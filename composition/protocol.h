// Independent Sailfish integration for the conversion engines used by FUTO.
#ifndef FUTO_COMPOSITION_PROTOCOL_H
#define FUTO_COMPOSITION_PROTOCOL_H

#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace futo {
struct Candidate {
    int id;
    std::string text;
    std::string comment;
};

struct Composition {
    bool consumed = true;
    std::string commit;
    std::string preedit;
    std::string input;
    int cursor = 0;  // Unicode scalar position, not UTF-8 bytes.
    std::vector<Candidate> candidates;
    bool has_more = false;
    bool append_candidates = false;
};

inline std::string json_string(const std::string& text) {
    const char* hex = "0123456789abcdef";
    std::string result = "\"";
    for (unsigned char c : text) {
        if (c == '"' || c == '\\') {
            result += '\\';
            result += c;
        } else if (c < 32) {
            result += "\\u00";
            result += hex[c >> 4];
            result += hex[c & 15];
        } else {
            result += c;
        }
    }
    return result + '"';
}

inline void reply(const Composition& state) {
    std::cout << "{\"consumed\":" << (state.consumed ? "true" : "false")
              << ",\"commit\":" << json_string(state.commit)
              << ",\"preedit\":" << json_string(state.preedit)
              << ",\"input\":" << json_string(state.input)
              << ",\"cursor\":" << state.cursor << ",\"candidates\":[";
    for (size_t i = 0; i < state.candidates.size(); ++i) {
        const auto& item = state.candidates[i];
        if (i) std::cout << ',';
        std::cout << "{\"id\":" << item.id << ",\"text\":" << json_string(item.text)
                  << ",\"comment\":" << json_string(item.comment) << '}';
    }
    std::cout << "],\"hasMore\":" << (state.has_more ? "true" : "false")
              << ",\"appendCandidates\":" << (state.append_candidates ? "true" : "false") << "}\n";
    std::cout.flush();
}

inline int hex_digit(char value) {
    if (value >= '0' && value <= '9') return value - '0';
    if (value >= 'a' && value <= 'f') return value - 'a' + 10;
    if (value >= 'A' && value <= 'F') return value - 'A' + 10;
    throw std::runtime_error("invalid text encoding");
}

inline std::string decode_text(const std::string& value) {
    if (value.size() % 2 || value.size() > 8192)
        throw std::runtime_error("invalid text length");
    std::string text;
    for (size_t i = 0; i < value.size(); i += 2) {
        char c = static_cast<char>((hex_digit(value[i]) << 4) | hex_digit(value[i + 1]));
        if (c == 0) throw std::runtime_error("invalid text character");
        text += c;
    }
    return text;
}

inline int parse_number(const std::string& value, int maximum = 1000000) {
    size_t count = 0;
    int number = std::stoi(value, &count);
    if (count != value.size() || number < 0 || number > maximum)
        throw std::runtime_error("invalid command argument");
    return number;
}

inline int scalar_count(const std::string& text, size_t bytes = std::string::npos) {
    int count = 0;
    for (size_t i = 0; i < text.size() && i < bytes; ++i)
        if ((static_cast<unsigned char>(text[i]) & 0xc0) != 0x80) ++count;
    return count;
}
}  // namespace futo
#endif
