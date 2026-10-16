.pragma library

function show(source, text) {
    for (var owner = source.parent; owner; owner = owner.parent) {
        var children = owner.children || []
        for (var i = 0; i < children.length; i++)
            if (children[i].objectName === "editorToolTip") {
                children[i].show(source, text)
                return
            }
    }
}
