// Headless Chrome load check via CDP: console errors + screenshots.
// Usage: node tools/browser_check.mjs <url> <outprefix> [clickDeploy]
import { spawn } from "node:child_process";
import { writeFileSync } from "node:fs";
const [url, out = "/tmp/ph", deploy = "1"] = process.argv.slice(2);
const port = 9300 + Math.floor(Math.random() * 500);
const chrome = spawn("google-chrome", [
  "--headless=new", "--no-sandbox", "--enable-unsafe-swiftshader", "--use-angle=swiftshader",
  "--ignore-gpu-blocklist", `--remote-debugging-port=${port}`, "--window-size=1280,720",
  "--autoplay-policy=no-user-gesture-required", "about:blank"], { stdio: "ignore" });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let targets;
for (let i = 0; i < 50; i++) {
  try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); }
}
const page = targets.find((t) => t.type === "page");
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener("open", r));
let id = 0; const pending = new Map(); const logs = []; const errors = [];
ws.addEventListener("message", (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result || m.error); pending.delete(m.id); return; }
  if (m.method === "Runtime.consoleAPICalled") {
    const text = m.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
    logs.push(`[${m.params.type}] ${text}`);
    if (m.params.type === "error") errors.push(text);
  } else if (m.method === "Runtime.exceptionThrown") {
    const d = m.params.exceptionDetails; errors.push("EXC " + (d.exception?.description || d.text));
  } else if (m.method === "Log.entryAdded" && m.params.entry.level === "error") {
    errors.push("LOG " + m.params.entry.text + " " + (m.params.entry.url || ""));
  }
});
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send("Runtime.enable"); await send("Log.enable"); await send("Page.enable");
await send("Page.navigate", { url });
await sleep(25000);
const shot = async (name) => { const r = await send("Page.captureScreenshot", { format: "png" }); writeFileSync(`${out}-${name}.png`, Buffer.from(r.data, "base64")); };
await shot("start");
if (deploy === "1") {
  const click = async (x, y) => {
    await send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
    await send("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 });
    await sleep(60);
    await send("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
  };
  const ev = await send("Runtime.evaluate", { expression: "JSON.stringify([innerWidth, innerHeight])", returnByValue: true });
  const [w, h] = JSON.parse(ev.result.value);
  // Deploy button sits near the bottom of the centered start card.
  for (const dy of [70, 90, 110, 50]) await click(w / 2, h / 2 + dy);
  await sleep(4000);
  await send("Input.dispatchKeyEvent", { type: "keyDown", code: "KeyW", key: "w", windowsVirtualKeyCode: 87 });
  await sleep(1500);
  await send("Input.dispatchKeyEvent", { type: "keyUp", code: "KeyW", key: "w", windowsVirtualKeyCode: 87 });
  await sleep(1500);
  await shot("play");
  if (process.env.ZOOM) {
    for (let i = 0; i < 20; i++) { await send("Input.dispatchMouseEvent", { type: "mouseWheel", x: w / 2, y: h / 2, deltaX: 0, deltaY: -120 }); await sleep(40); }
    await sleep(2500);
    await shot("zoom");
    await send("Input.dispatchKeyEvent", { type: "keyDown", code: "KeyC", key: "c", windowsVirtualKeyCode: 67 });
    await send("Input.dispatchKeyEvent", { type: "keyUp", code: "KeyC", key: "c", windowsVirtualKeyCode: 67 });
    await sleep(500);
    await shot("slide");
  }
}
console.log("LOGS:\n" + logs.slice(-25).join("\n"));
console.log("ERRORS(" + errors.length + "):\n" + errors.join("\n"));
ws.close(); chrome.kill("SIGKILL");
process.exit(0);
