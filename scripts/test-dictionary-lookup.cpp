#define main futo_dictionary_worker_main
#include "../engine/futo_engine.cpp"
#undef main

namespace {
int referenceDistance(CodeView left, CodeView right) {
    std::vector<std::vector<int>> distance(left.size() + 1,
            std::vector<int>(right.size() + 1));
    for (std::size_t i = 0; i <= left.size(); ++i) distance[i][0] = i;
    for (std::size_t j = 0; j <= right.size(); ++j) distance[0][j] = j;
    for (std::size_t i = 1; i <= left.size(); ++i)
        for (std::size_t j = 1; j <= right.size(); ++j) {
            distance[i][j] = std::min({distance[i - 1][j] + 1,
                    distance[i][j - 1] + 1,
                    distance[i - 1][j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1)});
            if (i > 1 && j > 1 && left[i - 1] == right[j - 2] && left[i - 2] == right[j - 1])
                distance[i][j] = std::min(distance[i][j], distance[i - 2][j - 2] + 1);
        }
    return distance.back().back();
}

void require(bool condition, const std::string &message) {
    if (!condition) throw std::runtime_error(message);
}

void addWords(std::vector<std::string> &words, const std::string &prefix, int remaining) {
    if (!prefix.empty()) words.push_back(prefix);
    if (remaining == 0) return;
    for (const std::string &letter : {"a", "b", "é"})
        addWords(words, prefix + letter, remaining - 1);
}
}

int main(int argc, char **argv) {
    if (argc != 2) return 64;
    std::vector<std::string> words;
    addWords(words, "", 5);
    for (const std::string &word : {"hello", "help", "helicopter", "the", "teh", "ihave",
            "привет", "привіт", "всё", "все", "العربية", "فارسی", "αλλά", "αλλα", "थाई", "ąęć", "éé"})
        words.push_back(word);
    words.push_back(std::string(MAX_WORD_LENGTH, 'a'));
    words.push_back(std::string(MAX_WORD_LENGTH - 1, 'a') + "b");
    std::ofstream fixture(argv[1]);
    for (std::size_t i = 0; i < words.size(); ++i)
        fixture << " word=" << words[i] << ",f=" << 100 + (i % 150) << ",flags=\n";
    fixture.close();
    DictionaryIndex dictionary(argv[1]);
    require(dictionary.size() == words.size(), "Fixture entries were unexpectedly discarded");

    std::vector<std::vector<uint32_t>> raw, normalized;
    for (const auto &word : words) {
        raw.push_back(codepoints_from_utf8(word));
        normalized.push_back(normalize(raw.back()));
    }
    std::size_t comparisons = 0;
    for (std::size_t i = 0; i < raw.size(); ++i)
        for (std::size_t j = 0; j < raw.size(); ++j)
            for (int maximum : {0, 1, 2}) {
                const int expected = referenceDistance(raw[i], raw[j]);
                const int actual = boundedDistance(raw[i], raw[j], maximum);
                require((actual <= maximum) == (expected <= maximum)
                        && (expected > maximum || actual == expected),
                        "Bounded edit distance differs from the reference matrix");
                ++comparisons;
            }

    auto queries = normalized;
    queries.push_back({});
    queries.push_back(normalize(codepoints_from_utf8("xyz")));
    queries.push_back(normalize(codepoints_from_utf8("првиет")));
    for (std::size_t i = 0; i < normalized.size(); i += 3) {
        auto query = normalized[i];
        if (query.size() > 1) std::swap(query[0], query[1]);
        queries.push_back(query);
        if (query.size() > 2) query.erase(query.begin() + 1);
        queries.push_back(query);
    }
    std::size_t lookups = 0;
    for (const auto &query : queries)
        for (int requested : {-1, 1}) {
            std::vector<std::string> expected, actual;
            const int maximum = requested >= 0 ? requested : (query.size() >= 7 ? 2 : 1);
            for (std::size_t i = 0; !query.empty() && i < normalized.size(); ++i) {
                const auto &word = normalized[i];
                bool eligible = startsWith(word, query);
                if (!eligible && (query.size() >= 3 || requested >= 0)) {
                    CodeView prefix(word.data(), std::min(word.size(), query.size() + maximum));
                    eligible = referenceDistance(query, prefix) <= maximum;
                }
                if (eligible) expected.push_back(words[i]);
            }
            for (const Entry *candidate : dictionary.analysisCandidates(query, requested))
                actual.push_back(dictionary.displayOf(*candidate));
            require(actual == expected, "Indexed lookup lost, added or reordered candidates: "
                    + codepoints_to_utf8(query));
            ++lookups;
        }
    std::remove(argv[1]);
    std::cout << "Dictionary lookup passed: " << comparisons
              << " reference distances and " << lookups << " exhaustive candidate comparisons\n";
}
