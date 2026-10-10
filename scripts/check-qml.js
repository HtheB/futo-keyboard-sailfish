/* Parse all project QML files with tree-sitter-qmljs. */
const fs = require("fs");
const path = require("path");
const Parser = require("tree-sitter");
const Qml = require("tree-sitter-qmljs");

const root = path.resolve(__dirname, "..");
const parser = new Parser();
parser.setLanguage(Qml);

function filesBelow(directory) {
    const result = [];
    for (const name of fs.readdirSync(directory).sort()) {
        const candidate = path.join(directory, name);
        const stat = fs.statSync(candidate);
        if (stat.isDirectory()) {
            result.push(...filesBelow(candidate));
        } else if (name.toLowerCase().endsWith(".qml")) {
            result.push(candidate);
        }
    }
    return result;
}

function errorNodes(node, result) {
    if (node.type === "ERROR" || node.isMissing)
        result.push(node);
    for (const child of node.namedChildren)
        errorNodes(child, result);
}

let failed = false;
const requestedDirectories = process.argv.slice(2);
const directories = requestedDirectories.length > 0
    ? requestedDirectories.map((directory) => path.resolve(directory))
    : [path.join(root, "layouts"), path.join(root, "qml")];
const files = directories.flatMap(filesBelow);
const sources = files.map((file) => ({file, source: fs.readFileSync(file, "utf8")}));
let overlayCount = 0;
if (requestedDirectories.length === 0) {
    const file = path.join(root, "vault/futo-keyboard-device-auth.cpp");
    const embedded = [...fs.readFileSync(file, "utf8").matchAll(/R"QML\(([\s\S]*?)\)QML"/g)]
        .map((match) => match[1]);
    if (embedded.length !== 3 || !embedded[0].includes("__UNLOCK_INPUT__"))
        throw new Error("Missing device authentication overlay templates");
    for (const input of embedded.slice(1)) {
        sources.push({file, source: embedded[0].replace("__UNLOCK_INPUT__", input)});
        overlayCount++;
    }
    const toastFile = path.join(root, "vault/futo-keyboard-setup-toast.cpp");
    const toastQml = fs.readFileSync(toastFile, "utf8").match(/R"QML\(([\s\S]*?)\)QML"/);
    if (!toastQml) throw new Error("Missing setup toast template");
    sources.push({file: toastFile, source: toastQml[1]});
}

for (const {file, source} of sources) {
    let tree;
    try {
        // Older node-tree-sitter builds can reject a single input string above
        // their native 32 KiB transfer buffer. Feed large QML files in chunks.
        tree = source.length > 32768
            ? parser.parse((offset) => source.slice(offset, offset + 8192))
            : parser.parse(source);
    } catch (error) {
        failed = true;
        process.stderr.write(`${path.relative(root, file)}: parser failure: ${error.message}\n`);
        continue;
    }
    const errors = [];
    errorNodes(tree.rootNode, errors);
    if (errors.length === 0)
        continue;
    failed = true;
    for (const error of errors) {
        const line = error.startPosition.row + 1;
        const column = error.startPosition.column + 1;
        const sample = source.slice(error.startIndex, Math.min(error.endIndex,
                                                               error.startIndex + 120))
            .replace(/\s+/g, " ");
        process.stderr.write(`${path.relative(root, file)}:${line}:${column}: ${error.type}: ${sample}\n`);
    }
}

if (failed)
    process.exit(1);
process.stdout.write(`Parsed ${files.length} QML files and ${overlayCount} authentication overlays without syntax errors.\n`);
