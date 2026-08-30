/*
 * Offline voice transcription worker for FUTO Keyboard on Sailfish OS.
 *
 * This independent port uses FUTO Voice Input's modified whisper.cpp engine
 * and model.  It is not an official FUTO product.  Audio is read from a local
 * 16 kHz mono signed-16-bit PCM file and no network access is performed.
 */

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <thread>
#include <vector>

#include "whisper.h"

namespace {

std::vector<std::string> splitComma(const std::string &value) {
    std::vector<std::string> result;
    std::size_t start = 0;
    while (start <= value.size()) {
        const std::size_t end = value.find(',', start);
        std::string item = value.substr(start,
                end == std::string::npos ? std::string::npos : end - start);
        if (!item.empty()) {
            result.push_back(item);
        }
        if (end == std::string::npos) {
            break;
        }
        start = end + 1;
    }
    return result;
}

std::string trim(const std::string &value) {
    const std::size_t start = value.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) {
        return {};
    }
    const std::size_t end = value.find_last_not_of(" \t\r\n");
    return value.substr(start, end - start + 1);
}

bool isNonSpeechMarker(const std::string &value) {
    const std::string text = trim(value);
    if (text.size() >= 2 && text.front() == '[' && text.back() == ']') {
        return true;
    }
    return text == "(silence)" || text == "(no speech)" || text == "<silence>";
}

} // namespace

int main(int argc, char **argv) {
    if (argc == 2 && std::string(argv[1]) == "--version") {
        std::cout << "futo-keyboard-voice 0.2.2" << std::endl;
        return 0;
    }
    if (argc != 4) {
        std::cerr << "usage: futo-keyboard-voice MODEL PCM LANGUAGES" << std::endl;
        return 2;
    }

    std::ifstream input(argv[2], std::ios::binary);
    if (!input) {
        std::cerr << "cannot open recorded audio" << std::endl;
        return 3;
    }
    std::vector<char> bytes((std::istreambuf_iterator<char>(input)),
            std::istreambuf_iterator<char>());
    // Reinterpret the little-endian bytes explicitly so this also stays correct
    // if the standard library gives char a signed representation.
    if (bytes.size() < 9600 || bytes.size() % 2 != 0 || bytes.size() > 1920000) {
        std::cerr << "recording length is outside the supported range" << std::endl;
        return 4;
    }
    std::vector<float> samples(bytes.size() / 2);
    double energy = 0.0;
    for (std::size_t i = 0; i < samples.size(); ++i) {
        const uint16_t low = static_cast<unsigned char>(bytes[i * 2]);
        const uint16_t high = static_cast<unsigned char>(bytes[i * 2 + 1]);
        const int16_t sample = static_cast<int16_t>(low | (high << 8));
        samples[i] = static_cast<float>(sample) / 32768.0f;
        energy += static_cast<double>(samples[i]) * static_cast<double>(samples[i]);
    }
    if (std::sqrt(energy / static_cast<double>(samples.size())) < 0.0035) {
        std::cout << std::endl;
        return 0;
    }

    whisper_log_set([](enum ggml_log_level, const char *, void *) {}, nullptr);
    struct whisper_context_params contextParams = whisper_context_default_params();
    contextParams.use_gpu = false;
    struct whisper_context *context = whisper_init_from_file_with_params(argv[1], contextParams);
    if (!context) {
        std::cerr << "cannot load voice model" << std::endl;
        return 5;
    }

    std::vector<int> allowedLanguages;
    for (const std::string &language : splitComma(argv[3])) {
        const int id = whisper_lang_id(language.c_str());
        if (id >= 0 && std::find(allowedLanguages.begin(), allowedLanguages.end(), id)
                == allowedLanguages.end()) {
            allowedLanguages.push_back(id);
        }
    }

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_progress = false;
    params.print_realtime = false;
    params.print_special = false;
    params.print_timestamps = false;
    params.no_timestamps = true;
    params.translate = false;
    params.max_tokens = 256;
    params.greedy.best_of = 2;
    params.temperature_inc = 0.0f;
    params.audio_ctx = std::min(1500,
            static_cast<int>(std::ceil(static_cast<double>(samples.size()) / 320.0)) + 32);
    const unsigned int processors = std::thread::hardware_concurrency();
    params.n_threads = static_cast<int>(std::max(1u, std::min(6u, processors)));
    if (allowedLanguages.size() == 1) {
        params.language = whisper_lang_str(allowedLanguages.front());
    } else if (allowedLanguages.size() > 1) {
        params.language = nullptr;
        params.allowed_langs = allowedLanguages.data();
        params.allowed_langs_size = allowedLanguages.size();
    } else {
        params.language = nullptr;
    }

    const int status = whisper_full(context, params, samples.data(),
            static_cast<int>(samples.size()));
    if (status != 0) {
        whisper_free(context);
        std::cerr << "voice transcription failed" << std::endl;
        return 6;
    }
    std::string transcription;
    const int segments = whisper_full_n_segments(context);
    for (int i = 0; i < segments; ++i) {
        const std::string segment = whisper_full_get_segment_text(context, i);
        if (segment == " you" && i == segments - 1) {
            continue;
        }
        transcription += segment;
    }
    whisper_free(context);
    transcription = trim(transcription);
    if (isNonSpeechMarker(transcription)) {
        transcription.clear();
    }
    std::cout << transcription << std::endl;
    return 0;
}
