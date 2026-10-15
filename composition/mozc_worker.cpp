// Mozc native adapter. Uses the same engine and session API as FUTO's MozcJNI.
#include "protocol.h"
#include "base/system_util.h"
#include "data_manager/data_manager.h"
#include "engine/engine.h"
#include "protocol/commands.pb.h"
#include "protocol/config.pb.h"
#include "session/session_handler.h"
#include <memory>

namespace mc = mozc::commands;
class MozcWorker {
 public:
    ~MozcWorker() {
        try {
            mc::Command command;
            command.mutable_input()->set_type(mc::Input::SYNC_DATA);
            evaluate(command);
        } catch (...) {}  // Preserve the previous encrypted snapshot on failure.
    }
    MozcWorker(const char* data, const char* profile, bool learning, const std::string& layout,
               const std::string& options = "flick") {
        if (layout != "qwerty" && layout != "12key" && layout != "12key-latin"
                && layout != "12key-number")
            throw std::runtime_error("unsupported Japanese layout");
        mozc::SystemUtil::SetUserProfileDirectory(profile);
        auto manager = mozc::DataManager::CreateFromFile(data);
        if (!manager.ok()) throw std::runtime_error("Japanese input data is incompatible");
        auto engine = mozc::Engine::CreateEngine(*std::move(manager));
        if (!engine.ok()) throw std::runtime_error("Japanese conversion engine failed");
        handler_ = std::make_unique<mozc::SessionHandler>(*std::move(engine));
        mc::Command command;
        command.mutable_input()->set_type(mc::Input::CREATE_SESSION);
        evaluate(command);
        id_ = command.output().id();
        if (!id_) throw std::runtime_error("Japanese session creation failed");
        command.Clear();
        command.mutable_input()->set_type(mc::Input::SET_REQUEST);
        auto* request = command.mutable_input()->mutable_request();
        request->set_mixed_conversion(true);
        request->set_zero_query_suggestion(true);
        const bool flick_only = options.find("flick") != std::string::npos;
        request->set_special_romanji_table(layout == "12key"
            ? (flick_only ? mc::Request::FLICK_TO_HIRAGANA : mc::Request::TOGGLE_FLICK_TO_HIRAGANA)
            : layout == "12key-latin"
              ? (flick_only ? mc::Request::FLICK_TO_HALFWIDTHASCII : mc::Request::TOGGLE_FLICK_TO_HALFWIDTHASCII)
            : layout == "12key-number"
              ? (flick_only ? mc::Request::FLICK_TO_NUMBER : mc::Request::TOGGLE_FLICK_TO_NUMBER)
            : mc::Request::QWERTY_MOBILE_TO_HIRAGANA);
        request->set_candidate_page_size(64);
        request->set_candidates_size_limit(2048);
        request->set_update_input_mode_from_surrounding_text(false);
        request->set_auto_partial_suggestion(true);
        evaluate(command);
        command.Clear();
        command.mutable_input()->set_type(mc::Input::SET_CONFIG);
        auto* config = command.mutable_input()->mutable_config();
        config->set_session_keymap(mozc::config::Config::MOBILE);
        config->set_incognito_mode(!learning);
        config->set_use_emoji_conversion(true);
        config->set_use_kana_modifier_insensitive_conversion(true);
        config->set_use_typing_correction(true);
        config->set_space_character_form(options.find("half") != std::string::npos
                || layout == "12key-latin" || layout == "12key-number"
                ? mozc::config::Config::FUNDAMENTAL_HALF_WIDTH : mozc::config::Config::FUNDAMENTAL_INPUT_MODE);
        config->set_history_learning_level(learning ? mozc::config::Config::DEFAULT_HISTORY
                                                   : mozc::config::Config::READ_ONLY);
        config->mutable_general_config()->set_upload_usage_stats(false);
        evaluate(command);
        command.Clear();
        command.mutable_input()->set_type(mc::Input::SEND_COMMAND);
        command.mutable_input()->mutable_command()->set_type(mc::SessionCommand::TURN_ON_IME);
        command.mutable_input()->mutable_command()->set_composition_mode(
            layout == "12key-latin" || layout == "12key-number" ? mc::HALF_ASCII : mc::HIRAGANA);
        evaluate(command);
    }

    futo::Composition process(const std::string& operation, const std::string& argument) {
        if (operation == "more") {
            const int offset = futo::parse_number(argument, 2048);
            auto state = last_;
            state.commit.clear();
            state.candidates.clear();
            for (size_t i = offset; i < all_.size() && i < size_t(offset + 64); ++i)
                state.candidates.push_back(all_[i]);
            state.has_more = all_.size() > size_t(offset + 64);
            state.append_candidates = true;
            return state;
        }
        mc::Command command;
        auto* input = command.mutable_input();
        if (operation == "flush") {
            input->set_type(mc::Input::SYNC_DATA);
            evaluate(command);
            auto state = last_;
            state.commit.clear();
            return state;
        }
        if (operation == "text" || operation == "key") {
            input->set_type(mc::Input::SEND_KEY);
            auto* key = input->mutable_key();
            if (operation == "text") {
                const auto text = futo::decode_text(argument);
                if (text.size() == 1 && static_cast<unsigned char>(text[0]) < 128)
                    key->set_key_code(static_cast<unsigned char>(text[0]));
                else {
                    key->set_key_string(text);
                    key->set_special_key(mc::KeyEvent::TEXT_INPUT);
                }
            } else {
                const int code = futo::parse_number(argument);
                if (code == 32) key->set_special_key(mc::KeyEvent::SPACE);
                else if (code == 0xff08) key->set_special_key(mc::KeyEvent::BACKSPACE);
                else if (code == 0xff0d) key->set_special_key(mc::KeyEvent::ENTER);
                else if (code == 0xff1b) key->set_special_key(mc::KeyEvent::ESCAPE);
                else if (code == 0xff51) key->set_special_key(mc::KeyEvent::LEFT);
                else if (code == 0xff53) key->set_special_key(mc::KeyEvent::RIGHT);
                else throw std::runtime_error("unsupported Japanese key");
            }
        } else {
            input->set_type(mc::Input::SEND_COMMAND);
            auto* session = input->mutable_command();
            if (operation == "select") {
                session->set_type(mc::SessionCommand::SUBMIT_CANDIDATE);
                size_t parsed = 0;
                int id = std::stoi(argument, &parsed);
                if (parsed != argument.size()) throw std::runtime_error("invalid candidate id");
                session->set_id(id);
            } else if (operation == "commit") session->set_type(mc::SessionCommand::SUBMIT);
            else if (operation == "reset") session->set_type(mc::SessionCommand::RESET_CONTEXT);
            else if (operation == "state") session->set_type(mc::SessionCommand::GET_STATUS);
            else if (operation == "stop-toggle") session->set_type(mc::SessionCommand::STOP_KEY_TOGGLING);
            else if (operation == "cursor") {
                session->set_type(mc::SessionCommand::MOVE_CURSOR);
                session->set_cursor_position(futo::parse_number(argument));
            }
            else throw std::runtime_error("unsupported composition command");
        }
        evaluate(command);
        const auto& output = command.output();
        futo::Composition state;
        state.consumed = output.consumed();
        if (output.has_result()) state.commit = output.result().value();
        if (output.has_preedit()) {
            for (const auto& segment : output.preedit().segment()) state.preedit += segment.value();
            state.cursor = output.preedit().cursor();
        }
        if (output.has_all_candidate_words()) {
            for (const auto& item : output.all_candidate_words().candidates())
                state.candidates.push_back({item.id(), item.value(), item.annotation().description()});
        } else if (output.has_candidate_window()) {
            for (const auto& item : output.candidate_window().candidate())
                state.candidates.push_back({item.id(), item.value(), item.annotation().description()});
        }
        all_ = state.candidates;
        state.has_more = all_.size() > 64;
        if (state.candidates.size() > 64) state.candidates.resize(64);
        last_ = state;
        return state;
    }
 private:
    void evaluate(mc::Command& command) {
        if (id_) command.mutable_input()->set_id(id_);
        if (!handler_->EvalCommand(&command)) throw std::runtime_error("Japanese command failed");
    }
    std::unique_ptr<mozc::SessionHandler> handler_;
    uint64_t id_ = 0;
    futo::Composition last_;
    std::vector<futo::Candidate> all_;
};

int main(int argc, char** argv) {
    if (argc != 5 && argc != 6) return 2;
    try {
        MozcWorker worker(argv[1], argv[2], std::string(argv[3]) == "learn", argv[4],
                          argc == 6 ? argv[5] : "flick");
        futo::reply(worker.process("state", ""));
        std::string line;
        while (std::getline(std::cin, line)) {
            if (line.size() > 8200) throw std::runtime_error("command too long");
            const auto split = line.find('\t');
            futo::reply(worker.process(line.substr(0, split),
                split == std::string::npos ? "" : line.substr(split + 1)));
        }
    } catch (const std::exception&) {
        std::cerr << "Japanese conversion worker failed\n";
        return 1;
    }
}
