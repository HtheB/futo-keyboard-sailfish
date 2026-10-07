cmake_minimum_required(VERSION 3.10)
project(futo_keyboard_prediction C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT FUTO_ANDROID_SOURCE)
    message(FATAL_ERROR "FUTO_ANDROID_SOURCE is required")
endif()

find_package(Python3 COMPONENTS Interpreter REQUIRED)

set(JNI_ROOT "${FUTO_ANDROID_SOURCE}/native/jni")
set(SRC_ROOT "${JNI_ROOT}/src")
set(GENERATED_CORE "${CMAKE_CURRENT_BINARY_DIR}/futo_language_model_core.inc")
add_custom_command(
    OUTPUT "${GENERATED_CORE}"
    COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/generate-core.py"
            "${JNI_ROOT}/org_futo_inputmethod_latin_xlm_LanguageModel.cpp"
            "${GENERATED_CORE}"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/generate-core.py"
        "${JNI_ROOT}/org_futo_inputmethod_latin_xlm_LanguageModel.cpp"
    VERBATIM)
add_custom_target(futo_prediction_core DEPENDS "${GENERATED_CORE}")

set(PROTOBUF_SOURCES
    arena.cc arenastring.cc bytestream.cc coded_stream.cc common.cc
    extension_set.cc generated_enum_util.cc
    generated_message_table_driven_lite.cc generated_message_util.cc
    implicit_weak_message.cc int128.cc io_win32.cc message_lite.cc
    parse_context.cc repeated_field.cc status.cc statusor.cc stringpiece.cc
    stringprintf.cc structurally_valid.cc strutil.cc time.cc
    wire_format_lite.cc zero_copy_stream.cc zero_copy_stream_impl.cc
    zero_copy_stream_impl_lite.cc)
list(TRANSFORM PROTOBUF_SOURCES PREPEND "${SRC_ROOT}/third_party/protobuf-lite/")

set(SENTENCEPIECE_SOURCES
    bpe_model.cc char_model.cc error.cc filesystem.cc model_factory.cc
    model_interface.cc normalizer.cc sentencepiece_processor.cc
    unigram_model.cc util.cc word_model.cc)
list(TRANSFORM SENTENCEPIECE_SOURCES PREPEND "${SRC_ROOT}/sentencepiece/")

add_executable(futo-keyboard-prediction
    "${CMAKE_CURRENT_SOURCE_DIR}/futo_prediction.cpp"
    "${GENERATED_CORE}"
    "${SRC_ROOT}/ggml/context.cpp"
    "${SRC_ROOT}/ggml/ggml.c"
    "${SRC_ROOT}/ggml/ggml-alloc.c"
    "${SRC_ROOT}/ggml/ggml-quants.c"
    "${SRC_ROOT}/ggml/ggml-backend.c"
    "${SRC_ROOT}/ggml/llama.cpp"
    "${SRC_ROOT}/ggml/LanguageModel.cpp"
    "${SRC_ROOT}/ggml/ModelMeta.cpp"
    "${SRC_ROOT}/sentencepiece/builtin_pb/sentencepiece_model.pb.cc"
    "${SRC_ROOT}/sentencepiece/builtin_pb/sentencepiece.pb.cc"
    ${PROTOBUF_SOURCES}
    ${SENTENCEPIECE_SOURCES})
add_dependencies(futo-keyboard-prediction futo_prediction_core)

target_include_directories(futo-keyboard-prediction PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${JNI_ROOT}"
    "${SRC_ROOT}"
    "${SRC_ROOT}/sentencepiece/builtin_pb"
    "${SRC_ROOT}/third_party"
    "${SRC_ROOT}/third_party/protobuf-lite"
    "${SRC_ROOT}/third_party/esaxx"
    "${SRC_ROOT}/third_party/darts_clone"
    "${SRC_ROOT}/third_party/absl")

target_compile_definitions(futo-keyboard-prediction PRIVATE
    HAVE_PTHREAD HOST_TOOL)
target_compile_options(futo-keyboard-prediction PRIVATE
    -O2 -fexceptions -Wno-unused-parameter -Wno-unused-function)
target_link_libraries(futo-keyboard-prediction PRIVATE pthread m)
