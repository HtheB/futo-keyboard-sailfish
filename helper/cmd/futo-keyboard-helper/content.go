package main

import (
	"archive/tar"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/godbus/dbus/v5"
)

const bundledContentManifestPath = "/usr/share/futo-keyboard-sailfish/content/manifest.json"

var contentIDPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,63}$`)

type contentManifest struct {
	FormatVersion  int           `json:"formatVersion"`
	ContentVersion string        `json:"contentVersion"`
	BaseURL        string        `json:"baseUrl"`
	Items          []contentItem `json:"items"`
}

type contentItem struct {
	ID             string   `json:"id"`
	Kind           string   `json:"kind"`
	Name           string   `json:"name"`
	Version        string   `json:"version"`
	Archive        string   `json:"archive"`
	SHA256         string   `json:"sha256"`
	DownloadBytes  int64    `json:"downloadBytes"`
	InstalledBytes int64    `json:"installedBytes"`
	Paths          []string `json:"paths"`
}

type installedContentMarker struct {
	ID          string `json:"id"`
	Version     string `json:"version"`
	SHA256      string `json:"sha256"`
	InstalledAt int64  `json:"installedAt"`
}

type contentJob struct {
	State      string
	DoneBytes  int64
	TotalBytes int64
	Message    string
	Cancel     chan struct{}
}

type contentStatusItem struct {
	ID             string `json:"id"`
	Kind           string `json:"kind"`
	Name           string `json:"name"`
	Version        string `json:"version"`
	Archive        string `json:"archive"`
	DownloadBytes  int64  `json:"downloadBytes"`
	InstalledBytes int64  `json:"installedBytes"`
	Installed      bool   `json:"installed"`
	Available      bool   `json:"available"`
	State          string `json:"state"`
	DoneBytes      int64  `json:"doneBytes"`
	TotalBytes     int64  `json:"totalBytes"`
	Message        string `json:"message,omitempty"`
}

type contentStatus struct {
	ContentVersion string              `json:"contentVersion"`
	Root           string              `json:"root"`
	Items          []contentStatusItem `json:"items"`
}

type contentManager struct {
	mu           sync.Mutex
	root         string
	downloadsDir string
	manifest     contentManifest
	items        map[string]contentItem
	jobs         map[string]*contentJob
	httpClient   *http.Client
	onChanged    func(contentItem, string)
}

func optionalContentRoot() string {
	if override := strings.TrimSpace(os.Getenv("FUTO_CONTENT_ROOT")); override != "" {
		return filepath.Clean(override)
	}
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return ""
	}
	return filepath.Join(home, ".local", "share", "futo-keyboard-sailfish", "content")
}

func firstAvailableContentFile(paths ...string) string {
	for _, candidate := range paths {
		if regularFileAvailable(candidate) {
			return candidate
		}
	}
	return ""
}

func resolvedDictionaryPath(file string) string {
	root := optionalContentRoot()
	userPath := ""
	if root != "" {
		userPath = filepath.Join(root, "dictionaries", file)
	}
	return firstAvailableContentFile(userPath, filepath.Join(bundledDictionaryDir, file))
}

func resolvedVoiceModelPath() string {
	root := optionalContentRoot()
	userPath := ""
	if root != "" {
		userPath = filepath.Join(root, "voice", "tiny_acft_q8_0.bin")
	}
	return firstAvailableContentFile(userPath, bundledVoiceModelPath)
}

func loadContentManifest(manifestPath string) (contentManifest, error) {
	var manifest contentManifest
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return manifest, err
	}
	if err := json.Unmarshal(data, &manifest); err != nil {
		return manifest, err
	}
	if manifest.FormatVersion != 1 {
		return manifest, fmt.Errorf("unsupported content manifest format %d", manifest.FormatVersion)
	}
	seen := make(map[string]bool)
	for _, item := range manifest.Items {
		if !contentIDPattern.MatchString(item.ID) || seen[item.ID] {
			return manifest, fmt.Errorf("invalid or duplicate content id %q", item.ID)
		}
		seen[item.ID] = true
		if item.Name == "" || item.Version == "" || item.Archive == "" ||
			len(item.SHA256) != sha256.Size*2 || item.DownloadBytes <= 0 ||
			item.InstalledBytes <= 0 || len(item.Paths) != 1 {
			return manifest, fmt.Errorf("incomplete content item %q", item.ID)
		}
		if _, err := hex.DecodeString(item.SHA256); err != nil {
			return manifest, fmt.Errorf("invalid checksum for %q", item.ID)
		}
		if _, err := safeContentRelativePath(item.Paths[0]); err != nil {
			return manifest, fmt.Errorf("invalid path for %q: %w", item.ID, err)
		}
		if strings.Contains(item.Archive, "/") || strings.Contains(item.Archive, `\`) {
			return manifest, fmt.Errorf("invalid archive name for %q", item.ID)
		}
	}
	return manifest, nil
}

func newContentManager(root, manifestPath, downloadsDir string) (*contentManager, error) {
	manifest, err := loadContentManifest(manifestPath)
	if err != nil {
		return nil, err
	}
	manager := &contentManager{
		root:         filepath.Clean(root),
		downloadsDir: filepath.Clean(downloadsDir),
		manifest:     manifest,
		items:        make(map[string]contentItem),
		jobs:         make(map[string]*contentJob),
		httpClient: &http.Client{
			Timeout: 45 * time.Minute,
		},
	}
	for _, item := range manifest.Items {
		manager.items[item.ID] = item
	}
	return manager, nil
}

func safeContentRelativePath(value string) (string, error) {
	value = strings.ReplaceAll(strings.TrimSpace(value), `\`, "/")
	clean := path.Clean(value)
	if value == "" || clean == "." || clean != value || path.IsAbs(clean) ||
		clean == ".." || strings.HasPrefix(clean, "../") {
		return "", errors.New("unsafe relative path")
	}
	return clean, nil
}

func (manager *contentManager) destination(relative string) (string, error) {
	clean, err := safeContentRelativePath(relative)
	if err != nil {
		return "", err
	}
	destination := filepath.Join(manager.root, filepath.FromSlash(clean))
	relativeToRoot, err := filepath.Rel(manager.root, destination)
	if err != nil || relativeToRoot == ".." || strings.HasPrefix(relativeToRoot, ".."+string(os.PathSeparator)) {
		return "", errors.New("content path escapes storage root")
	}
	return destination, nil
}

func (manager *contentManager) markerPath(id string) string {
	return filepath.Join(manager.root, ".installed", id+".json")
}

func pathAvailable(value string) bool {
	info, err := os.Stat(value)
	return err == nil && (info.IsDir() || info.Mode().IsRegular())
}

func (manager *contentManager) installed(item contentItem) bool {
	for _, relative := range item.Paths {
		destination, err := manager.destination(relative)
		if err == nil && pathAvailable(destination) {
			continue
		}
		// A dictionary may also be provided system-wide by a package in
		// bundledDictionaryDir; resolvedDictionaryPath already falls back to it.
		if item.Kind == "dictionary" && strings.HasPrefix(relative, "dictionaries/") &&
			pathAvailable(filepath.Join(bundledDictionaryDir,
				strings.TrimPrefix(relative, "dictionaries/"))) {
			continue
		}
		return false
	}
	return true
}

func (manager *contentManager) localArchive(item contentItem) string {
	for _, candidate := range []string{
		filepath.Join(manager.downloadsDir, "FUTO-Keyboard-content", item.Archive),
		filepath.Join(manager.downloadsDir, item.Archive),
	} {
		if regularFileAvailable(candidate) {
			return candidate
		}
	}
	return ""
}

func (manager *contentManager) remoteURL(item contentItem) (string, error) {
	base := strings.TrimSpace(os.Getenv("FUTO_CONTENT_BASE_URL"))
	if base == "" {
		base = strings.TrimSpace(manager.manifest.BaseURL)
	}
	if base == "" {
		return "", errors.New("download server is not configured")
	}
	baseURL, err := url.Parse(base)
	if err != nil || baseURL.Host == "" {
		return "", errors.New("invalid content download server")
	}
	allowInsecure := os.Getenv("FUTO_ALLOW_INSECURE_CONTENT") == "1" &&
		(baseURL.Hostname() == "127.0.0.1" || baseURL.Hostname() == "localhost")
	if baseURL.Scheme != "https" && !allowInsecure {
		return "", errors.New("content downloads require HTTPS")
	}
	if !strings.HasSuffix(baseURL.Path, "/") {
		baseURL.Path += "/"
	}
	archiveURL, err := baseURL.Parse(url.PathEscape(item.Archive))
	if err != nil {
		return "", err
	}
	return archiveURL.String(), nil
}

func (manager *contentManager) itemAvailable(item contentItem) bool {
	if manager.localArchive(item) != "" {
		return true
	}
	_, err := manager.remoteURL(item)
	return err == nil
}

func (manager *contentManager) status() contentStatus {
	manager.mu.Lock()
	defer manager.mu.Unlock()
	result := contentStatus{
		ContentVersion: manager.manifest.ContentVersion,
		Root:           manager.root,
		Items:          make([]contentStatusItem, 0, len(manager.manifest.Items)),
	}
	for _, item := range manager.manifest.Items {
		state := contentStatusItem{
			ID:             item.ID,
			Kind:           item.Kind,
			Name:           item.Name,
			Version:        item.Version,
			Archive:        item.Archive,
			DownloadBytes:  item.DownloadBytes,
			InstalledBytes: item.InstalledBytes,
			Installed:      manager.installed(item),
			Available:      manager.itemAvailable(item),
			State:          "idle",
		}
		if job := manager.jobs[item.ID]; job != nil {
			state.State = job.State
			state.DoneBytes = job.DoneBytes
			state.TotalBytes = job.TotalBytes
			state.Message = job.Message
		}
		result.Items = append(result.Items, state)
	}
	return result
}

func (manager *contentManager) updateJob(id string, update func(*contentJob)) {
	manager.mu.Lock()
	defer manager.mu.Unlock()
	if job := manager.jobs[id]; job != nil {
		update(job)
	}
}

func (manager *contentManager) startInstall(id string) (bool, error) {
	manager.mu.Lock()
	item, found := manager.items[id]
	if !found {
		manager.mu.Unlock()
		return false, errors.New("unknown content pack")
	}
	if job := manager.jobs[id]; job != nil &&
		(job.State == "downloading" || job.State == "installing") {
		manager.mu.Unlock()
		return false, nil
	}
	job := &contentJob{
		State:      "downloading",
		TotalBytes: item.DownloadBytes,
		Cancel:     make(chan struct{}),
	}
	manager.jobs[id] = job
	manager.mu.Unlock()
	go manager.install(item, job)
	return true, nil
}

func (manager *contentManager) cancelInstall(id string) (bool, error) {
	manager.mu.Lock()
	defer manager.mu.Unlock()
	job := manager.jobs[id]
	if job == nil || (job.State != "downloading" && job.State != "installing") {
		return false, nil
	}
	select {
	case <-job.Cancel:
	default:
		close(job.Cancel)
	}
	return true, nil
}

func (manager *contentManager) install(item contentItem, job *contentJob) {
	err := manager.installContent(item, job)
	state := "installed"
	message := ""
	if err != nil {
		state = "failed"
		message = err.Error()
	}
	manager.updateJob(item.ID, func(current *contentJob) {
		current.State = state
		current.Message = message
	})
	if manager.onChanged != nil {
		manager.onChanged(item, state)
	}
}

func availableBytes(value string) (uint64, error) {
	probe := value
	for {
		var stats syscall.Statfs_t
		if err := syscall.Statfs(probe, &stats); err == nil {
			return stats.Bavail * uint64(stats.Bsize), nil
		}
		parent := filepath.Dir(probe)
		if parent == probe {
			return 0, errors.New("cannot determine available storage")
		}
		probe = parent
	}
}

func (manager *contentManager) installContent(item contentItem, job *contentJob) error {
	if err := os.MkdirAll(filepath.Join(manager.root, ".downloads"), 0o700); err != nil {
		return err
	}
	available, err := availableBytes(manager.root)
	if err != nil {
		return err
	}
	required := uint64(item.DownloadBytes + item.InstalledBytes + 16*1024*1024)
	if available < required {
		return fmt.Errorf("not enough free space: need %d MB", (required+999999)/1000000)
	}
	archivePath := filepath.Join(manager.root, ".downloads", item.ID+".part")
	_ = os.Remove(archivePath)
	if err := manager.obtainArchive(item, job, archivePath); err != nil {
		_ = os.Remove(archivePath)
		return err
	}
	manager.updateJob(item.ID, func(current *contentJob) { current.State = "installing" })
	stagingRoot := filepath.Join(manager.root, ".staging", item.ID)
	_ = os.RemoveAll(stagingRoot)
	if err := os.MkdirAll(stagingRoot, 0o700); err != nil {
		return err
	}
	defer os.RemoveAll(stagingRoot)
	if err := extractContentArchive(archivePath, stagingRoot, item.InstalledBytes, job.Cancel); err != nil {
		return err
	}
	_ = os.Remove(archivePath)
	relative := item.Paths[0]
	staged := filepath.Join(stagingRoot, filepath.FromSlash(relative))
	if !pathAvailable(staged) {
		return errors.New("content archive does not contain its declared path")
	}
	destination, err := manager.destination(relative)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(destination), 0o700); err != nil {
		return err
	}
	backup := destination + ".old"
	_ = os.RemoveAll(backup)
	if pathAvailable(destination) {
		if err := os.Rename(destination, backup); err != nil {
			return err
		}
	}
	if err := os.Rename(staged, destination); err != nil {
		if pathAvailable(backup) {
			_ = os.Rename(backup, destination)
		}
		return err
	}
	_ = os.RemoveAll(backup)
	marker := installedContentMarker{
		ID:          item.ID,
		Version:     item.Version,
		SHA256:      item.SHA256,
		InstalledAt: time.Now().Unix(),
	}
	markerData, err := json.Marshal(marker)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(manager.markerPath(item.ID)), 0o700); err != nil {
		return err
	}
	markerTemporary := manager.markerPath(item.ID) + ".new"
	if err := os.WriteFile(markerTemporary, markerData, 0o600); err != nil {
		return err
	}
	return os.Rename(markerTemporary, manager.markerPath(item.ID))
}

func (manager *contentManager) obtainArchive(item contentItem, job *contentJob, destination string) error {
	source := manager.localArchive(item)
	var reader io.ReadCloser
	if source != "" {
		file, err := os.Open(source)
		if err != nil {
			return err
		}
		reader = file
	} else {
		remote, err := manager.remoteURL(item)
		if err != nil {
			return err
		}
		request, err := http.NewRequest(http.MethodGet, remote, nil)
		if err != nil {
			return err
		}
		response, err := manager.httpClient.Do(request)
		if err != nil {
			return err
		}
		if response.StatusCode != http.StatusOK {
			response.Body.Close()
			return fmt.Errorf("download failed: HTTP %d", response.StatusCode)
		}
		reader = response.Body
	}
	defer reader.Close()
	file, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	hash := sha256.New()
	buffer := make([]byte, 128*1024)
	var written int64
	for {
		select {
		case <-job.Cancel:
			file.Close()
			return errors.New("download cancelled")
		default:
		}
		read, readErr := reader.Read(buffer)
		if read > 0 {
			written += int64(read)
			if written > item.DownloadBytes+64*1024 {
				file.Close()
				return errors.New("download is larger than declared")
			}
			if _, err := file.Write(buffer[:read]); err != nil {
				file.Close()
				return err
			}
			_, _ = hash.Write(buffer[:read])
			manager.updateJob(item.ID, func(current *contentJob) { current.DoneBytes = written })
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			file.Close()
			return readErr
		}
	}
	if err := file.Close(); err != nil {
		return err
	}
	if written != item.DownloadBytes {
		return fmt.Errorf("download size mismatch: got %d, expected %d", written, item.DownloadBytes)
	}
	actualHash := hex.EncodeToString(hash.Sum(nil))
	if !strings.EqualFold(actualHash, item.SHA256) {
		return errors.New("download checksum verification failed")
	}
	return nil
}

func extractContentArchive(archivePath, destination string, maximumBytes int64, cancel <-chan struct{}) error {
	file, err := os.Open(archivePath)
	if err != nil {
		return err
	}
	defer file.Close()
	compressed, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer compressed.Close()
	reader := tar.NewReader(compressed)
	var extracted int64
	for {
		select {
		case <-cancel:
			return errors.New("installation cancelled")
		default:
		}
		header, err := reader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		relative, err := safeContentRelativePath(strings.TrimSuffix(header.Name, "/"))
		if err != nil {
			return errors.New("content archive contains an unsafe path")
		}
		target := filepath.Join(destination, filepath.FromSlash(relative))
		if header.Typeflag == tar.TypeDir {
			if err := os.MkdirAll(target, 0o700); err != nil {
				return err
			}
			continue
		}
		if header.Typeflag != tar.TypeReg && header.Typeflag != tar.TypeRegA {
			return errors.New("content archive contains an unsupported entry")
		}
		if header.Size < 0 || extracted+header.Size > maximumBytes+1024*1024 {
			return errors.New("content archive exceeds its declared size")
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
			return err
		}
		output, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
		if err != nil {
			return err
		}
		copied, copyErr := io.CopyN(output, reader, header.Size)
		closeErr := output.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
		extracted += copied
	}
	if extracted != maximumBytes {
		return fmt.Errorf("installed size mismatch: got %d, expected %d", extracted, maximumBytes)
	}
	return nil
}

func (manager *contentManager) remove(id string) (bool, error) {
	manager.mu.Lock()
	item, found := manager.items[id]
	if !found {
		manager.mu.Unlock()
		return false, errors.New("unknown content pack")
	}
	if job := manager.jobs[id]; job != nil &&
		(job.State == "downloading" || job.State == "installing") {
		manager.mu.Unlock()
		return false, errors.New("content pack is busy")
	}
	manager.mu.Unlock()
	removed := false
	for _, relative := range item.Paths {
		destination, err := manager.destination(relative)
		if err != nil {
			return false, err
		}
		if pathAvailable(destination) {
			if err := os.RemoveAll(destination); err != nil {
				return false, err
			}
			removed = true
		}
	}
	_ = os.Remove(manager.markerPath(id))
	manager.mu.Lock()
	delete(manager.jobs, id)
	manager.mu.Unlock()
	if removed && manager.onChanged != nil {
		manager.onChanged(item, "removed")
	}
	return removed, nil
}

func (service *service) ContentStatus() (string, *dbus.Error) {
	if service.content == nil {
		return "", dbus.MakeFailedError(errors.New("content manager is unavailable"))
	}
	data, err := json.Marshal(service.content.status())
	if err != nil {
		return "", dbus.MakeFailedError(err)
	}
	return string(data), nil
}

func (service *service) InstallContent(id string) (bool, *dbus.Error) {
	if service.content == nil {
		return false, dbus.MakeFailedError(errors.New("content manager is unavailable"))
	}
	started, err := service.content.startInstall(id)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return started, nil
}

func (service *service) CancelContentInstall(id string) (bool, *dbus.Error) {
	if service.content == nil {
		return false, dbus.MakeFailedError(errors.New("content manager is unavailable"))
	}
	cancelled, err := service.content.cancelInstall(id)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return cancelled, nil
}

func (service *service) RemoveContent(id string) (bool, *dbus.Error) {
	if service.content == nil {
		return false, dbus.MakeFailedError(errors.New("content manager is unavailable"))
	}
	removed, err := service.content.remove(id)
	if err != nil {
		return false, dbus.MakeFailedError(err)
	}
	return removed, nil
}
