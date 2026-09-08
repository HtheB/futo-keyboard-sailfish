/* Number-row key supplied by an exact generated FUTO layout. */
import QtQuick 2.0

FutoCharacterKey {
    id: numberKey
    property var keyData: ({ kind: "gap" })

    active: keyData && keyData.kind === "character"
    secondaryHintEligible: false
    caption: active ? String(keyData.caption || "") : ""
    captionShifted: active && keyData.shiftedCaption !== undefined
                    ? String(keyData.shiftedCaption) : caption
    keyOutput: active ? String(keyData.output || keyData.caption || "") : ""
    keyOutputShifted: active && keyData.shiftedOutput !== undefined
                      ? String(keyData.shiftedOutput) : keyOutput
    exactAlternativeMode: true
    letterAlternativeChoices: active && keyData.more ? keyData.more : []
    letterAlternativeChoicesShifted: active && keyData.shiftedMore
                                     ? keyData.shiftedMore
                                     : letterAlternativeChoices
}
