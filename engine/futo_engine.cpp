/*
 * FUTO Keyboard for Sailfish OS - native dictionary worker
 *
 * This is an independent Sailfish OS integration for FUTO Keyboard's native
 * dictionary data. It is not an official FUTO product. The FUTO-derived
 * native library and dictionaries remain subject to the FUTO Source First
 * License; see LICENSES/FUTO-SOURCE-FIRST-LICENSE.md.
 */

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "defines.h"
#include "ggml/unicode.h"
#include "utils/char_utils.h"

namespace {

struct Entry {
    std::string display;
    std::vector<uint32_t> normalized;
    int probability;
};

struct RankedEntry {
    const Entry *entry;
    std::int64_t score;
};

struct ScoredWord {
    std::string word;
    std::int64_t score;
};

struct CorrectionWord {
    std::string word;
    int score;
};

struct SwipePoint {
    uint32_t key;
    double x;
    double y;
};

struct Analysis {
    bool known = false;
    int knownScore = -1;
    std::vector<ScoredWord> suggestions;
    std::vector<CorrectionWord> corrections;
    std::vector<std::string> phrases;
};

std::vector<uint32_t> normalize(const std::vector<uint32_t> &input) {
    std::vector<uint32_t> output;
    output.reserve(input.size());
    for (uint32_t codePoint : input) {
        output.push_back(static_cast<uint32_t>(latinime::CharUtils::toBaseLowerCase(
                static_cast<int>(codePoint))));
    }
    return output;
}

std::string formatDisplay(const std::string &word, bool capitalizeFirst) {
    std::string output(word);
    if (capitalizeFirst && !output.empty() && output[0] >= 'a' && output[0] <= 'z') {
        output[0] -= ('a' - 'A');
    }
    return output;
}

bool startsWith(const std::vector<uint32_t> &word, const std::vector<uint32_t> &prefix) {
    return word.size() >= prefix.size()
            && std::equal(prefix.begin(), prefix.end(), word.begin());
}

const std::unordered_map<std::u32string, std::string> &englishContractions() {
    static const std::unordered_map<std::u32string, std::string> contractions = {
        {U"im", "I'm"}, {U"ive", "I've"}, {U"ill", "I'll"}, {U"id", "I'd"},
        {U"dont", "don't"}, {U"cant", "can't"}, {U"wont", "won't"},
        {U"youre", "you're"}, {U"youve", "you've"}, {U"youll", "you'll"},
        {U"youd", "you'd"}, {U"theyre", "they're"}, {U"theyve", "they've"},
        {U"theyll", "they'll"}, {U"theyd", "they'd"}
    };
    return contractions;
}

int boundedDistance(const std::vector<uint32_t> &left,
        const std::vector<uint32_t> &right, int maximum) {
    const int leftSize = static_cast<int>(left.size());
    const int rightSize = static_cast<int>(right.size());
    if (std::abs(leftSize - rightSize) > maximum) {
        return maximum + 1;
    }
    std::vector<int> previousPrevious(rightSize + 1);
    std::vector<int> previous(rightSize + 1);
    std::vector<int> current(rightSize + 1);
    for (int j = 0; j <= rightSize; ++j) {
        previous[j] = j;
    }
    for (int i = 1; i <= leftSize; ++i) {
        current[0] = i;
        int rowMinimum = current[0];
        for (int j = 1; j <= rightSize; ++j) {
            const int substitution = previous[j - 1]
                    + (left[i - 1] == right[j - 1] ? 0 : 1);
            current[j] = std::min({previous[j] + 1, current[j - 1] + 1, substitution});
            if (i > 1 && j > 1 && left[i - 1] == right[j - 2]
                    && left[i - 2] == right[j - 1]) {
                current[j] = std::min(current[j], previousPrevious[j - 2] + 1);
            }
            rowMinimum = std::min(rowMinimum, current[j]);
        }
        if (rowMinimum > maximum) {
            return maximum + 1;
        }
        previousPrevious = previous;
        previous = current;
    }
    return previous[rightSize];
}

bool isAdjacentTransposition(const std::vector<uint32_t> &left,
        const std::vector<uint32_t> &right) {
    if (left.size() != right.size() || left.size() < 2) {
        return false;
    }
    std::size_t firstMismatch = left.size();
    for (std::size_t i = 0; i < left.size(); ++i) {
        if (left[i] != right[i]) {
            firstMismatch = i;
            break;
        }
    }
    if (firstMismatch + 1 >= left.size()
            || left[firstMismatch] != right[firstMismatch + 1]
            || left[firstMismatch + 1] != right[firstMismatch]) {
        return false;
    }
    for (std::size_t i = firstMismatch + 2; i < left.size(); ++i) {
        if (left[i] != right[i]) {
            return false;
        }
    }
    return true;
}

std::string escapeJson(const std::string &input) {
    std::ostringstream output;
    for (unsigned char value : input) {
        switch (value) {
        case '\"': output << "\\\""; break;
        case '\\': output << "\\\\"; break;
        case '\b': output << "\\b"; break;
        case '\f': output << "\\f"; break;
        case '\n': output << "\\n"; break;
        case '\r': output << "\\r"; break;
        case '\t': output << "\\t"; break;
        default:
            if (value < 0x20) {
                static const char hex[] = "0123456789abcdef";
                output << "\\u00" << hex[(value >> 4) & 0xf] << hex[value & 0xf];
            } else {
                output << static_cast<char>(value);
            }
        }
    }
    return output.str();
}

std::vector<std::string> splitTabs(const std::string &line) {
    std::vector<std::string> fields;
    std::size_t start = 0;
    while (true) {
        const std::size_t separator = line.find('\t', start);
        if (separator == std::string::npos) {
            fields.push_back(line.substr(start));
            return fields;
        }
        fields.push_back(line.substr(start, separator - start));
        start = separator + 1;
    }
}

double pointDistance(const SwipePoint &left, const SwipePoint &right) {
    const double dx = left.x - right.x;
    const double dy = left.y - right.y;
    return std::sqrt(dx * dx + dy * dy);
}

std::vector<SwipePoint> parseSwipePoints(const std::string &serialized) {
    std::vector<SwipePoint> points;
    std::size_t start = 0;
    while (start < serialized.size()) {
        const std::size_t end = serialized.find(';', start);
        const std::string field = serialized.substr(start,
                end == std::string::npos ? std::string::npos : end - start);
        const std::size_t first = field.find(':');
        const std::size_t second = first == std::string::npos
                ? std::string::npos : field.find(':', first + 1);
        if (first != std::string::npos && second != std::string::npos) {
            try {
                const uint32_t key = static_cast<uint32_t>(std::stoul(field.substr(0, first)));
                const double x = std::stod(field.substr(first + 1, second - first - 1));
                const double y = std::stod(field.substr(second + 1));
                if (std::isfinite(x) && std::isfinite(y) && x >= -0.1 && x <= 1.1
                        && y >= -0.1 && y <= 1.1) {
                    const uint32_t normalizedKey = static_cast<uint32_t>(
                            latinime::CharUtils::toBaseLowerCase(static_cast<int>(key)));
                    points.push_back({normalizedKey, x, y});
                }
            } catch (const std::exception &) {
                return {};
            }
        }
        if (end == std::string::npos) {
            break;
        }
        start = end + 1;
    }
    return points;
}

std::vector<SwipePoint> resampleSwipeCurve(const std::vector<SwipePoint> &points,
        std::size_t sampleCount) {
    if (points.empty() || sampleCount == 0) {
        return {};
    }
    if (points.size() == 1) {
        return std::vector<SwipePoint>(sampleCount, points.front());
    }
    std::vector<double> cumulative(points.size(), 0.0);
    for (std::size_t i = 1; i < points.size(); ++i) {
        cumulative[i] = cumulative[i - 1] + pointDistance(points[i - 1], points[i]);
    }
    const double total = cumulative.back();
    if (total < 0.000001) {
        return std::vector<SwipePoint>(sampleCount, points.front());
    }
    std::vector<SwipePoint> result;
    result.reserve(sampleCount);
    std::size_t segment = 1;
    for (std::size_t sample = 0; sample < sampleCount; ++sample) {
        const double target = total * static_cast<double>(sample)
                / static_cast<double>(sampleCount - 1);
        while (segment + 1 < cumulative.size() && cumulative[segment] < target) {
            ++segment;
        }
        const double segmentStart = cumulative[segment - 1];
        const double segmentLength = cumulative[segment] - segmentStart;
        const double ratio = segmentLength > 0.000001
                ? (target - segmentStart) / segmentLength : 0.0;
        result.push_back({0,
                points[segment - 1].x + (points[segment].x - points[segment - 1].x) * ratio,
                points[segment - 1].y + (points[segment].y - points[segment - 1].y) * ratio});
    }
    return result;
}

double swipeCurveLength(const std::vector<SwipePoint> &points) {
    double result = 0.0;
    for (std::size_t i = 1; i < points.size(); ++i) {
        result += pointDistance(points[i - 1], points[i]);
    }
    return result;
}

bool firstIsUppercase(const std::vector<uint32_t> &codePoints) {
    if (codePoints.empty()) {
        return false;
    }
    const int first = static_cast<int>(codePoints.front());
    return latinime::CharUtils::toLowerCase(first) != first;
}

class DictionaryIndex {
public:
    explicit DictionaryIndex(const std::string &path) {
        loadEntries(path);
        if (mEntries.empty()) {
            throw std::runtime_error("dictionary contains no words: " + path);
        }
        buildExactIndex();
    }

    Analysis analyze(const std::string &queryUtf8, int requestedLimit,
            bool allowEnglishContractions = false) const {
        const int limit = std::max(1, std::min(requestedLimit, 20));
        Analysis analysis;
        std::vector<uint32_t> query;
        try {
            query = codepoints_from_utf8(queryUtf8);
        } catch (const std::exception &) {
            return analysis;
        }
        if (query.empty() || query.size() > MAX_WORD_LENGTH) {
            return analysis;
        }
        const bool capitalize = firstIsUppercase(query);
        const std::vector<uint32_t> normalizedQuery = normalize(query);
        std::vector<RankedEntry> ranked;
        ranked.reserve(256);

        int uppercaseCount = 0;
        for (uint32_t codePoint : query) {
            if (latinime::CharUtils::toLowerCase(static_cast<int>(codePoint))
                    != static_cast<int>(codePoint)) {
                ++uppercaseCount;
            }
        }
        const bool collectCorrections = normalizedQuery.size() >= 3 && uppercaseCount <= 1;

        for (const Entry &entry : mEntries) {
            const int probability = std::max(0, entry.probability);
            if (entry.normalized == normalizedQuery) {
                analysis.known = true;
                analysis.knownScore = std::max(analysis.knownScore, probability);
                ranked.push_back({&entry, 4000000000LL + probability});
                continue;
            }

            std::int64_t suggestionScore = std::numeric_limits<std::int64_t>::min();
            if (startsWith(entry.normalized, normalizedQuery)) {
                const std::int64_t lengthPenalty = static_cast<std::int64_t>(
                        entry.normalized.size() - normalizedQuery.size()) * 1000;
                suggestionScore = 3000000000LL
                        + static_cast<std::int64_t>(probability) * 1000000LL
                        - lengthPenalty;
            } else if (normalizedQuery.size() >= 3) {
                const int maximumDistance = normalizedQuery.size() >= 7 ? 2 : 1;
                const std::size_t comparisonLength = std::min(entry.normalized.size(),
                        normalizedQuery.size() + static_cast<std::size_t>(maximumDistance));
                if (comparisonLength + static_cast<std::size_t>(maximumDistance)
                        >= normalizedQuery.size()) {
                    const std::vector<uint32_t> candidatePrefix(entry.normalized.begin(),
                            entry.normalized.begin() + comparisonLength);
                    const int distance = boundedDistance(
                            normalizedQuery, candidatePrefix, maximumDistance);
                    if (distance <= maximumDistance) {
                        const std::int64_t correctionBase = isAdjacentTransposition(
                                normalizedQuery, candidatePrefix)
                                ? 3400000000LL : 2000000000LL;
                        suggestionScore = correctionBase
                                - static_cast<std::int64_t>(distance) * 200000000LL
                                + static_cast<std::int64_t>(probability) * 1000000LL
                                - static_cast<std::int64_t>(entry.normalized.size()) * 1000LL;
                    }
                }
            }
            if (suggestionScore != std::numeric_limits<std::int64_t>::min()) {
                ranked.push_back({&entry, suggestionScore});
            }

            if (collectCorrections
                    && std::abs(static_cast<int>(entry.normalized.size())
                            - static_cast<int>(normalizedQuery.size())) <= 1
                    && boundedDistance(normalizedQuery, entry.normalized, 1) == 1) {
                const int correctionScore = probability
                        + (isAdjacentTransposition(normalizedQuery, entry.normalized) ? 20 : 0);
                analysis.corrections.push_back({
                        formatDisplay(entry.display, capitalize), correctionScore});
            }
        }

        std::sort(ranked.begin(), ranked.end(), [](const RankedEntry &left,
                const RankedEntry &right) {
            if (left.score != right.score) {
                return left.score > right.score;
            }
            return left.entry->normalized.size() < right.entry->normalized.size();
        });

        analysis.suggestions.reserve(limit);
        for (const RankedEntry &candidate : ranked) {
            const std::string word = formatDisplay(candidate.entry->display, capitalize);
            const auto duplicate = std::find_if(analysis.suggestions.begin(),
                    analysis.suggestions.end(), [&](const ScoredWord &existing) {
                        return existing.word == word;
                    });
            if (word.empty() || duplicate != analysis.suggestions.end()) {
                continue;
            }
            analysis.suggestions.push_back({word, candidate.score});
            if (static_cast<int>(analysis.suggestions.size()) >= limit) {
                break;
            }
        }

        std::sort(analysis.corrections.begin(), analysis.corrections.end(),
                [](const CorrectionWord &left, const CorrectionWord &right) {
            if (left.score != right.score) {
                return left.score > right.score;
            }
            return left.word.size() < right.word.size();
        });
        if (analysis.corrections.size() > 8) {
            analysis.corrections.resize(8);
        }
        const std::u32string normalizedKey(normalizedQuery.begin(), normalizedQuery.end());
        const bool exactEnglishContraction = allowEnglishContractions
                && englishContractions().find(normalizedKey) != englishContractions().end();
        if (!analysis.known || exactEnglishContraction) {
            const std::string phrase = segmentPhrase(normalizedQuery, capitalize,
                    allowEnglishContractions);
            if (!phrase.empty() && phrase != queryUtf8) {
                analysis.phrases.push_back(phrase);
            }
        }
        return analysis;
    }

    std::vector<std::string> suggest(const std::string &queryUtf8, int requestedLimit) const {
        const int limit = std::max(1, std::min(requestedLimit, 20));
        const Analysis analysis = analyze(queryUtf8, limit);
        std::vector<std::string> result;
        result.reserve(limit);
        result.push_back(queryUtf8);
        for (const ScoredWord &candidate : analysis.suggestions) {
            if (candidate.word.empty()
                    || std::find(result.begin(), result.end(), candidate.word) != result.end()) {
                continue;
            }
            result.push_back(candidate.word);
            if (static_cast<int>(result.size()) >= limit) {
                break;
            }
        }
        return result;
    }

    std::vector<ScoredWord> swipe(const std::string &pathData,
            const std::string &geometryData, int requestedLimit, bool capitalize) const {
        const int limit = std::max(1, std::min(requestedLimit, 20));
        const std::vector<SwipePoint> observed = parseSwipePoints(pathData);
        const std::vector<SwipePoint> geometry = parseSwipePoints(geometryData);
        if (observed.size() < 3 || geometry.size() < 20) {
            return {};
        }

        std::unordered_map<uint32_t, SwipePoint> keyCenters;
        for (const SwipePoint &point : geometry) {
            keyCenters[point.key] = point;
        }
        const std::vector<SwipePoint> observedSamples = resampleSwipeCurve(observed, 32);
        const double observedLength = swipeCurveLength(observed);
        if (observedSamples.size() != 32 || observedLength < 0.08) {
            return {};
        }

        std::vector<ScoredWord> ranked;
        ranked.reserve(256);
        for (const Entry &entry : mEntries) {
            if (entry.normalized.size() < 2 || entry.normalized.size() > 32
                    || entry.normalized.front() != observed.front().key
                    || entry.normalized.back() != observed.back().key) {
                continue;
            }
            std::vector<SwipePoint> candidate;
            candidate.reserve(entry.normalized.size());
            bool complete = true;
            for (uint32_t codePoint : entry.normalized) {
                const auto center = keyCenters.find(codePoint);
                if (center == keyCenters.end()) {
                    complete = false;
                    break;
                }
                candidate.push_back(center->second);
            }
            if (!complete || candidate.size() < 2) {
                continue;
            }

            const std::vector<SwipePoint> candidateSamples = resampleSwipeCurve(candidate, 32);
            double shapeCost = 0.0;
            for (std::size_t i = 0; i < observedSamples.size(); ++i) {
                const double distance = pointDistance(observedSamples[i], candidateSamples[i]);
                shapeCost += distance * distance;
            }
            shapeCost /= static_cast<double>(observedSamples.size());

            double visitCost = 0.0;
            for (const SwipePoint &letter : candidate) {
                double closest = std::numeric_limits<double>::max();
                for (const SwipePoint &point : observedSamples) {
                    closest = std::min(closest, pointDistance(letter, point));
                }
                visitCost += closest * closest;
            }
            visitCost /= static_cast<double>(candidate.size());

            const double candidateLength = swipeCurveLength(candidate);
            const double lengthCost = std::abs(std::log(
                    (candidateLength + 0.01) / (observedLength + 0.01)));
            // Reject curves that merely share their first and last letters.  The
            // relatively generous limits still allow a finger to cut corners.
            if (shapeCost > 0.09 || visitCost > 0.055 || lengthCost > 1.25) {
                continue;
            }

            const std::int64_t score = 7000000000LL
                    - static_cast<std::int64_t>(shapeCost * 40000000000.0)
                    - static_cast<std::int64_t>(visitCost * 12000000000.0)
                    - static_cast<std::int64_t>(lengthCost * 350000000.0)
                    + static_cast<std::int64_t>(std::max(0, entry.probability)) * 500000LL
                    - static_cast<std::int64_t>(entry.normalized.size()) * 1000LL;
            ranked.push_back({formatDisplay(entry.display, capitalize), score});
        }

        std::sort(ranked.begin(), ranked.end(), [](const ScoredWord &left,
                const ScoredWord &right) {
            if (left.score != right.score) {
                return left.score > right.score;
            }
            return left.word.size() < right.word.size();
        });
        std::vector<ScoredWord> result;
        result.reserve(limit);
        for (const ScoredWord &candidate : ranked) {
            const auto duplicate = std::find_if(result.begin(), result.end(),
                    [&](const ScoredWord &existing) { return existing.word == candidate.word; });
            if (candidate.word.empty() || duplicate != result.end()) {
                continue;
            }
            result.push_back(candidate);
            if (static_cast<int>(result.size()) >= limit) {
                break;
            }
        }
        return result;
    }

    std::vector<std::string> topWords(int requestedLimit) const {
        const int limit = std::max(1, std::min(requestedLimit, 20));
        std::vector<const Entry *> ranked;
        ranked.reserve(mEntries.size());
        for (const Entry &entry : mEntries) {
            ranked.push_back(&entry);
        }
        std::partial_sort(ranked.begin(), ranked.begin() + std::min<std::size_t>(
                ranked.size(), static_cast<std::size_t>(limit)), ranked.end(),
                [](const Entry *left, const Entry *right) {
                    if (left->probability != right->probability) {
                        return left->probability > right->probability;
                    }
                    return left->normalized.size() < right->normalized.size();
                });
        std::vector<std::string> result;
        result.reserve(limit);
        for (const Entry *entry : ranked) {
            if (entry->display.empty()
                    || std::find(result.begin(), result.end(), entry->display) != result.end()) {
                continue;
            }
            result.push_back(entry->display);
            if (static_cast<int>(result.size()) >= limit) {
                break;
            }
        }
        return result;
    }

    std::string correct(const std::string &queryUtf8) const {
        std::vector<uint32_t> query;
        try {
            query = codepoints_from_utf8(queryUtf8);
        } catch (const std::exception &) {
            return {};
        }
        if (query.size() < 3 || query.size() > MAX_WORD_LENGTH) {
            return {};
        }

        int uppercaseCount = 0;
        for (uint32_t codePoint : query) {
            if (latinime::CharUtils::toLowerCase(static_cast<int>(codePoint))
                    != static_cast<int>(codePoint)) {
                ++uppercaseCount;
            }
        }
        // Preserve acronyms and mixed-case names rather than guessing at them.
        if (uppercaseCount > 1) {
            return {};
        }

        const std::vector<uint32_t> normalizedQuery = normalize(query);
        const Analysis analysis = analyze(queryUtf8, 1);
        if (analysis.known || analysis.corrections.empty()) {
            return {};
        }

        const int bestScore = analysis.corrections[0].score;
        const int secondScore = analysis.corrections.size() > 1
                ? analysis.corrections[1].score : std::numeric_limits<int>::min();

        // The short-word thresholds and runner-up margin deliberately favor missed
        // corrections over replacing names or uncommon valid words.
        const int minimumScore = normalizedQuery.size() == 3 ? 170
                : (normalizedQuery.size() == 4 ? 130 : 90);
        const int minimumMargin = normalizedQuery.size() <= 4 ? 15 : 10;
        if (bestScore < minimumScore
                || (secondScore != std::numeric_limits<int>::min()
                    && bestScore - secondScore < minimumMargin)) {
            return {};
        }
        return analysis.corrections[0].word;
    }

    std::size_t size() const { return mEntries.size(); }

    void writeCompiled(const std::string &path) const {
        std::ofstream output(path, std::ios::binary | std::ios::trunc);
        if (!output) {
            throw std::runtime_error("cannot create compiled dictionary: " + path);
        }
        static const char magic[8] = {'F', 'K', 'S', 'I', 'D', 'X', '1', '\0'};
        output.write(magic, sizeof(magic));
        const uint32_t count = static_cast<uint32_t>(mEntries.size());
        output.write(reinterpret_cast<const char *>(&count), sizeof(count));
        for (const Entry &entry : mEntries) {
            if (entry.display.size() > std::numeric_limits<uint16_t>::max()
                    || entry.normalized.size() > MAX_WORD_LENGTH) {
                continue;
            }
            const uint16_t displaySize = static_cast<uint16_t>(entry.display.size());
            const uint8_t normalizedSize = static_cast<uint8_t>(entry.normalized.size());
            const uint8_t reserved = 0;
            const int32_t probability = entry.probability;
            output.write(reinterpret_cast<const char *>(&displaySize), sizeof(displaySize));
            output.write(reinterpret_cast<const char *>(&normalizedSize), sizeof(normalizedSize));
            output.write(reinterpret_cast<const char *>(&reserved), sizeof(reserved));
            output.write(reinterpret_cast<const char *>(&probability), sizeof(probability));
            output.write(entry.display.data(), entry.display.size());
            output.write(reinterpret_cast<const char *>(entry.normalized.data()),
                         entry.normalized.size() * sizeof(uint32_t));
        }
        if (!output) {
            throw std::runtime_error("cannot write compiled dictionary: " + path);
        }
    }

private:
    struct PhraseState {
        bool valid = false;
        std::int64_t score = std::numeric_limits<std::int64_t>::min();
        bool transformed = false;
        std::vector<std::string> words;
    };

    void buildExactIndex() {
        for (const Entry &entry : mEntries) {
            const std::u32string key(entry.normalized.begin(), entry.normalized.end());
            const auto existing = mExactEntries.find(key);
            if (existing == mExactEntries.end()
                    || existing->second->probability < entry.probability) {
                mExactEntries[key] = &entry;
            }
        }
    }

    std::string segmentPhrase(const std::vector<uint32_t> &query,
            bool capitalizeFirst, bool allowEnglishContractions) const {
        if (query.size() < 2 || query.size() > MAX_WORD_LENGTH) {
            return {};
        }
        const std::size_t maximumWords = 4;
        std::vector<std::vector<PhraseState>> states(query.size() + 1,
                std::vector<PhraseState>(maximumWords + 1));
        states[0][0].valid = true;
        states[0][0].score = 0;

        for (std::size_t start = 0; start < query.size(); ++start) {
            for (std::size_t wordCount = 0; wordCount < maximumWords; ++wordCount) {
                if (!states[start][wordCount].valid) {
                    continue;
                }
                for (std::size_t end = start + 1; end <= query.size(); ++end) {
                    const std::u32string key(query.begin() + start, query.begin() + end);
                    std::string display;
                    int probability = -1;
                    const auto exact = mExactEntries.find(key);
                    if (exact != mExactEntries.end()) {
                        probability = std::max(0, exact->second->probability);
                        if (probability >= 120 && (key.size() > 1 || probability >= 200)) {
                            display = exact->second->display;
                            if (display == "OK") {
                                display = "ok";
                            }
                        }
                    }
                    bool transformed = false;
                    if (allowEnglishContractions) {
                        const auto contraction = englishContractions().find(key);
                        if (contraction != englishContractions().end()) {
                            display = contraction->second;
                            probability = 255;
                            transformed = true;
                        }
                    }
                    if (display.empty()) {
                        continue;
                    }
                    const std::size_t nextCount = wordCount + 1;
                    const std::int64_t nextScore = states[start][wordCount].score
                            + static_cast<std::int64_t>(probability) * 1000000LL
                            - 12000000LL - (transformed ? 0 : 1000LL * key.size());
                    PhraseState &next = states[end][nextCount];
                    if (!next.valid || nextScore > next.score) {
                        next.valid = true;
                        next.score = nextScore;
                        next.transformed = states[start][wordCount].transformed || transformed;
                        next.words = states[start][wordCount].words;
                        next.words.push_back(display);
                    }
                }
            }
        }

        const PhraseState *best = nullptr;
        for (std::size_t count = 1; count <= maximumWords; ++count) {
            const PhraseState &candidate = states[query.size()][count];
            if (!candidate.valid) {
                continue;
            }
            const bool transformedSingle = count == 1 && candidate.transformed;
            if ((count < 2 && !transformedSingle)
                    || (count >= 2 && query.size() < 6 && !candidate.transformed)) {
                continue;
            }
            if (!best || candidate.score > best->score) {
                best = &candidate;
            }
        }
        if (!best) {
            return {};
        }
        std::ostringstream phrase;
        for (std::size_t i = 0; i < best->words.size(); ++i) {
            if (i) {
                phrase << ' ';
            }
            phrase << best->words[i];
        }
        std::string output = phrase.str();
        if (capitalizeFirst && !output.empty() && output[0] >= 'a' && output[0] <= 'z') {
            output[0] -= ('a' - 'A');
        }
        return output;
    }

    void loadEntries(const std::string &path) {
        std::ifstream probe(path, std::ios::binary);
        char magic[8] = {};
        probe.read(magic, sizeof(magic));
        static const char expectedMagic[8] = {'F', 'K', 'S', 'I', 'D', 'X', '1', '\0'};
        if (probe && std::equal(std::begin(magic), std::end(magic), std::begin(expectedMagic))) {
            loadCompiled(probe, path);
            return;
        }
        probe.close();

        std::ifstream input(path);
        if (!input) {
            throw std::runtime_error("cannot open dictionary: " + path);
        }
        std::string line;
        while (std::getline(input, line)) {
            if (line.compare(0, 6, " word=") != 0 || line.find("not_a_word=true") != std::string::npos) {
                continue;
            }
            const std::size_t frequencyMarker = line.find(",f=", 6);
            if (frequencyMarker == std::string::npos) {
                continue;
            }
            const std::string word = line.substr(6, frequencyMarker - 6);
            const std::size_t frequencyEnd = line.find(',', frequencyMarker + 3);
            int probability = 0;
            try {
                probability = std::stoi(line.substr(frequencyMarker + 3,
                        frequencyEnd - (frequencyMarker + 3)));
            } catch (const std::exception &) {
                continue;
            }
            std::vector<uint32_t> display;
            try {
                display = codepoints_from_utf8(word);
            } catch (const std::exception &) {
                continue;
            }
            if (display.empty() || display.size() > MAX_WORD_LENGTH) {
                continue;
            }
            mEntries.push_back({word, normalize(display), probability});
        }
    }

    void loadCompiled(std::ifstream &input, const std::string &path) {
        input.seekg(0, std::ios::end);
        const std::streamoff fileSize = input.tellg();
        if (fileSize <= 8 || fileSize > (1024LL * 1024LL * 1024LL)) {
            throw std::runtime_error("invalid compiled dictionary size: " + path);
        }
        std::vector<char> data(static_cast<std::size_t>(fileSize - 8));
        input.seekg(8, std::ios::beg);
        input.read(data.data(), data.size());
        if (!input) {
            throw std::runtime_error("cannot read compiled dictionary: " + path);
        }
        std::size_t offset = 0;
        auto copyBytes = [&](void *destination, std::size_t size) {
            if (size > data.size() - offset) {
                throw std::runtime_error("truncated compiled dictionary: " + path);
            }
            std::memcpy(destination, data.data() + offset, size);
            offset += size;
        };

        uint32_t count = 0;
        copyBytes(&count, sizeof(count));
        if (count == 0 || count > 2000000) {
            throw std::runtime_error("invalid compiled dictionary header: " + path);
        }
        mEntries.reserve(count);
        for (uint32_t i = 0; i < count; ++i) {
            uint16_t displaySize = 0;
            uint8_t normalizedSize = 0;
            uint8_t reserved = 0;
            int32_t probability = 0;
            copyBytes(&displaySize, sizeof(displaySize));
            copyBytes(&normalizedSize, sizeof(normalizedSize));
            copyBytes(&reserved, sizeof(reserved));
            copyBytes(&probability, sizeof(probability));
            if (displaySize == 0 || displaySize > 1024
                    || normalizedSize == 0 || normalizedSize > MAX_WORD_LENGTH) {
                throw std::runtime_error("invalid compiled dictionary entry: " + path);
            }
            std::string display(displaySize, '\0');
            std::vector<uint32_t> normalized(normalizedSize);
            copyBytes(&display[0], displaySize);
            copyBytes(normalized.data(), normalized.size() * sizeof(uint32_t));
            mEntries.push_back({std::move(display), std::move(normalized), probability});
        }
    }

    std::vector<Entry> mEntries;
    std::unordered_map<std::u32string, const Entry *> mExactEntries;
};

void printJsonWords(const std::vector<std::string> &words) {
    std::cout << "OK\t[";
    for (std::size_t i = 0; i < words.size(); ++i) {
        if (i) {
            std::cout << ',';
        }
        std::cout << '\"' << escapeJson(words[i]) << '\"';
    }
    std::cout << "]" << std::endl;
}

void printJsonString(const std::string &value) {
    std::cout << "OK\t\"" << escapeJson(value) << "\"" << std::endl;
}

void printJsonScoredWords(const std::vector<ScoredWord> &words) {
    std::cout << "OK\t[";
    for (std::size_t i = 0; i < words.size(); ++i) {
        if (i) {
            std::cout << ',';
        }
        std::cout << "{\"word\":\"" << escapeJson(words[i].word)
                  << "\",\"score\":" << words[i].score << '}';
    }
    std::cout << "]" << std::endl;
}

void printJsonAnalysis(const Analysis &analysis) {
    std::cout << "OK\t{\"known\":" << (analysis.known ? "true" : "false")
              << ",\"knownScore\":" << analysis.knownScore
              << ",\"suggestions\":[";
    for (std::size_t i = 0; i < analysis.suggestions.size(); ++i) {
        if (i) {
            std::cout << ',';
        }
        std::cout << "{\"word\":\"" << escapeJson(analysis.suggestions[i].word)
                  << "\",\"score\":" << analysis.suggestions[i].score << '}';
    }
    std::cout << "],\"corrections\":[";
    for (std::size_t i = 0; i < analysis.corrections.size(); ++i) {
        if (i) {
            std::cout << ',';
        }
        std::cout << "{\"word\":\"" << escapeJson(analysis.corrections[i].word)
                  << "\",\"score\":" << analysis.corrections[i].score << '}';
    }
    std::cout << "],\"phrases\":[";
    for (std::size_t i = 0; i < analysis.phrases.size(); ++i) {
        if (i) {
            std::cout << ',';
        }
        std::cout << '\"' << escapeJson(analysis.phrases[i]) << '\"';
    }
    std::cout << "]}" << std::endl;
}

} // namespace

int main(int argc, char **argv) {
    if (argc == 2 && std::string(argv[1]) == "--version") {
        std::cout << "futo-keyboard-sailfish-engine 0.2.1" << std::endl;
        return 0;
    }
    if (argc == 4 && std::string(argv[1]) == "--compile") {
        try {
            DictionaryIndex dictionary(argv[2]);
            dictionary.writeCompiled(argv[3]);
            std::cerr << "compiled " << dictionary.size() << " entries" << std::endl;
            return 0;
        } catch (const std::exception &error) {
            std::cerr << error.what() << std::endl;
            return 3;
        }
    }

    std::unordered_map<std::string, std::string> dictionaryPaths;
    for (int i = 1; i < argc; ++i) {
        const std::string argument(argv[i]);
        if (argument == "--dictionary" && i + 1 < argc) {
            const std::string mapping(argv[++i]);
            const std::size_t equals = mapping.find('=');
            if (equals == std::string::npos || equals == 0 || equals + 1 >= mapping.size()) {
                std::cerr << "invalid --dictionary mapping" << std::endl;
                return 2;
            }
            dictionaryPaths[mapping.substr(0, equals)] = mapping.substr(equals + 1);
        } else {
            std::cerr << "usage: futo-keyboard-engine --dictionary CODE=PATH [...]\n"
                      << "       futo-keyboard-engine --compile SOURCE OUTPUT" << std::endl;
            return 2;
        }
    }
    if (dictionaryPaths.empty()) {
        std::cerr << "at least one dictionary is required" << std::endl;
        return 2;
    }

    std::unordered_map<std::string, std::unique_ptr<DictionaryIndex>> dictionaries;

    std::string line;
    while (std::getline(std::cin, line)) {
        const std::vector<std::string> fields = splitTabs(line);
        if (fields.size() == 1 && fields[0] == "PING") {
            std::cout << "OK\tPONG" << std::endl;
            continue;
        }
        const bool suggestCommand = fields.size() == 4 && fields[0] == "SUGGEST";
        const bool correctCommand = fields.size() == 3 && fields[0] == "CORRECT";
        const bool analyzeCommand = fields.size() == 4 && fields[0] == "ANALYZE";
        const bool topCommand = fields.size() == 3 && fields[0] == "TOP";
        const bool swipeCommand = fields.size() == 6 && fields[0] == "SWIPE";
        if (!suggestCommand && !correctCommand && !analyzeCommand && !topCommand
                && !swipeCommand) {
            std::cout << "ERROR\tinvalid command" << std::endl;
            continue;
        }
        const auto dictionaryPath = dictionaryPaths.find(fields[1]);
        if (dictionaryPath == dictionaryPaths.end()) {
            std::cout << "ERROR\tunknown language" << std::endl;
            continue;
        }
        auto dictionary = dictionaries.find(fields[1]);
        if (dictionary == dictionaries.end()) {
            try {
                std::unique_ptr<DictionaryIndex> index(new DictionaryIndex(dictionaryPath->second));
                std::cerr << "loaded " << fields[1] << " dictionary ("
                          << index->size() << " entries)" << std::endl;
                dictionary = dictionaries.emplace(fields[1], std::move(index)).first;
            } catch (const std::exception &error) {
                std::cout << "ERROR\t" << error.what() << std::endl;
                continue;
            }
        }
        if (correctCommand) {
            printJsonString(dictionary->second->correct(fields[2]));
        } else {
            int limit = 8;
            try {
                limit = std::stoi(fields[2]);
            } catch (const std::exception &) {
                std::cout << "ERROR\tinvalid limit" << std::endl;
                continue;
            }
            if (swipeCommand) {
                printJsonScoredWords(dictionary->second->swipe(
                        fields[4], fields[5], limit, fields[3] == "1"));
            } else if (topCommand) {
                printJsonWords(dictionary->second->topWords(limit));
            } else if (analyzeCommand) {
                const bool englishContractions = fields[1] == "EN" || fields[1] == "EN_GB";
                printJsonAnalysis(dictionary->second->analyze(
                        fields[3], limit, englishContractions));
            } else {
                printJsonWords(dictionary->second->suggest(fields[3], limit));
            }
        }
    }
    return 0;
}
