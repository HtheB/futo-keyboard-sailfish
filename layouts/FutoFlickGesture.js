.pragma library

// Pure gesture selection; output codes come only from the upstream layout.
function direction(dx, dy, threshold, choices) {
    if (Math.max(Math.abs(dx), Math.abs(dy)) < threshold)
        return "primary"
    var result = Math.abs(dx) >= Math.abs(dy)
            ? (dx < 0 ? "left" : "right") : (dy < 0 ? "up" : "down")
    return choices[result] ? result : "primary"
}

function displayedCaption(choice) {
    if (!choice) return ""
    return choice.caption === "!icon/japanese_key" ? "小゛゜" : String(choice.caption)
}

function isKanaModifier(choice) {
    return !!choice && choice.caption === "!icon/japanese_key"
}

function isKanaPunctuation(choice) {
    return !!choice && choice.caption === "、" && choice.output === "#"
}
