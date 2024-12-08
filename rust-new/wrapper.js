#!/usr/bin/env node

const fs = require("fs").promises;
const { exec } = require("child_process");
const WebSocket = require("ws");

// Variables
let logProcessToConsole = true;
let rconWaitingToStart = false;

(async function main() {
  try {
    await fs.writeFile("latest.log", "");
    console.log("Log file cleared.");
  } catch (err) {
    console.log("Error initializing log file:", err);
    process.exit(1);
  }

  const args = process.argv.slice(process.execArgv.length + 2);
  const startupCmd = args.join(" ");

  if (!startupCmd) {
    console.log("Error: Please specify a startup command.");
    process.exit(1);
  }

  console.log("Starting Rust...");
  const gameProcess = exec(startupCmd);

  process.stdin.resume();
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", initialListener);

  gameProcess.stdout.on("data", filterOutput);
  gameProcess.stderr.on("data", filterOutput);

  gameProcess.on("exit", (code) => {
    console.log(`Rust process exited with code ${code}.`);
    process.exit(code);
  });

  process.on("exit", () => {
    console.log("Cleaning up...");
    gameProcess.kill("SIGTERM");
  });

  rconWaitingToStart = true;
  pollRcon();
})();

function initialListener(data) {
  const command = data.toString().trim();
  if (command === "quit") {
    gameProcess.kill("SIGKILL");
  } else {
    console.log("Unable to run command.  Server is not yet running.");
  }
}

function filterOutput(data) {
  const seenPercentage = {};
  const str = data.toString();

  if (str.startsWith("Loading Prefab Bundle ")) {
    const percentage = str.substring("Loading Prefab Bundle ".length);
    if (seenPercentage[percentage]) return;
    seenPercentage[percentage] = true;
  }

  if (logProcessToConsole) console.log(str);
  // Also append to console.log file
  fs.appendFile("console.log", str).catch(console.log);
}

function createRconPacket(command) {
  return JSON.stringify({
    Identifier: 1,
    Message: command,
    Name: "WebRcon",
  });
}

function pollRcon() {
  const serverHostname = process.env.RCON_IP || "localhost";
  const serverPort = process.env.RCON_PORT || "28016";
  const serverPassword = process.env.RCON_PASS || "default_password";
  const ws = new WebSocket(
    `ws://${serverHostname}:${serverPort}/${serverPassword}`
  );

  ws.on("open", handleRconOpen(ws));
  ws.on("message", handleRconMessage);
  ws.on("error", () => handleRconError);
  ws.on("close", () => console.log("RCON connection closed."));
}

function handleRconOpen(ws) {
  console.log(
    "Connected to RCON.  Please wait until the server status switches to 'Running' before sending commands."
  );

  rconWaitingToStart = false;

  // Send a command to the server to test the connection
  ws.send(createRconPacket("status"));
  logProcessToConsole = false;

  process.stdin.removeListener("data", initialListener);

  process.stdin.on("data", (data) => {
    const command = data.toString().trim();
    ws.send(createRconPacket(command));
  });
}

function handleRconMessage(data) {
  try {
    const json = JSON.parse(data);
    if (json?.Message) {
      console.log(json.Message);
      fs.appendFile("latest.log", `${json.Message}\n`).catch(console.log);
    }
  } catch (err) {
    console.log("Error parsing RCON message:", err);
  }
}

function handleRconError() {
  rconWaitingToStart = true;
  setTimeout(pollRcon, 5000);
}

function handleRconClose() {
  if (!rconWaitingToStart) {
    console.log("RCON connection closed.");
    process.exit();
  }
}
