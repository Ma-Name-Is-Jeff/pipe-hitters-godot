// Phone-landscape CDP check with touch emulation. Scripted steps, console-error report.
// Usage: node tools/phone_check.mjs <url> <outprefix> "wait:25000;shot:start;tap:420,300;drag:x1,y1,x2,y2,ms;hold:x,y,ms;wait:2000"
import { spawn } from "node:child_process";
import { writeFileSync } from "node:fs";
const [url, out, steps = ""] = process.argv.slice(2);
const W = +(process.env.PW || 844), H = +(process.env.PH || 390);
const port = 9300 + Math.floor(Math.random() * 500);
const chrome = spawn("google-chrome", ["--headless=new", "--no-sandbox", "--enable-unsafe-swiftshader", "--use-angle=swiftshader",
  "--ignore-gpu-blocklist", `--remote-debugging-port=${port}`, `--window-size=${W},${H}`, "--autoplay-policy=no-user-gesture-required", "about:blank"], { stdio: "ignore" });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let targets;
for (let i = 0; i < 50; i++) { try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); } }
const ws = new WebSocket(targets.find((t) => t.type === "page").webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener("open", r));
let id = 0; const pending = new Map(); const errors = []; const logs = [];
ws.addEventListener("message", (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result || m.error); pending.delete(m.id); return; }
  if (m.method === "Runtime.consoleAPICalled") {
    const t = m.params.args.map((a) => a.value ?? a.description ?? "").join(" "); logs.push(`[${m.params.type}] ${t}`);
    if (m.params.type === "error") errors.push(t);
  } else if (m.method === "Runtime.exceptionThrown") { const d = m.params.exceptionDetails; errors.push("EXC " + (d.exception?.description || d.text)); }
  else if (m.method === "Log.entryAdded" && m.params.entry.level === "error") errors.push("LOG " + m.params.entry.text + " " + (m.params.entry.url || ""));
});
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send("Runtime.enable"); await send("Log.enable"); await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: W, height: H, deviceScaleFactor: 1, mobile: true });
await send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 });
await send("Page.navigate", { url });
const touch = (type, pts) => send("Input.dispatchTouchEvent", { type, touchPoints: pts.map((p, i) => ({ x: p[0], y: p[1], id: i + 1 })) });
const shot = async (n) => { const r = await send("Page.captureScreenshot", { format: "png" }); writeFileSync(`${out}-${n}.png`, Buffer.from(r.data, "base64")); };
for (const st of steps.split(";").filter(Boolean)) {
  const [k, a = ""] = st.split(/:(.*)/s); const n = a.split(",").map(Number);
  if (k === "wait") await sleep(n[0]);
  else if (k === "shot") await shot(a);
  else if (k === "tap") { await touch("touchStart", [[n[0], n[1]]]); await sleep(80); await touch("touchEnd", []); }
  else if (k === "hold") { await touch("touchStart", [[n[0], n[1]]]); await sleep(n[2]); await touch("touchEnd", []); }
  else if (k === "drag") { const [x1, y1, x2, y2, ms] = n; await touch("touchStart", [[x1, y1]]); for (let i = 1; i <= 8; i++) { await touch("touchMove", [[x1 + (x2 - x1) * i / 8, y1 + (y2 - y1) * i / 8]]); await sleep(ms / 8); } await sleep(150); await touch("touchEnd", []); }
  else if (k === "twin") { // two fingers: x1,y1,x2,y2 (moving stick), a1,b1,a2,b2 (second finger), ms[,shotName]
    const [x1, y1, x2, y2, a1, b1, a2, b2, ms] = n; const nm = a.split(",")[9];
    await touch("touchStart", [[x1, y1], [a1, b1]]);
    await touch("touchMove", [[x2, y2], [a2, b2]]);
    if (nm) { const names = nm.split("|"); for (let i = 0; i < names.length; i++) { await sleep(ms / names.length); await shot(names[i]); } } else await sleep(ms);
    await touch("touchEnd", []); }
}
console.log("LOGS:\n" + logs.slice(-15).join("\n"));
console.log("ERRORS(" + errors.length + "):\n" + errors.join("\n"));
ws.close(); chrome.kill("SIGKILL"); process.exit(0);
