# FUTO typed-prediction attribution

The optional English context-aware prediction model and the KeyboardLM runtime
are taken from the official FUTO Android Keyboard sources.

- Android Keyboard source revision:
  `eaf0389f962b0dba07778d0feab6511e6e98c581`
- Large-resources revision:
  `d87d9dbdf3966bbe18413be375dab2f6c7bbdfdd`
- Model: `raw/ml4_q6_k.gguf` (English v1)
- Model SHA-256:
  `6545c1c9ef2d76e9bfb87ad4fcf2061889513af84fcf30d907412be7fcdedb7b`

FUTO's KeyboardLM implementation and model are distributed with the FUTO
Source First License 1.1-kb included as `FUTO-SOURCE-FIRST-LICENSE.md`.

The worker also builds the copies of llama.cpp/ggml, SentencePiece and
protobuf-lite vendored by that pinned FUTO source revision. llama.cpp/ggml is
MIT licensed. SentencePiece is Copyright 2016 Google Inc. and licensed under
the Apache License, Version 2.0; the complete Apache-2.0 text is already
included as `NOTO-EMOJI-SVG-LICENSE.txt`. protobuf-lite is Copyright 2008
Google Inc. and distributed under its three-clause BSD license in
`PROTOBUF-LITE-BSD-LICENSE.txt`.

The Sailfish integration runs the model only in the separate
`futo-keyboard-prediction` process. The model remains optional downloadable
content and is never bundled in the main RPM.
