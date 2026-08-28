.pragma library

// Shared catalogue for the desktop-style key page, toolbar and settings UI.
// Keep the IDs stable: users' toolbar order is stored as a comma-separated
// list in dconf.
var keys = [
    { "id": "esc", "label": "Esc" },
    { "id": "f1", "label": "F1" },
    { "id": "f2", "label": "F2" },
    { "id": "f3", "label": "F3" },
    { "id": "f4", "label": "F4" },
    { "id": "f5", "label": "F5" },
    { "id": "f6", "label": "F6" },
    { "id": "f7", "label": "F7" },
    { "id": "f8", "label": "F8" },
    { "id": "f9", "label": "F9" },
    { "id": "f10", "label": "F10" },
    { "id": "f11", "label": "F11" },
    { "id": "f12", "label": "F12" },
    { "id": "print", "label": "PrtSc" },
    { "id": "pause", "label": "Pause" },
    { "id": "insert", "label": "Ins" },
    { "id": "delete", "label": "Del" },
    { "id": "home", "label": "Home" },
    { "id": "end", "label": "End" },
    { "id": "pageup", "label": "PgUp" },
    { "id": "pagedown", "label": "PgDn" },
    { "id": "ctrl", "label": "Ctrl" },
    { "id": "alt", "label": "Alt" },
    { "id": "altgr", "label": "AltGr" },
    { "id": "super", "label": "Sailfish" },
    { "id": "tab", "label": "Tab" },
    { "id": "menu", "label": "Menu" },
    { "id": "numlock", "label": "Num" },
    { "id": "scrolllock", "label": "Scroll" },
    { "id": "left", "label": "Left" },
    { "id": "up", "label": "Up" },
    { "id": "down", "label": "Down" },
    { "id": "right", "label": "Right" },
    { "id": "backspace", "label": "Backspace" },
    { "id": "space", "label": "Space" },
    { "id": "enter", "label": "Enter" }
]

function definition(keyId) {
    keyId = String(keyId)
    for (var i = 0; i < keys.length; ++i) {
        if (keys[i].id === keyId)
            return keys[i]
    }
    return null
}

function label(keyId) {
    var item = definition(keyId)
    return item ? item.label : String(keyId)
}

function ids() {
    var result = []
    for (var i = 0; i < keys.length; ++i)
        result.push(keys[i].id)
    return result
}

function splitUnique(value) {
    var raw = String(value).split(",")
    var result = []
    for (var i = 0; i < raw.length; ++i) {
        var keyId = raw[i].trim()
        if (definition(keyId) && result.indexOf(keyId) < 0)
            result.push(keyId)
    }
    return result
}

function completeOrder(value) {
    var result = splitUnique(value)
    var all = ids()
    for (var i = 0; i < all.length; ++i) {
        if (result.indexOf(all[i]) < 0)
            result.push(all[i])
    }
    return result
}
