/* BSD-derived Sailfish spacebar row using the FUTO gesture-aware space key. */
import QtQuick 2.0
import com.jolla.keyboard 1.0
import Sailfish.Silica 1.0
import ".."

KeyboardRow {
    id: spacebarRow
    splitIndex: 4
    property Item targetLayout
    property int symbolNumberLayout
    // Portrait thumb typing keeps the bottom row continuous. Landscape thumb
    // typing mirrors SwiftKey's separated left/right bottom clusters.
    property int avoidanceWidth: targetLayout && targetLayout.thumbLandscapeMode
                                 ? targetLayout.avoidanceWidth : 0

    FutoSymbolKey { targetLayout: spacebarRow.targetLayout }
    FutoCommaKey { symbolNumberLayout: spacebarRow.symbolNumberLayout }
    FutoVoiceKey { targetLayout: spacebarRow.targetLayout }
    FutoSpacebarKey {
        languageLabel: (keyboard.inputHandler && keyboard.inputHandler.detectedLanguage
                        ? keyboard.inputHandler.detectedLanguage : "FUTO")
        incognitoIndicatorVisible: spacebarRow.targetLayout
                && spacebarRow.targetLayout.effectiveIncognitoMode
    }
    FutoSpacebarKey {
        active: targetLayout && targetLayout.thumbLandscapeMode
        languageLabel: ""
    }
	PeriodKey {}
	// Keep the Enter glyph at its normal size while narrowing only its touch
	// cell.  This moves a normal-width Period key right and extends Space.
	FutoEnterKey {
		targetLayout: spacebarRow.targetLayout
		implicitWidth: Math.round(functionKeyWidth * 0.80)
	}
}
