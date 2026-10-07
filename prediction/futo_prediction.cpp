/*
 * Standalone Sailfish worker for FUTO's English KeyboardLM.
 *
 * The model implementation is generated verbatim from the pinned FUTO
 * Android Keyboard source at build time.  This file only supplies the small
 * line protocol used by the Sailfish helper and the exact-key input mixes
 * needed when Maliit does not expose Android's ProximityInfo object.
 */

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include "ggml/LanguageModel.h"
#include "defines.h"

#define TIME_START(name)
#define TIME_END(name)
using std::isnan;

#include "futo_language_model_core.inc"

namespace {

std::vector<std::string> splitTabs(const std::string &line) {
    std::vector<std::string> fields;
    std::size_t start = 0;
    while (true) {
        const std::size_t tab = line.find('\t', start);
        fields.push_back(line.substr(start, tab == std::string::npos
                ? std::string::npos : tab - start));
        if (tab == std::string::npos) {
            return fields;
        }
        start = tab + 1;
    }
}

std::string escapeJson(const std::string &value) {
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
                const char digits[] = "0123456789abcdef";
                output << "\\u00" << digits[character >> 4]
                       << digits[character & 0x0f];
            } else {
                output << static_cast<char>(character);
            }
        }
    }
    return output.str();
}

WordCapitalizeMode capitalizationMode(const std::string &word) {
    if (word.empty() || isFirstCharLowercase(word.c_str(), false)) {
        return WordCapitalizeMode::IgnoredCapitals;
    }
    if (word.size() > 1 && !hasLowercase(word.c_str(), false)) {
        return WordCapitalizeMode::AllCapitals;
    }
    return WordCapitalizeMode::FirstCapital;
}

std::vector<TokenMix> exactKeyMixes(LanguageModelState &state,
                                    const std::string &word) {
    std::vector<TokenMix> mixes;
    mixes.reserve(word.size());
    for (unsigned char character : word) {
        if (!((character >= 'a' && character <= 'z')
                || (character >= 'A' && character <= 'Z'))) {
            continue;
        }
        const unsigned char lower = character >= 'A' && character <= 'Z'
                ? static_cast<unsigned char>(character - 'A' + 'a') : character;
        TokenMix mix{};
        mix.x = -1.0f;
        mix.y = -1.0f;
        mix.mixes[0].weight = 1.0f;
        mix.mixes[0].token = state.specialTokens.LETTERS_TO_IDS[lower - 'a'];
        for (int index = 1; index < NUM_TOKEN_MIX; ++index) {
            mix.mixes[index].weight = 0.0f;
            mix.mixes[index].token = mix.mixes[0].token;
        }
        mixes.push_back(mix);
    }
    return mixes;
}

void printResults(std::vector<std::pair<float, std::string>> results,
                  const std::string &partial, float autocorrectThreshold) {
    for (auto &result : results) {
        result.second = trim(result.second);
    }
    if (!partial.empty()) {
        bool exact = false;
        for (const auto &result : results) {
            if (isExactMatch(result.second, partial)) {
                exact = true;
                break;
            }
        }
        if (exact) {
            for (auto &result : results) {
                if (!isExactMatch(result.second, partial)) {
                    result.first -= 1.0f;
                }
            }
        }
    }
    sortProbabilityPairVectorDescending(results);

    std::string mode = RETURNVAL_UNCERTAIN;
    if (results.size() >= 2) {
        if (results[0].first > autocorrectThreshold * results[1].first) {
            mode = RETURNVAL_AUTOCORRECT;
        } else if (results[0].first <= (autocorrectThreshold * 0.1f)
                                      * results[1].first) {
            mode = RETURNVAL_CLUELESS;
        }
    }
    if (!results.empty() && !partial.empty()
            && results[0].second.size() * 2 < partial.size()) {
        mode = RETURNVAL_CLUELESS;
    }

    std::cout << "OK\t{\"mode\":\"" << mode << "\",\"suggestions\":[";
    for (std::size_t index = 0; index < results.size(); ++index) {
        if (index != 0) {
            std::cout << ',';
        }
        std::cout << "{\"word\":\"" << escapeJson(results[index].second)
                  << "\",\"probability\":" << results[index].first << '}';
    }
    std::cout << "]}" << std::endl;
}

} // namespace

int main(int argc, char **argv) {
    if (argc == 2 && std::string(argv[1]) == "--version") {
        std::cout << "futo-keyboard-prediction 1" << std::endl;
        return 0;
    }
    if (argc != 3 || std::string(argv[1]) != "--model") {
        std::cerr << "usage: futo-keyboard-prediction --model MODEL.gguf"
                  << std::endl;
        return 2;
    }

    llama_log_set([](ggml_log_level, const char *, void *) {}, nullptr);
    LanguageModelState state;
    if (!state.Initialize(argv[2])) {
        std::cerr << "could not load FUTO KeyboardLM model" << std::endl;
        return 3;
    }

    std::string line;
    while (std::getline(std::cin, line)) {
        const std::vector<std::string> fields = splitTabs(line);
        if (fields.size() == 1 && fields[0] == "PING") {
            std::cout << "OK\tPONG" << std::endl;
            continue;
        }
        if (fields.size() != 4 || fields[0] != "PREDICT") {
            std::cout << "ERROR\tinvalid command" << std::endl;
            continue;
        }
        float threshold = 1.0f;
        try {
            threshold = std::stof(fields[3]);
        } catch (const std::exception &) {
            std::cout << "ERROR\tinvalid threshold" << std::endl;
            continue;
        }

        const std::string &context = fields[1];
        const std::string &partial = fields[2];
        std::vector<std::pair<float, std::string>> results;
        if (partial.empty()) {
            results = state.PredictNextWord(context, {});
        } else {
            std::vector<TokenMix> mixes = exactKeyMixes(state, partial);
            if (mixes.empty()) {
                std::cout << "OK\t{\"mode\":\"clueless\",\"suggestions\":[]}"
                          << std::endl;
                continue;
            }
            results = state.PredictCorrection(context, mixes, false,
                    capitalizationMode(partial), {});
        }
        printResults(std::move(results), partial, threshold);
    }
    return 0;
}
