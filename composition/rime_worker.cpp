// RIME native adapter. Behaviour follows FUTO's ChineseIME and RimeJni;
// Android JNI and coroutine plumbing are replaced by a private line protocol.
#include "protocol.h"
#include "rime_api.h"
#include <memory>

class RimeWorker {
 public:
    RimeWorker(const char* shared, const char* user, const char* schema, bool learning,
               const char* prebuilt = nullptr) {
        api_ = rime_get_api();
        RIME_STRUCT(RimeTraits, traits);
        traits.shared_data_dir = shared;
        traits.user_data_dir = user;
        traits.app_name = "rime.futo-sailfish";
        traits.distribution_name = "FUTO Keyboard for Sailfish OS";
        traits.distribution_code_name = "futo-sailfish";
        traits.distribution_version = "1";
        traits.log_dir = "";
        traits.min_log_level = 3;
        if (prebuilt && *prebuilt) traits.prebuilt_data_dir = prebuilt;
        api_->setup(&traits);
        api_->initialize(&traits);
        if ((!prebuilt || !*prebuilt) && api_->start_maintenance(false))
            api_->join_maintenance_thread();
        session_ = api_->create_session();
        if (!session_ || !api_->select_schema(session_, schema))
            throw std::runtime_error("Chinese input data is missing or incompatible");
        api_->set_option(session_, "ascii_mode", false);
        api_->set_option(session_, "simplification", std::string(schema) == "luna_pinyin_simp");
        // The per-language schema patch resets futo_zh_simp. In particular,
        // both Chinese scripts use the same stroke schema name; inferring the
        // script from that name would force Simplified stroke input to Traditional.
        api_->set_option(session_, "incognito_mode", !learning);
    }
    ~RimeWorker() {
        api_->destroy_session(session_);
        api_->finalize();
    }

    futo::Composition evaluate(const std::string& operation, const std::string& argument) {
        bool consumed = true;
        if (operation == "text") {
            // The Pinyin and stroke layouts output ASCII codes to RIME.
            // Non-ASCII punctuation is committed after finishing composition.
            const auto text = futo::decode_text(argument);
            if (text.size() != 1 || static_cast<unsigned char>(text[0]) >= 128) {
                api_->commit_composition(session_);
                auto state = snapshot(true);
                state.commit += text;
                return state;
            }
            consumed = api_->process_key(session_, static_cast<unsigned char>(text[0]), 0);
            auto state = snapshot(consumed);
            if (!consumed) {
                state.commit += text;
                state.consumed = true; // Literal text is returned exactly once.
            }
            return state;
        } else if (operation == "key") {
            consumed = api_->process_key(session_, futo::parse_number(argument), 0);
        } else if (operation == "select") {
            const int id = futo::parse_number(argument);
            if (!api_->select_candidate(session_, id))
                throw std::runtime_error("candidate is no longer available");
        } else if (operation == "commit") {
            api_->commit_composition(session_);
        } else if (operation == "reset") {
            api_->clear_composition(session_);
        } else if (operation == "cursor") {
            const int position = futo::parse_number(argument);
            const char* input = api_->get_input(session_);
            if (!input || size_t(position) > std::string(input).size())
                throw std::runtime_error("invalid reading cursor");
            api_->set_caret_pos(session_, position);
        } else if (operation == "more") {
            auto state = snapshot(true, futo::parse_number(argument, 2048));
            state.append_candidates = true;
            return state;
        } else if (operation != "state") {
            throw std::runtime_error("unsupported composition command");
        }
        return snapshot(consumed);
    }

 private:
    futo::Composition snapshot(bool consumed, int offset = 0) {
        futo::Composition state;
        state.consumed = consumed;
        state.input = api_->get_input(session_) ? api_->get_input(session_) : "";
        RIME_STRUCT(RimeCommit, commit);
        if (api_->get_commit(session_, &commit)) {
            state.commit = commit.text ? commit.text : "";
            api_->free_commit(&commit);
        }
        RIME_STRUCT(RimeContext, context);
        if (api_->get_context(session_, &context)) {
            state.preedit = context.composition.preedit ? context.composition.preedit : "";
            state.cursor = futo::scalar_count(state.input, api_->get_caret_pos(session_));
            api_->free_context(&context);
        }
        // Like RimeJni, use absolute candidate indices rather than page-local numbers.
        RimeCandidateListIterator iterator{};
        if (api_->candidate_list_from_index(session_, &iterator, offset)) {
            for (int index = offset; index < offset + 64 && api_->candidate_list_next(&iterator); ++index) {
                state.candidates.push_back({index,
                    iterator.candidate.text ? iterator.candidate.text : "",
                    iterator.candidate.comment ? iterator.candidate.comment : ""});
            }
            state.has_more = api_->candidate_list_next(&iterator);
            api_->candidate_list_end(&iterator);
        }
        return state;
    }
    RimeApi* api_ = nullptr;
    RimeSessionId session_ = 0;
};

int main(int argc, char** argv) {
    if (argc != 5 && argc != 6) return 2;
    try {
        RimeWorker worker(argv[1], argv[2], argv[3], std::string(argv[4]) == "learn",
                          argc == 6 ? argv[5] : nullptr);
        if (std::string(argv[4]) == "prepare") return 0;
        futo::reply(worker.evaluate("state", ""));
        std::string line;
        while (std::getline(std::cin, line)) {
            if (line.size() > 8200) throw std::runtime_error("command too long");
            size_t split = line.find('\t');
            futo::reply(worker.evaluate(line.substr(0, split),
                split == std::string::npos ? "" : line.substr(split + 1)));
        }
    } catch (const std::exception&) {
        // Never log input, dictionary paths, or candidate text.
        std::cerr << "Chinese conversion worker failed\n";
        return 1;
    }
}
