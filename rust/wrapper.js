#!/usr/bin/env node

const fs = require("fs");
const { spawn } = require("child_process");
const WebSocket = require("ws");

const LATEST_LOG = "latest.log";
const CONSOLE_LOG = "console.log";

const IGNORED_SUBSTRINGS = [
  "ERROR: Shader",
  "WARNING: Shader",
];

// Hoisted so dedup actually works across multiple data chunks
const seenPercentage = new Set();

// One stdin handler at a time — track and remove on rotation
let activeStdinHandler = null;
let rconWs = null;
let gameProcess = null;
let logProcessToConsole = true;
let exited = false;

// Reconnect backoff state
let rconHasEverConnected = false;
let rconRetryDelay = 5000;
const RCON_RETRY_MAX = 30000;
let rconErrorLogged = false;

// ---------- bootstrap ----------

try {
  fs.writeFileSync(LATEST_LOG, "");
  fs.writeFileSync(CONSOLE_LOG, "");
} catch (err) {
  console.log("Error initializing log files:", err);
  process.exit(1);
}

const args = process.argv.slice(process.execArgv.length + 2);
const startupCmd = args.join(" ").trim();

if (!startupCmd) {
  console.log("Error: Please specify a startup command.");
  process.exit(1);
}

if (!process.env.RCON_PASS) {
  console.log("Error: RCON_PASS is not set. Refusing to start with an empty/default RCON password.");
  process.exit(1);
}

console.log("Starting Rust...");
// spawn with shell so the eval'd STARTUP string (env-var prefixes, redirects, etc.) still works,
// but stream output instead of buffering it like exec() does.
gameProcess = spawn(startupCmd, { shell: true });

gameProcess.stdout.on("data", filterOutput);
gameProcess.stderr.on("data", filterOutput);

gameProcess.on("exit", (code, signal) => {
  exited = true;
  const tail = signal
    ? `Rust process exited with signal ${signal}.\n`
    : `Rust process exited with code ${code ?? 0}.\n`;
  console.log(tail.trimEnd());
  appendLog(CONSOLE_LOG, tail);

  if (rconWs) {
    try { rconWs.terminate(); } catch (_) { /* ignore */ }
  }
  process.exit(code ?? (signal ? 1 : 0));
});

setActiveStdinHandler(initialListener);
process.stdin.resume();
process.stdin.setEncoding("utf8");

// Forward signals so RustDedicated has a chance to save before exit
process.on("SIGINT", () => shutdown("SIGTERM"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

process.on("exit", () => {
  if (exited || !gameProcess) return;
  try { gameProcess.kill("SIGTERM"); } catch (_) { /* ignore */ }
});

pollRcon();

// ---------- handlers ----------

function shutdown(signal) {
  if (exited || !gameProcess) {
    process.exit(0);
    return;
  }
  console.log(`Received ${signal}, asking RustDedicated to shut down...`);
  try { gameProcess.kill("SIGTERM"); } catch (_) { /* ignore */ }
}

function initialListener(data) {
  const command = data.toString().trim();
  if (command === "quit") {
    // Graceful — let Rust save and exit
    try { gameProcess.kill("SIGTERM"); } catch (_) { /* ignore */ }
  } else {
    console.log(`Unable to run "${command}" — RCON is not connected yet.`);
  }
}

function filterOutput(data) {
  const str = data.toString();

  if (IGNORED_SUBSTRINGS.some((s) => str.includes(s))) {
    appendLog(CONSOLE_LOG, str);
    return;
  }

  if (str.startsWith("Loading Prefab Bundle ")) {
    const pct = str.substring("Loading Prefab Bundle ".length);
    if (seenPercentage.has(pct)) return;
    seenPercentage.add(pct);
  }

  if (str.includes("Server startup complete")) {
    // After startup, RCON owns the console; stop double-logging stdout.
    logProcessToConsole = false;
    // Re-emit because Pterodactyl/Pelican occasionally misses the first instance
    console.log(str);
  }

  if (logProcessToConsole) console.log(str);
  appendLog(CONSOLE_LOG, str);
}

function appendLog(file, text) {
  fs.appendFile(file, text, (err) => {
    if (err) console.log(`Error writing to ${file}:`, err);
  });
}

function createRconPacket(command) {
  return JSON.stringify({
    Identifier: 1,
    Message: command,
    Name: "WebRcon",
  });
}

function pollRcon() {
  const host = process.env.RCON_IP || "localhost";
  const port = process.env.RCON_PORT || "28016";
  const pass = process.env.RCON_PASS;

  const ws = new WebSocket(`ws://${host}:${port}/${pass}`);

  ws.on("open", () => handleRconOpen(ws));
  ws.on("message", handleRconMessage);
  ws.on("error", handleRconError);
  ws.on("close", handleRconClose);
}

function handleRconOpen(ws) {
  rconWs = ws;
  rconHasEverConnected = true;
  rconRetryDelay = 5000;
  rconErrorLogged = false;

  console.log("Connected to RCON. Please wait until the server status switches to 'Running' before sending commands.");
  ws.send(createRconPacket("status"));
  logProcessToConsole = false;

  setActiveStdinHandler((data) => {
    const command = data.toString().trim();
    if (!command) return;
    try {
      ws.send(createRconPacket(command));
    } catch (err) {
      console.log("Error sending RCON command:", err);
    }
  });
}

function handleRconMessage(data) {
  try {
    const json = JSON.parse(data);
    if (json && json.Message && json.Type !== "Chat" && json.Message.length > 0) {
      console.log(json.Message);
      appendLog(LATEST_LOG, `${json.Message}\n`);
    }
  } catch (err) {
    console.log("Error parsing RCON message:", err);
  }
}

function handleRconError() {
  if (!rconErrorLogged) {
    console.log("Waiting for RCON to come up...");
    rconErrorLogged = true;
  }
}

function handleRconClose() {
  rconWs = null;
  // Reset stdin to the pre-RCON handler so commands don't disappear
  setActiveStdinHandler(initialListener);

  if (exited) return;

  if (rconHasEverConnected) {
    console.log("RCON connection closed. Reconnecting...");
    appendLog(LATEST_LOG, "RCON connection closed.\n");
    appendLog(CONSOLE_LOG, "RCON connection closed.\n");
    const delay = rconRetryDelay;
    rconRetryDelay = Math.min(rconRetryDelay * 2, RCON_RETRY_MAX);
    setTimeout(pollRcon, delay);
  } else {
    // Still in initial-poll phase — keep the tight 5s cadence
    setTimeout(pollRcon, 5000);
  }
}

function setActiveStdinHandler(handler) {
  if (activeStdinHandler) {
    process.stdin.removeListener("data", activeStdinHandler);
  }
  activeStdinHandler = handler;
  if (handler) {
    process.stdin.on("data", handler);
  }
}
