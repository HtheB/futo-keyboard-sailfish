package main

import (
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

const conversionProfileLimit = 32 * 1024 * 1024

// Engines need normal files. Decrypt into a private tmpfs directory only;
// persistent storage uses the existing device-bound learned-data codec.
func conversionRuntimeDirectory() (string, error) {
	if info, err := os.Stat("/dev/shm"); err == nil && info.IsDir() {
		return os.MkdirTemp("/dev/shm", "futo-conversion-")
	}
	return "", errors.New("private conversion memory storage is unavailable")
}

func conversionProfileFile(name string) bool {
	name = filepath.ToSlash(name)
	return name != "." && name != ".." && name != "" && !strings.HasPrefix(name, "/") &&
		!strings.Contains(name, "\\") && filepath.ToSlash(filepath.Clean(name)) == name &&
		!strings.HasPrefix(name, "../") && !strings.HasPrefix(name, "build/") &&
		!strings.HasSuffix(name, ".yaml") && !strings.HasSuffix(name, ".lock") &&
		filepath.Base(name) != "LOCK"
}

func restoreConversionProfile(codec *secureFileCodec, path, profile string) error {
	if codec == nil || !codec.hasKey() {
		return errors.New("conversion learning storage is locked")
	}
	data, err := codec.readFile(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	defer zeroBytes(data)
	if len(data) > 2*conversionProfileLimit {
		return errors.New("conversion history is too large")
	}
	var files map[string][]byte
	if err := json.Unmarshal(data, &files); err != nil {
		return err
	}
	total := 0
	for name, contents := range files {
		defer zeroBytes(contents)
		total += len(contents)
		if !conversionProfileFile(name) || total > conversionProfileLimit {
			return errors.New("invalid conversion history")
		}
		file := filepath.Join(profile, name)
		if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
			return err
		}
		if err := os.WriteFile(file, contents, 0600); err != nil {
			return err
		}
	}
	return nil
}

func saveConversionProfile(codec *secureFileCodec, path, profile string) error {
	if codec == nil || !codec.hasKey() {
		return errors.New("conversion learning storage is locked")
	}
	files := map[string][]byte{}
	total := 0
	err := filepath.WalkDir(profile, func(file string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		name, err := filepath.Rel(profile, file)
		if err != nil {
			return err
		}
		if entry.IsDir() {
			if name == "build" {
				return filepath.SkipDir
			}
			return nil
		}
		if !conversionProfileFile(name) {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return errors.New("invalid conversion profile entry")
		}
		if info.Size() > conversionProfileLimit || total+int(info.Size()) > conversionProfileLimit {
			return errors.New("conversion history is too large")
		}
		input, err := os.Open(file)
		if err != nil {
			return err
		}
		contents, err := io.ReadAll(io.LimitReader(input, int64(conversionProfileLimit-total+1)))
		_ = input.Close()
		if err != nil {
			return err
		}
		total += len(contents)
		if total > conversionProfileLimit {
			zeroBytes(contents)
			return errors.New("conversion history is too large")
		}
		files[filepath.ToSlash(name)] = contents
		return nil
	})
	defer func() {
		for _, contents := range files {
			zeroBytes(contents)
		}
	}()
	if err != nil {
		return err
	}
	data, err := json.Marshal(files)
	if err != nil {
		return err
	}
	defer zeroBytes(data)
	return codec.writeFile(path, data)
}
