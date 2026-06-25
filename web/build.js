/* Bundles the game into a single self-contained dist/waspwarfare.html
 * (HTML + CSS + JS inlined) that runs offline from file://.
 * Usage:  node build.js
 */
const fs = require("fs");
const path = require("path");

const root = __dirname;
const css = fs.readFileSync(path.join(root, "styles.css"), "utf8");
const order = [
  "js/data.js", "js/util.js", "js/audio.js", "js/engine.js",
  "js/ai.js", "js/render.js", "js/ui.js", "js/main.js",
];
const js = order
  .map((f) => `/* === ${f} === */\n` + fs.readFileSync(path.join(root, f), "utf8"))
  .join("\n\n");

let html = fs.readFileSync(path.join(root, "index.html"), "utf8");
html = html.replace(/<link rel="stylesheet" href="styles.css"[^>]*>/, "<style>\n" + css + "\n</style>");
html = html.replace(/<script src="js\/[^"]+"><\/script>\s*/g, "");
html = html.replace(/<\/body>/, "<script>\n" + js + "\n</script>\n</body>");

fs.mkdirSync(path.join(root, "dist"), { recursive: true });
fs.writeFileSync(path.join(root, "dist", "waspwarfare.html"), html);
console.log("Wrote dist/waspwarfare.html (" + html.length + " bytes)");
