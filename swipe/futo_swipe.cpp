/*
 * FUTO Keyboard for Sailfish OS - FUTO Swipe worker
 *
 * This worker is a GPLv3 integration around FUTO's trained SwipeEngine.  It
 * deliberately runs as a separate process from the keyboard's Source First
 * dictionary worker.  The line protocol contains only swipe coordinates,
 * keyboard geometry, dictionary identifiers and decoded candidates.
 */

#include "swipe_decoder/engine.hpp"
#include "swipe_decoder/itrie.h"
#include "swipe_decoder/layout.hpp"

#include <algorithm>
#include <clocale>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cwctype>
#include <fstream>
#include <iostream>
#include <limits>
#include <list>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

constexpr char kDictionaryMagic[8] = {'F', 'K', 'S', 'I', 'D', 'X', '1', '\0'};
constexpr std::size_t kMaximumDictionaryBytes = 512U * 1024U * 1024U;
constexpr std::size_t kMaximumEntries = 2000000U;
// The downloadable dictionaries are ordered by descending frequency.  Most
// contain fewer than this many entries, while the Romanian source contains
// over 1.1 million extremely low-frequency forms.  Keeping the useful head of
// that list avoids a ~300 MB persistent swipe trie without affecting ordinary
// typed lookup, which continues to use the complete dictionary worker.
constexpr std::size_t kMaximumSwipeEntries = 250000U;
constexpr std::size_t kMaximumWordLength = 64U;
constexpr std::size_t kTrieCacheLimit = 3U;

struct ParsedPoint {
    uint32_t key = 0;
    float x = 0.0f;
    float y = 0.0f;
    float t = 0.0f;
};

struct DictionaryEntry {
    std::string display;
    std::vector<uint32_t> normalized;
    int32_t probability = 0;
};

struct EnglishSpecialLayout {
    bool active = false;
    swipe_decoder::KeyboardLayout layout;
    float scaleX = 1.0f;
    float scaleY = 1.0f;
    float offsetX = 0.0f;
    float offsetY = 0.0f;
};

uint32_t lowerCodepoint(uint32_t codepoint) {
    // The dictionaries are normally already lower-case.  towlower gives us
    // the complete platform Unicode table for capitalized dictionary entries
    // and layouts, including Greek and Cyrillic.
    const wint_t lowered = std::towlower(static_cast<wint_t>(codepoint));
    return lowered == WEOF ? codepoint : static_cast<uint32_t>(lowered);
}

uint32_t upperCodepoint(uint32_t codepoint) {
    const wint_t upper = std::towupper(static_cast<wint_t>(codepoint));
    return upper == WEOF ? codepoint : static_cast<uint32_t>(upper);
}

std::string capitalizeFirst(const std::string &word) {
    if (word.empty()) {
        return word;
    }
    const char *begin = word.data();
    const char *end = begin + word.size();
    int first = 0;
    const char *next = swipe_decoder::utf8_decode_one(begin, end, first);
    if (next == begin || first == 0xFFFD) {
        return word;
    }
    std::string result;
    swipe_decoder::utf8_encode_one(static_cast<int>(upperCodepoint(first)), result);
    result.append(next, end);
    return result;
}

std::string jsonEscape(const std::string &value) {
    std::ostringstream output;
    for (unsigned char character : value) {
        switch (character) {
        case '\\': output << "\\\\"; break;
        case '"': output << "\\\""; break;
        case '\b': output << "\\b"; break;
        case '\f': output << "\\f"; break;
        case '\n': output << "\\n"; break;
        case '\r': output << "\\r"; break;
        case '\t': output << "\\t"; break;
        default:
            if (character < 0x20) {
                static const char hexadecimal[] = "0123456789abcdef";
                output << "\\u00" << hexadecimal[character >> 4]
                       << hexadecimal[character & 0x0f];
            } else {
                output << static_cast<char>(character);
            }
        }
    }
    return output.str();
}

std::vector<std::string> split(const std::string &value, char delimiter) {
    std::vector<std::string> result;
    std::size_t start = 0;
    while (start <= value.size()) {
        const std::size_t end = value.find(delimiter, start);
        result.push_back(value.substr(start, end == std::string::npos
                ? std::string::npos : end - start));
        if (end == std::string::npos) {
            break;
        }
        start = end + 1;
    }
    return result;
}

bool parseUnsigned(const std::string &value, uint32_t &result) {
    try {
        std::size_t consumed = 0;
        const unsigned long parsed = std::stoul(value, &consumed, 10);
        if (consumed != value.size() || parsed > std::numeric_limits<uint32_t>::max()) {
            return false;
        }
        result = static_cast<uint32_t>(parsed);
        return true;
    } catch (...) {
        return false;
    }
}

bool parseFloat(const std::string &value, float &result) {
    try {
        std::size_t consumed = 0;
        const float parsed = std::stof(value, &consumed);
        if (consumed != value.size() || !std::isfinite(parsed)) {
            return false;
        }
        result = parsed;
        return true;
    } catch (...) {
        return false;
    }
}

bool parsePoints(const std::string &value, bool requireTime,
        std::vector<ParsedPoint> &result) {
    result.clear();
    for (const std::string &encoded : split(value, ';')) {
        const std::vector<std::string> fields = split(encoded, ':');
        if (fields.size() != (requireTime ? 4U : 3U)) {
            return false;
        }
        ParsedPoint point;
        if (!parseUnsigned(fields[0], point.key)
                || !parseFloat(fields[1], point.x)
                || !parseFloat(fields[2], point.y)
                || (requireTime && !parseFloat(fields[3], point.t))) {
            return false;
        }
        if (point.x < 0.0f || point.x > 1.0f
                || point.y < 0.0f || point.y > 1.0f
                || (requireTime && point.t < 0.0f)) {
            return false;
        }
        result.push_back(point);
    }
    return !result.empty();
}

std::vector<char> readFile(const std::string &path) {
    std::ifstream input(path, std::ios::binary | std::ios::ate);
    if (!input) {
        throw std::runtime_error("cannot open dictionary: " + path);
    }
    const std::streamoff size = input.tellg();
    if (size < 12 || static_cast<uint64_t>(size) > kMaximumDictionaryBytes) {
        throw std::runtime_error("invalid dictionary size: " + path);
    }
    std::vector<char> data(static_cast<std::size_t>(size));
    input.seekg(0);
    input.read(data.data(), size);
    if (!input) {
        throw std::runtime_error("cannot read dictionary: " + path);
    }
    return data;
}

template<typename T>
T takeNumber(const std::vector<char> &data, std::size_t &offset) {
    if (sizeof(T) > data.size() - offset) {
        throw std::runtime_error("truncated compiled dictionary");
    }
    T value{};
    std::memcpy(&value, data.data() + offset, sizeof(T));
    offset += sizeof(T);
    return value;
}

std::vector<DictionaryEntry> loadDictionary(const std::string &path) {
    const std::vector<char> data = readFile(path);
    if (std::memcmp(data.data(), kDictionaryMagic, sizeof(kDictionaryMagic)) != 0) {
        throw std::runtime_error("unsupported dictionary format: " + path);
    }
    std::size_t offset = sizeof(kDictionaryMagic);
    const uint32_t count = takeNumber<uint32_t>(data, offset);
    if (count == 0 || count > kMaximumEntries) {
        throw std::runtime_error("invalid dictionary entry count: " + path);
    }
    std::vector<DictionaryEntry> entries;
    const uint32_t loadedCount = static_cast<uint32_t>(std::min<std::size_t>(
            count, kMaximumSwipeEntries));
    entries.reserve(loadedCount);
    for (uint32_t index = 0; index < loadedCount; ++index) {
        const uint16_t displaySize = takeNumber<uint16_t>(data, offset);
        const uint8_t normalizedSize = takeNumber<uint8_t>(data, offset);
        (void)takeNumber<uint8_t>(data, offset);
        const int32_t probability = takeNumber<int32_t>(data, offset);
        const std::size_t required = static_cast<std::size_t>(displaySize)
                + static_cast<std::size_t>(normalizedSize) * sizeof(uint32_t);
        if (displaySize == 0 || displaySize > 1024 || normalizedSize == 0
                || normalizedSize > kMaximumWordLength || required > data.size() - offset) {
            throw std::runtime_error("invalid dictionary entry: " + path);
        }
        DictionaryEntry entry;
        entry.display.assign(data.data() + offset, displaySize);
        offset += displaySize;
        entry.normalized.resize(normalizedSize);
        std::memcpy(entry.normalized.data(), data.data() + offset,
                entry.normalized.size() * sizeof(uint32_t));
        offset += entry.normalized.size() * sizeof(uint32_t);
        entry.probability = probability;
        entries.push_back(std::move(entry));
    }
    return entries;
}

struct CompactNode {
    uint32_t childOffset = 0;
    uint32_t wordOffset = 0;
    uint16_t childCount = 0;
    uint16_t wordLength = 0;
    uint16_t depth = 0;
    uint8_t character = 0;
    uint8_t isWord = 0;
    float logFrequency = -100.0f;
};

class CompactTrie {
public:
    CompactTrie(const std::string &path, const swipe_decoder::KeyboardLayout &layout) {
        build(path, layout);
        interface_.userdata = this;
        interface_.vtable = &vtable_;
    }

    ITrie *interface() { return &interface_; }

private:
    struct Candidate {
        std::vector<uint8_t> path;
        std::string display;
        int32_t probability = 0;
    };

    struct TemporaryEdge {
        uint32_t parent = 0;
        uint32_t child = 0;
    };

    int numberOfCharacters_ = 0;
    std::vector<CompactNode> nodes_;
    std::vector<uint32_t> children_;
    std::vector<char> words_;
    ITrie interface_{};

    static int numChars(void *self) {
        return static_cast<CompactTrie *>(self)->numberOfCharacters_;
    }
    static TrieId root(void *) { return 0; }
    static int charIndex(void *self, TrieId id) {
        const CompactTrie *trie = static_cast<CompactTrie *>(self);
        return id < trie->nodes_.size() ? trie->nodes_[id].character : -1;
    }
    static uint32_t childCount(void *self, TrieId id) {
        const CompactTrie *trie = static_cast<CompactTrie *>(self);
        return id < trie->nodes_.size() ? trie->nodes_[id].childCount : 0;
    }
    static TrieId child(void *self, TrieId id, uint32_t index) {
        const CompactTrie *trie = static_cast<CompactTrie *>(self);
        if (id >= trie->nodes_.size() || index >= trie->nodes_[id].childCount) {
            return 0;
        }
        return trie->children_[trie->nodes_[id].childOffset + index];
    }
    static bool isWord(void *self, TrieId id) {
        const CompactTrie *trie = static_cast<CompactTrie *>(self);
        return id < trie->nodes_.size() && trie->nodes_[id].isWord;
    }
    static float frequency(void *self, TrieId id) {
        const CompactTrie *trie = static_cast<CompactTrie *>(self);
        return id < trie->nodes_.size() ? trie->nodes_[id].logFrequency : -100.0f;
    }
    static uint16_t depth(void *self, TrieId id) {
        const CompactTrie *trie = static_cast<CompactTrie *>(self);
        return id < trie->nodes_.size() ? trie->nodes_[id].depth : 0;
    }
    static const char *word(void *self, TrieId id) {
        const CompactTrie *trie = static_cast<CompactTrie *>(self);
        if (id >= trie->nodes_.size() || !trie->nodes_[id].isWord) {
            return nullptr;
        }
        return trie->words_.data() + trie->nodes_[id].wordOffset;
    }
    static void endSearch(void *) {}

    static const ITrieVTable vtable_;

    void build(const std::string &dictionaryPath,
            const swipe_decoder::KeyboardLayout &layout) {
        numberOfCharacters_ = layout.num_keys;
        std::unordered_map<uint32_t, uint8_t> characterIndices;
        characterIndices.reserve(layout.code_points.size());
        for (std::size_t index = 0; index < layout.code_points.size(); ++index) {
            characterIndices.emplace(lowerCodepoint(layout.code_points[index]),
                    static_cast<uint8_t>(index));
        }

        std::vector<Candidate> candidates;
        const std::vector<DictionaryEntry> entries = loadDictionary(dictionaryPath);
        candidates.reserve(entries.size());
        for (const DictionaryEntry &entry : entries) {
            const std::vector<int> display = swipe_decoder::utf8_to_codepoints(entry.display);
            Candidate candidate;
            candidate.path.reserve(entry.normalized.size());
            bool usable = true;
            for (std::size_t index = 0; index < entry.normalized.size(); ++index) {
                uint32_t codepoint = lowerCodepoint(entry.normalized[index]);
                if (index < display.size()) {
                    const uint32_t displayCodepoint = lowerCodepoint(display[index]);
                    if (characterIndices.find(displayCodepoint) != characterIndices.end()) {
                        codepoint = displayCodepoint;
                    }
                }
                const auto found = characterIndices.find(codepoint);
                if (found != characterIndices.end()) {
                    candidate.path.push_back(found->second);
                } else {
                    // Never silently remove an unknown character: that turns a
                    // longer dictionary word into an unrelated short gesture.
                    usable = false;
                    break;
                }
            }
            if (!usable || candidate.path.empty()
                    || candidate.path.size() > kMaximumWordLength) {
                continue;
            }
            candidate.display = entry.display;
            candidate.probability = entry.probability;
            candidates.push_back(std::move(candidate));
        }
        std::sort(candidates.begin(), candidates.end(), [](const Candidate &left,
                const Candidate &right) {
            if (left.path != right.path) {
                return left.path < right.path;
            }
            return left.probability > right.probability;
        });

        nodes_.clear();
        nodes_.push_back(CompactNode{});
        std::vector<TemporaryEdge> edges;
        std::vector<uint8_t> previousPath;
        std::vector<uint32_t> nodeStack(1, 0);
        for (const Candidate &candidate : candidates) {
            std::size_t common = 0;
            while (common < previousPath.size() && common < candidate.path.size()
                    && previousPath[common] == candidate.path[common]) {
                ++common;
            }
            nodeStack.resize(common + 1);
            for (std::size_t index = common; index < candidate.path.size(); ++index) {
                if (nodes_.size() >= std::numeric_limits<uint32_t>::max()) {
                    throw std::runtime_error("dictionary trie is too large");
                }
                CompactNode node;
                node.character = candidate.path[index];
                node.depth = static_cast<uint16_t>(index + 1);
                const uint32_t nodeID = static_cast<uint32_t>(nodes_.size());
                nodes_.push_back(node);
                edges.push_back({nodeStack.back(), nodeID});
                nodeStack.push_back(nodeID);
            }
            CompactNode &terminal = nodes_[nodeStack.back()];
            const float candidateLogFrequency = std::log(
                    std::max(1.0f, static_cast<float>(candidate.probability)));
            if (!terminal.isWord || candidateLogFrequency > terminal.logFrequency) {
                terminal.isWord = 1;
                terminal.logFrequency = candidateLogFrequency;
                terminal.wordOffset = static_cast<uint32_t>(words_.size());
                terminal.wordLength = static_cast<uint16_t>(std::min<std::size_t>(
                        candidate.display.size(), std::numeric_limits<uint16_t>::max()));
                words_.insert(words_.end(), candidate.display.begin(), candidate.display.end());
                words_.push_back('\0');
            }
            previousPath = candidate.path;
        }

        std::vector<uint32_t> counts(nodes_.size(), 0);
        for (const TemporaryEdge &edge : edges) {
            ++counts[edge.parent];
        }
        uint32_t offset = 0;
        for (std::size_t index = 0; index < nodes_.size(); ++index) {
            nodes_[index].childOffset = offset;
            nodes_[index].childCount = static_cast<uint16_t>(counts[index]);
            offset += counts[index];
        }
        children_.resize(edges.size());
        std::vector<uint32_t> positions(nodes_.size(), 0);
        for (const TemporaryEdge &edge : edges) {
            children_[nodes_[edge.parent].childOffset + positions[edge.parent]++] = edge.child;
        }
        if (nodes_.size() <= 1 || words_.empty()) {
            throw std::runtime_error("dictionary has no words usable by this layout");
        }
    }
};

const ITrieVTable CompactTrie::vtable_ = {
    &CompactTrie::numChars,
    &CompactTrie::root,
    &CompactTrie::charIndex,
    &CompactTrie::childCount,
    &CompactTrie::child,
    &CompactTrie::isWord,
    &CompactTrie::frequency,
    &CompactTrie::depth,
    &CompactTrie::word,
    &CompactTrie::endSearch
};

class Worker {
public:
    explicit Worker(std::string encoderPath,
            std::string decoderPath,
            std::string lmModelPath,
            std::string lmVocabPath,
            std::unordered_map<std::string, std::string> dictionaries)
        : encoderPath_(std::move(encoderPath)),
          decoderPath_(std::move(decoderPath)),
          lmModelPath_(std::move(lmModelPath)),
          lmVocabPath_(std::move(lmVocabPath)),
          dictionaries_(std::move(dictionaries)) {}

    void handle(const std::string &line) {
        const std::vector<std::string> fields = split(line, '\t');
        if (fields.size() != 8 || fields[0] != "SWIPE3") {
            error("invalid command");
            return;
        }
        const std::string &language = fields[1];
        const auto dictionary = dictionaries_.find(language);
        if (dictionary == dictionaries_.end()) {
            error("unknown language");
            return;
        }
        uint32_t requestedLimit = 0;
        uint32_t capitalize = 0;
        uint32_t allowEnglishRefinement = 0;
        if (!parseUnsigned(fields[2], requestedLimit)
                || !parseUnsigned(fields[3], capitalize)
                || !parseUnsigned(fields[4], allowEnglishRefinement)) {
            error("invalid options");
            return;
        }
        requestedLimit = std::max<uint32_t>(1, std::min<uint32_t>(20, requestedLimit));

        std::vector<ParsedPoint> path;
        std::vector<ParsedPoint> geometry;
        if (!parsePoints(fields[6], true, path) || path.size() < 2
                || !parsePoints(fields[7], false, geometry) || geometry.size() < 2) {
            error("invalid swipe data");
            return;
        }
        swipe_decoder::KeyboardLayout originalLayout = makeLayout(geometry);
        if (originalLayout.num_keys < 2 || originalLayout.num_keys > 64) {
            error("unsupported keyboard geometry");
            return;
        }

        try {
            const bool english = language == "EN" || language == "EN_GB";
            const bool refinement = allowEnglishRefinement != 0 && english;
            EnglishSpecialLayout special;
            if (refinement && !decoderPath_.empty()) {
                special = matchEnglishQwerty(originalLayout);
            }
            const swipe_decoder::KeyboardLayout &layout = special.active
                    ? special.layout : originalLayout;
            CompactTrie *trie = cachedTrie(language, dictionary->second, layout);
            if (!ready_) {
                swipe_decoder::SwipeEngine::Config config;
                config.encoder_path = encoderPath_;
                // Always establish the universal path first. Optional English
                // refinements are applied atomically below, so a missing or
                // incompatible refinement can never disable swipe typing.
                config.layout = originalLayout;
                config.dictionaries = {trie->interface()};
                config.num_threads = 1;
                // Match FUTO Keyboard's high-accuracy pass.  A beam of 32 is
                // used only for its provisional preview; the completed swipe
                // is decoded with 300 candidates before top-k ranking.
                config.beam_width = 300;
                config.top_k = static_cast<int>(requestedLimit);
                if (!engine_.init(config)) {
                    throw std::runtime_error("could not initialize FUTO Swipe model");
                }
                ready_ = true;
            }
            swipe_decoder::SwipeEngine::Mode mode;
            mode.layout = layout;
            mode.dictionaries = std::vector<ITrie *>{trie->interface()};
            mode.decoder_path = special.active ? decoderPath_ : std::string();
            const bool useLm = refinement && !lmModelPath_.empty()
                    && !lmVocabPath_.empty();
            mode.lm_model_path = useLm ? lmModelPath_ : std::string();
            mode.lm_vocab_path = useLm ? lmVocabPath_ : std::string();
            if (!engine_.setMode(mode)) {
                // The encoder-only mode supports every language and layout.
                // Gracefully discard optional English refinements if their
                // files are corrupt or the active geometry does not fit.
                special.active = false;
                trie = cachedTrie(language, dictionary->second, originalLayout);
                swipe_decoder::SwipeEngine::Mode fallback;
                fallback.layout = originalLayout;
                fallback.dictionaries = std::vector<ITrie *>{trie->interface()};
                fallback.decoder_path = std::string();
                fallback.lm_model_path = std::string();
                fallback.lm_vocab_path = std::string();
                if (!engine_.setMode(fallback)) {
                    throw std::runtime_error("could not activate swipe language/layout");
                }
            }
            activeTrie_ = trie;
            pruneTrieCache();

            std::vector<float> x, y, t;
            x.reserve(path.size());
            y.reserve(path.size());
            t.reserve(path.size());
            const float firstTime = path.front().t;
            for (const ParsedPoint &point : path) {
                x.push_back(special.active
                        ? point.x * special.scaleX + special.offsetX : point.x);
                y.push_back(special.active
                        ? point.y * special.scaleY + special.offsetY : point.y);
                t.push_back(std::max(0.0f, point.t - firstTime));
            }
            const std::vector<std::string> context = contextWords(fields[5]);
            std::vector<swipe_decoder::DecodedWord> decoded = engine_.recognize(
                    x.data(), y.data(), t.data(), x.size(), context,
                    static_cast<int>(requestedLimit), 300);
            std::cout << "OK\t[";
            for (std::size_t index = 0; index < decoded.size(); ++index) {
                if (index) {
                    std::cout << ',';
                }
                std::string word = decoded[index].word;
                if (capitalize != 0) {
                    word = capitalizeFirst(word);
                }
                const int64_t score = static_cast<int64_t>(std::llround(
                        decoded[index].final_score * 1000000000.0));
                std::cout << "{\"word\":\"" << jsonEscape(word)
                          << "\",\"score\":" << score << '}';
            }
            std::cout << "]" << std::endl;
        } catch (const std::exception &exception) {
            error(exception.what());
        }
    }

private:
    struct CacheEntry {
        std::string key;
        std::unique_ptr<CompactTrie> trie;
    };

    std::string encoderPath_;
    std::string decoderPath_;
    std::string lmModelPath_;
    std::string lmVocabPath_;
    std::unordered_map<std::string, std::string> dictionaries_;
    swipe_decoder::SwipeEngine engine_;
    bool ready_ = false;
    CompactTrie *activeTrie_ = nullptr;
    std::list<CacheEntry> cache_;

    static void error(const std::string &message) {
        std::cout << "ERROR\t" << message << std::endl;
    }

    static swipe_decoder::KeyboardLayout makeLayout(
            const std::vector<ParsedPoint> &geometry) {
        swipe_decoder::KeyboardLayout layout;
        std::unordered_map<uint32_t, bool> seen;
        for (const ParsedPoint &point : geometry) {
            const uint32_t key = lowerCodepoint(point.key);
            if (seen[key]) {
                continue;
            }
            seen[key] = true;
            layout.code_points.push_back(static_cast<int>(key));
            swipe_decoder::utf8_encode_one(static_cast<int>(key), layout.letters);
            layout.key_cx.push_back(point.x);
            layout.key_cy.push_back(point.y);
        }
        layout.num_keys = static_cast<int>(layout.code_points.size());
        layout.build_index();
        return layout;
    }

    static EnglishSpecialLayout matchEnglishQwerty(
            const swipe_decoder::KeyboardLayout &source) {
        EnglishSpecialLayout result;
        if (source.num_keys != 26 || source.code_points.size() != 26
                || source.key_cx.size() != 26 || source.key_cy.size() != 26) {
            return result;
        }

        static const float expectedX[26] = {
            0.05555556f, 0.61111111f, 0.38888889f, 0.27777778f,
            0.22222222f, 0.38888889f, 0.50000000f, 0.61111111f,
            0.77777778f, 0.72222222f, 0.83333333f, 0.94444444f,
            0.83333333f, 0.72222222f, 0.88888889f, 1.00000000f,
            0.00000000f, 0.33333333f, 0.16666667f, 0.44444444f,
            0.66666667f, 0.50000000f, 0.11111111f, 0.27777778f,
            0.55555556f, 0.16666667f
        };
        static const float expectedY[26] = {
            0.5f, 1.0f, 1.0f, 0.5f, 0.0f, 0.5f, 0.5f, 0.5f,
            0.0f, 0.5f, 0.5f, 0.5f, 1.0f, 1.0f, 0.0f, 0.0f,
            0.0f, 0.0f, 0.5f, 0.0f, 0.0f, 1.0f, 0.0f, 1.0f,
            0.0f, 1.0f
        };

        float xByLetter[26]{};
        float yByLetter[26]{};
        bool present[26]{};
        float minX = 1.0f, maxX = 0.0f, minY = 1.0f, maxY = 0.0f;
        for (int index = 0; index < source.num_keys; ++index) {
            const int letter = static_cast<int>(lowerCodepoint(
                    static_cast<uint32_t>(source.code_points[index]))) - 'a';
            if (letter < 0 || letter >= 26 || present[letter]) {
                return result;
            }
            present[letter] = true;
            xByLetter[letter] = source.key_cx[index];
            yByLetter[letter] = source.key_cy[index];
            minX = std::min(minX, source.key_cx[index]);
            maxX = std::max(maxX, source.key_cx[index]);
            minY = std::min(minY, source.key_cy[index]);
            maxY = std::max(maxY, source.key_cy[index]);
        }
        const float width = maxX - minX;
        const float height = maxY - minY;
        if (width <= 0.0f || height <= 0.0f) {
            return result;
        }
        for (int letter = 0; letter < 26; ++letter) {
            if (!present[letter]
                    || std::fabs((xByLetter[letter] - minX) / width
                                 - expectedX[letter]) >= 0.12f
                    || std::fabs((yByLetter[letter] - minY) / height
                                 - expectedY[letter]) >= 0.12f) {
                return result;
            }
        }

        constexpr float trainingXOffset = 0.05f;
        constexpr float trainingXScale = 0.90f;
        constexpr float trainingYOffset = 0.1667f;
        constexpr float trainingYScale = 0.6666f;
        result.scaleX = trainingXScale / width;
        result.scaleY = trainingYScale / height;
        result.offsetX = trainingXOffset - minX * result.scaleX;
        result.offsetY = trainingYOffset - minY * result.scaleY;
        for (int letter = 0; letter < 26; ++letter) {
            result.layout.code_points.push_back('a' + letter);
            result.layout.letters.push_back(static_cast<char>('a' + letter));
            result.layout.key_cx.push_back(expectedX[letter] * trainingXScale
                                           + trainingXOffset);
            result.layout.key_cy.push_back(expectedY[letter] * trainingYScale
                                           + trainingYOffset);
        }
        result.layout.num_keys = 26;
        result.layout.build_index();
        result.active = true;
        return result;
    }

    static std::string layoutKey(const std::string &language,
            const swipe_decoder::KeyboardLayout &layout) {
        std::ostringstream result;
        result << language << ':';
        for (int codepoint : layout.code_points) {
            result << std::hex << codepoint << ',';
        }
        return result.str();
    }

    CompactTrie *cachedTrie(const std::string &language,
            const std::string &dictionaryPath,
            const swipe_decoder::KeyboardLayout &layout) {
        const std::string key = layoutKey(language, layout);
        for (auto iterator = cache_.begin(); iterator != cache_.end(); ++iterator) {
            if (iterator->key == key) {
                cache_.splice(cache_.begin(), cache_, iterator);
                return cache_.front().trie.get();
            }
        }
        CacheEntry entry;
        entry.key = key;
        entry.trie = std::make_unique<CompactTrie>(dictionaryPath, layout);
        cache_.push_front(std::move(entry));
        return cache_.front().trie.get();
    }

    void pruneTrieCache() {
        while (cache_.size() > kTrieCacheLimit) {
            auto victim = cache_.end();
            do {
                --victim;
            } while (victim != cache_.begin() && victim->trie.get() == activeTrie_);
            if (victim->trie.get() == activeTrie_) {
                break;
            }
            cache_.erase(victim);
        }
    }

    static std::vector<std::string> contextWords(const std::string &context) {
        std::vector<std::string> result;
        std::istringstream input(context);
        std::string word;
        while (input >> word) {
            result.push_back(word);
            if (result.size() > 8) {
                result.erase(result.begin());
            }
        }
        return result;
    }
};

void usage(const char *program) {
    std::cerr << "Usage: " << program
              << " --encoder PATH [--decoder PATH --lm-model PATH --lm-vocab PATH]"
              << " --dictionary LANGUAGE=PATH [...]\n";
}

} // namespace

int main(int argc, char **argv) {
    std::setlocale(LC_CTYPE, "");
    std::string encoderPath;
    std::string decoderPath;
    std::string lmModelPath;
    std::string lmVocabPath;
    std::unordered_map<std::string, std::string> dictionaries;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--encoder" && index + 1 < argc) {
            encoderPath = argv[++index];
        } else if (argument == "--decoder" && index + 1 < argc) {
            decoderPath = argv[++index];
        } else if (argument == "--lm-model" && index + 1 < argc) {
            lmModelPath = argv[++index];
        } else if (argument == "--lm-vocab" && index + 1 < argc) {
            lmVocabPath = argv[++index];
        } else if (argument == "--dictionary" && index + 1 < argc) {
            const std::string value = argv[++index];
            const std::size_t equals = value.find('=');
            if (equals == std::string::npos || equals == 0 || equals + 1 >= value.size()) {
                usage(argv[0]);
                return 2;
            }
            dictionaries[value.substr(0, equals)] = value.substr(equals + 1);
        } else {
            usage(argv[0]);
            return 2;
        }
    }
    if (encoderPath.empty() || dictionaries.empty()) {
        usage(argv[0]);
        return 2;
    }

    Worker worker(std::move(encoderPath), std::move(decoderPath),
            std::move(lmModelPath), std::move(lmVocabPath),
            std::move(dictionaries));
    std::string line;
    while (std::getline(std::cin, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        worker.handle(line);
    }
    return 0;
}
