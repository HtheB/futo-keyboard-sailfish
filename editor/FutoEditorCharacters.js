.pragma library
.import "FutoSymbolData.js" as Symbols

// Expand only the selected block. The grid virtualizes its delegates, including
// the larger symbol categories shared with the keyboard's symbol picker.
var categories = [
    {name: "Latin", icon: "Aa", ranges: [[33, 126], [161, 591], [7680, 7935]]},
    {name: "Greek", icon: "Ω", ranges: [[880, 1023], [7936, 8191]]},
    {name: "Cyrillic", icon: "Я", ranges: [[1024, 1327]]},
    {name: "Arabic", icon: "ع", ranges: [[1568, 1610], [1646, 1747], [1749, 1773], [1776, 1791]]},
    {name: "Diacritics", icon: "◌́", ranges: [[768, 879], [1611, 1631]]}
].concat(Symbols.categories.filter(function(category) { return category.id !== "favorites" }))

function characters(index) {
    var category = categories[index]
    if (!category) return []
    if (category.entries) return category.entries
    var result = []
    for (var r = 0; r < category.ranges.length; ++r)
        for (var cp = category.ranges[r][0]; cp <= category.ranges[r][1]; ++cp)
            result.push(String.fromCharCode(cp))
    return result
}
function display(value) {
    var cp = value.charCodeAt(0)
    return (cp >= 0x300 && cp <= 0x36f || cp >= 0x64b && cp <= 0x65f) ? "◌" + value : value
}
