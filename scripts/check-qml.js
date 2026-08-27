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

for (const file of files) {
    const source = fs.readFileSync(file, "utf8");
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
process.stdout.write(`Parsed ${files.length} QML files without syntax errors.\n`);
