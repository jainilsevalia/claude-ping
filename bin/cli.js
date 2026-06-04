#!/usr/bin/env node

const { execSync, spawn } = require("child_process");
const path = require("path");
const os = require("os");
const fs = require("fs");

const isWindows = process.platform === "win32";
const scriptsDir = path.join(__dirname, "..", "scripts");
const logFile = path.join(os.homedir(), ".claude-ping", "claude-ping.log");

const USAGE = `
claude-code-ping — Keep your Claude Code rate-limit window working for you.

Usage:
  claude-code-ping install [--interval <hours>]   Set up scheduled pinging
  claude-code-ping uninstall                      Remove scheduled task and logs
  claude-code-ping ping                           Run a single ping now
  claude-code-ping status                         Check if scheduler is active
  claude-code-ping --help                         Show this help

Examples:
  npx claude-code-ping install                    Install with default 5h interval
  npx claude-code-ping install --interval 4       Install with 4h interval
  npx claude-code-ping status                     Check status and recent pings
`.trim();

function runScript(scriptName, args = []) {
  const ext = isWindows ? ".ps1" : ".sh";
  const scriptPath = path.join(scriptsDir, scriptName + ext);

  if (!fs.existsSync(scriptPath)) {
    console.error(`Script not found: ${scriptPath}`);
    process.exit(1);
  }

  if (isWindows) {
    const psArgs = [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      scriptPath,
      ...args,
    ];
    const child = spawn("powershell.exe", psArgs, { stdio: "inherit" });
    child.on("close", (code) => process.exit(code || 0));
  } else {
    const child = spawn("bash", [scriptPath, ...args], { stdio: "inherit" });
    child.on("close", (code) => process.exit(code || 0));
  }
}

function showStatus() {
  console.log("\nclaude-code-ping status\n");

  // Check scheduler
  let schedulerActive = false;
  try {
    if (isWindows) {
      execSync('schtasks /Query /TN "ClaudePing"', { stdio: "pipe" });
      console.log("[OK] Scheduled task 'ClaudePing' is registered");
      schedulerActive = true;
    } else if (process.platform === "darwin") {
      execSync("launchctl list com.claude-ping", { stdio: "pipe" });
      console.log("[OK] Launchd agent 'com.claude-ping' is loaded");
      schedulerActive = true;
    } else {
      const crontab = execSync("crontab -l 2>/dev/null", {
        encoding: "utf8",
      });
      if (crontab.includes("claude-ping")) {
        console.log("[OK] Cron entry for claude-ping is active");
        schedulerActive = true;
      }
    }
  } catch {
    // scheduler not found
  }

  if (!schedulerActive) {
    console.log("[--] No scheduled task found. Run: claude-code-ping install");
  }

  // Show recent log entries
  console.log("");
  if (fs.existsSync(logFile)) {
    const content = fs.readFileSync(logFile, "utf8").trim();
    const lines = content.split("\n");
    const recent = lines.slice(-10);
    console.log(`Recent pings (${logFile}):`);
    recent.forEach((line) => console.log("  " + line));
  } else {
    console.log("No log file found yet. Pings will appear after first run.");
  }
  console.log("");
}

// Parse arguments
const args = process.argv.slice(2);
const command = args[0];

if (!command || command === "--help" || command === "-h") {
  console.log(USAGE);
  process.exit(0);
}

switch (command) {
  case "install": {
    const intervalIdx = args.indexOf("--interval");
    const scriptArgs = [];
    if (intervalIdx !== -1 && args[intervalIdx + 1]) {
      const hours = args[intervalIdx + 1];
      if (!/^\d+$/.test(hours) || parseInt(hours) < 1 || parseInt(hours) > 24) {
        console.error("Error: --interval must be a number between 1 and 24");
        process.exit(1);
      }
      if (isWindows) {
        scriptArgs.push("-IntervalHours", hours);
      } else {
        scriptArgs.push(hours);
      }
    }
    runScript("install", scriptArgs);
    break;
  }
  case "uninstall":
    runScript("uninstall");
    break;
  case "ping":
    runScript("claude-ping");
    break;
  case "status":
    showStatus();
    break;
  default:
    console.error(`Unknown command: ${command}`);
    console.log(USAGE);
    process.exit(1);
}
