/* Render Noto SVG artwork for Sailfish's older Qt renderer. */
const fs = require("fs");
const path = require("path");
const sharp = require("sharp");

const projectRoot = path.resolve(__dirname, "..");
const sourceDirectory = path.join(projectRoot, "emoji", "noto");

async function main() {
    const names = fs.readdirSync(sourceDirectory)
        .filter((name) => name.toLowerCase().endsWith(".svg"))
        .sort();

    for (const name of names) {
        const source = path.join(sourceDirectory, name);
        const target = path.join(sourceDirectory, name.slice(0, -4) + ".png");
        await sharp(source, { density: 192 })
            .resize(128, 128, { fit: "contain" })
            .png()
            .toFile(target);
    }

    process.stdout.write(`Rendered ${names.length} Noto emoji PNG files.\n`);
}

main().catch((error) => {
    process.stderr.write(String(error.stack || error) + "\n");
    process.exit(1);
});
