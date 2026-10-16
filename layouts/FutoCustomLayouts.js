.pragma library
.import "FutoDeadKeyData.js" as DeadKeys

var actions = ["text", "space", "backspace", "enter", "shift", "page", "emoji", "symbols", "language", "clipboard", "voice", "esc", "tab", "delete", "insert", "home", "end", "pageup", "pagedown", "left", "right", "up", "down", "ctrl", "alt", "altgr", "super", "menu", "print", "pause", "numlock", "scrolllock", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12", "spacer"]
var labels = {space: "Space", backspace: "⌫", enter: "↵", shift: "⇧", page: "Page", emoji: "☺", symbols: "Symbols", language: "Language", clipboard: "Paste", voice: "Microphone", esc: "Esc", tab: "Tab", delete: "Del", insert: "Ins", home: "Home", end: "End", pageup: "PgUp", pagedown: "PgDn", left: "←", right: "→", up: "↑", down: "↓", ctrl: "Ctrl", alt: "Alt", altgr: "AltGr", super: "Sailfish", menu: "Menu", print: "PrtSc", pause: "Pause", numlock: "Num", scrolllock: "Scroll", spacer: ""}
var combining = {"`":"\u0300", "'":"\u0301", "´":"\u0301", "^":"\u0302", "~":"\u0303", "¯":"\u0304", "˘":"\u0306", ".":"\u0307", "\"":"\u0308", "¨":"\u0308", "°":"\u030a", "˚":"\u030a", "˝":"\u030b", "ˇ":"\u030c", "¸":"\u0327", "˛":"\u0328", "/":"\u0338"}
function compose(dead, text) {
    if (text === " " || text === dead) return dead
    var mark = combining[dead] || dead
    var base = text.charAt(0), suffix = text.slice(1)
    var result = DeadKeys.pairs[base + mark]
    return result ? result + suffix : dead + text
}

function clone(value) { return JSON.parse(JSON.stringify(value)) }
function textValid(value, maximum, optional) {
    if (optional && value === undefined) return true
    if (typeof value !== "string" || value.indexOf("\u0000") >= 0) return false
    var count = 0
    for (var i = 0; i < value.length; ++i) {
        var code = value.charCodeAt(i)
        if (code >= 0xd800 && code <= 0xdbff) {
            if (++i >= value.length || value.charCodeAt(i) < 0xdc00 || value.charCodeAt(i) > 0xdfff) return false
        } else if (code >= 0xdc00 && code <= 0xdfff) return false
        count++
    }
    return count <= maximum
}
function key(action, output, width, label, target) {
    return {action: action || "text", label: label || "", output: output || "",
        shifted: "", width: width || 1, more: [], defaultMore: 0, dead: false, target: target || "", style: "auto"}
}
function showsCard(item, separated) {
    if (item.action === "spacer" || item.style === "plain") return false
    return item.style === "button" || item.action === "space" || item.action === "text" && separated
}
function keyLabel(item) {
    if (item.label) return String(item.label)
    if (item.action === "text") return String(item.output)
    return labels[item.action] !== undefined ? labels[item.action] : item.action.toUpperCase()
}
function newPage(id, name, kind) {
    return {id: id, name: name, kind: kind || "text", rows: [[key("page", "", 1, "⚙", id)]]}
}
function blank(name) {
    return {format: "futo-layout", version: 1, id: "", name: name || "My layout",
        pages: [newPage("letters", "ABC", "text")]}
}
function parse(raw) {
    if (typeof raw === "string" && raw.length > 2097152) return null
    try {
        var data = typeof raw === "string" ? JSON.parse(raw) : clone(raw)
        if (!data || data.version !== 1 || !Array.isArray(data.layouts) || data.layouts.length > 64) return null
        var seen = {}
        for (var i = 0; i < data.layouts.length; ++i) {
            var layout = data.layouts[i]
            if (!valid(layout, true) || seen[layout.id]) return null
            seen[layout.id] = true
        }
        return data
    } catch (error) { return null }
}
function valid(layout, requireId) {
    if (!layout || layout.format !== "futo-layout" || layout.version !== 1
            || !textValid(layout.name, 80) || !layout.name.trim()
            || (requireId && !/^custom-[a-f0-9]{32}$/.test(layout.id))
            || layout.id !== "" && !/^custom-[a-f0-9]{32}$/.test(layout.id)
            || !Array.isArray(layout.pages) || !layout.pages.length || layout.pages.length > 16) return false
    var pages = Object.create(null), count = 0
    for (var p = 0; p < layout.pages.length; ++p) {
        var page = layout.pages[p]
        if (!page || !/^[a-zA-Z0-9_-]{1,48}$/.test(page.id) || pages[page.id]
                || !textValid(page.name, 48) || !page.name.trim()
                || ["text", "symbols", "function"].indexOf(page.kind) < 0
                || !Array.isArray(page.rows) || !page.rows.length || page.rows.length > 12) return false
        pages[page.id] = true
        for (var r = 0; r < page.rows.length; ++r) {
            var row = page.rows[r]
            if (!Array.isArray(row) || !row.length || row.length > 48) return false
            count += row.length
            for (var k = 0; k < row.length; ++k) {
                var item = row[k]
                if (!item || actions.indexOf(item.action) < 0 || typeof item.width !== "number" || !isFinite(item.width)
                        || item.style !== undefined && ["", "auto", "button", "plain"].indexOf(item.style) < 0
                        || item.width < 0.25 || item.width > 20 || !textValid(item.output, 64)
                        || !textValid(item.label, 40) || !textValid(item.shifted, 64, true)
                        || item.action === "text" && !item.output
                        || typeof item.dead !== "boolean" || item.dead && (item.action !== "text" || !textValid(item.output, 1))
                        || !Array.isArray(item.more) || item.more.length > 32
                        || typeof item.defaultMore !== "number" || Math.floor(item.defaultMore) !== item.defaultMore
                        || item.defaultMore < 0 || item.defaultMore >= item.more.length && item.defaultMore !== 0) return false
                for (var m = 0; m < item.more.length; ++m)
                    if (!textValid(item.more[m], 64) || !item.more[m]) return false
            }
        }
    }
    if (count > 2048) return false
    for (p = 0; p < layout.pages.length; ++p)
        for (r = 0; r < layout.pages[p].rows.length; ++r)
            for (k = 0; k < layout.pages[p].rows[r].length; ++k) {
                var cell = layout.pages[p].rows[r][k]
                if (cell.action === "page" && !pages[cell.target]) return false
            }
    return true
}
function pageIndex(layout, id) {
    if (layout) for (var i = 0; i < layout.pages.length; ++i) if (layout.pages[i].id === id) return i
    return 0
}
function textRows(layout) {
    var rows = layout.pages[0].rows, result = []
    for (var r = 0; r < rows.length; ++r) {
        var row = []
        for (var k = 0; k < rows[r].length; ++k) {
            var item = rows[r][k]
            row.push({kind: "character", caption: keyLabel(item), output: item.output,
                shiftedOutput: item.shifted || item.output.toUpperCase(), more: []})
        }
        result.push(row)
    }
    return result
}
// All renderer and editor coordinates share this weighted geometry. In thumb
// mode each half fills its own cluster; no key is allowed to cross the gap.
function geometry(rows, width, height, gap) {
    var result = [], rowHeight = height / Math.max(1, rows.length)
    for (var r = 0; r < rows.length; ++r) {
        var row = rows[r], split = gap > 0 ? Math.ceil(row.length / 2) : row.length
        for (var half = 0; half < (gap > 0 ? 2 : 1); ++half) {
            var begin = half ? split : 0, end = half ? row.length : split
            var total = 0, x = half ? (width + gap) / 2 : 0
            var available = gap > 0 ? (width - gap) / 2 : width
            for (var k = begin; k < end; ++k) total += row[k].width
            for (k = begin; k < end; ++k) {
                var size = available * row[k].width / Math.max(0.25, total)
                result.push({row: r, column: k, x: x, y: r * rowHeight, width: size, height: rowHeight})
                x += size
            }
        }
    }
    return result
}
function move(layout, page, fromRow, fromKey, toRow, toKey) {
    var rows = layout.pages[page].rows
    if (fromRow < 0 || fromRow >= rows.length || toRow < 0 || toRow >= rows.length
            || fromKey < 0 || fromKey >= rows[fromRow].length) return null
    if (fromRow !== toRow && rows[fromRow].length === 1) return null
    var item = rows[fromRow].splice(fromKey, 1)[0]
    if (fromRow === toRow && toKey > fromKey) toKey--
    toKey = Math.max(0, Math.min(rows[toRow].length, toKey))
    rows[toRow].splice(toKey, 0, item)
    return {row: toRow, column: toKey}
}
function fromBuiltin(index, layouts) {
    if (layouts.imeHint(index) && layouts.imeHint(index) !== "qwerty") return null
    var result = blank(layouts.name(index)), rows = []
    for (var r = 0; r < layouts.rowCount(index); ++r) {
        var row = []
        for (var c = 0; c < layouts.rowLength(index, r); ++c) {
            var source = layouts.key(index, r, c), item
            if (source.kind === "shift") item = key("shift")
            else if (source.kind === "delete") item = key("backspace")
            else if (source.kind === "symbols") item = key("page", "", 1, "123", "numbers")
            else if (source.kind === "character") {
                item = key("text", layouts.output(index, r, c, false), 1, layouts.caption(index, r, c, false))
                item.shifted = layouts.output(index, r, c, true)
                var choices = layouts.alternativeChoices(index, r, c, "", false, false)
                for (var m = 0; m < choices.length; ++m) {
                    var output = String(choices[m].output || choices[m].caption || "")
                    if (output && output !== item.output && item.more.indexOf(output) < 0) item.more.push(output)
                }
                var hint = layouts.secondarySymbolForLayout(index, r, c, false)
                if (hint && hint !== item.output && item.more.indexOf(hint) < 0) item.more.push(hint)
                item.defaultMore = Math.max(0, item.more.indexOf(hint))
            } else item = key("spacer")
            row.push(item)
        }
        if (r === layouts.rowCount(index) - 1) {
            var hasShift = false, hasBackspace = false
            for (var ci = 0; ci < row.length; ++ci) { hasShift = hasShift || row[ci].action === "shift"; hasBackspace = hasBackspace || row[ci].action === "backspace" }
            if (!hasShift && !layouts.imeHint(index) && ["arabic", "persian"].indexOf(layouts.script(index)) < 0) row.unshift(key("shift", "", 1.35))
            if (!hasBackspace) row.push(key("backspace", "", 1.35))
        }
        rows.push(row)
    }
    rows.push([key("page", "", 1, "123", "numbers"), key("text", ","), key("space", "", 5), key("text", "."), key("enter")])
    result.pages[0].rows = rows
    var numbers = ["1234567890", "@#$%&*-+=", "()[]{}<>/"], symbols = ["€£¥₺¢§±×÷", "_\\|~`^°•…", "\"'!?;:©®™"]
    function symbolPage(id, name, lists, nextId, nextLabel) {
        var page = {id: id, name: name, kind: "symbols", rows: []}
        for (var i = 0; i < lists.length; ++i) {
            var row = []; for (var j = 0; j < lists[i].length; ++j) row.push(key("text", lists[i].charAt(j)))
            page.rows.push(row)
        }
        page.rows.push([key("page", "", 1, nextLabel, nextId), key("text", ","), key("space", "", 4), key("text", "."), key("backspace"), key("enter")])
        return page
    }
    result.pages.push(symbolPage("numbers", "123", numbers, "symbols", "{&="))
    result.pages.push(symbolPage("symbols", "{&=", symbols, "function", "Fn"))
    var fn = {id: "function", name: "Fn", kind: "function", rows: [[], [], []]}
    for (var f = 1; f <= 12; ++f) fn.rows[0].push(key("f" + f))
    var navigation = ["esc", "tab", "home", "end", "pageup", "pagedown", "insert", "delete"]
    for (var n = 0; n < navigation.length; ++n) fn.rows[1].push(key(navigation[n]))
    fn.rows[2] = [key("page", "", 1, "ABC", "letters"), key("ctrl"), key("super"), key("alt"), key("space", "", 2), key("altgr"), key("left"), key("up"), key("down"), key("right"), key("enter")]
    result.pages.push(fn)
    return result
}
