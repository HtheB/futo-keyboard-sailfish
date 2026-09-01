#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
REVISION=18328c3042b066952c0936b3771d492fe2ec289a
BASE_URL="https://huggingface.co/futo-org/futo-swipe"

download() {
    local relative=$1
    local sha256=$2
    local destination="$ROOT/swipe/models/$relative"
    mkdir -p "$(dirname "$destination")"
    curl --fail --location --retry 3 \
        "$BASE_URL/resolve/$REVISION/$relative?download=true" \
        -o "$destination"
    printf '%s  %s\n' "$sha256" "$destination" | sha256sum --check
}

# The encoder is universal and layout-agnostic. The smaller decoder and
# context model are optional refinements used only for a single active English
# QWERTY language; every other language continues through the universal path.
download honorable_sturgeon/model_fp32.pte \
    725242bab5d14345e96ff214e8de2bfbc1f962c232d320df9c24cb82ffd1fbaf
download honorable_sturgeon/metadata.json \
    d2c5aecd89d97e21125046eb1f311b5aed1bdb5805e97316bba70b13f1c7be2c
download magic_macaw/model_fp32.pte \
    01eaf16ac4bc0f1ed0698c240807f0e95e6d427bcf6de04983ffc50736744d85
download magic_macaw/metadata.json \
    65ffc8890de41782eb3322aa96f31df24463ea434a200d3ce84aad4fe7c28a11
download hungry_jellyfish/context_lm.pte \
    74d29f56a513c0c60abcd43df3b16a6b68925cdf4e97e51b094a5275ec2810d7
download hungry_jellyfish/metadata.json \
    3daee38ea94796b676e7f60c3e1cf22525d5ae4dbdfa2787979a99e4573d9495
download hungry_jellyfish/vocab.txt \
    a7db66376783b5a23ee3d4a2aaa8f2499fd9b35f975e92bcb248664c2cf6ebd1

cp "$ROOT/LICENSES/FUTO-SWIPE-MODEL-WEIGHTS-LICENSE.md" \
    "$ROOT/swipe/models/LICENSE.md"
