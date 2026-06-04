# claude-ping

> Keep your Claude Code rate-limit window working for you, not against you.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![npm version](https://img.shields.io/npm/v/claude-code-ping.svg)](https://www.npmjs.com/package/claude-code-ping)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-brightgreen.svg)](#quick-start)
[![Release](https://img.shields.io/github/v/release/jainilsevalia/claude-ping)](https://github.com/jainilsevalia/claude-ping/releases)
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero-orange.svg)](#how-its-implemented)

A zero-dependency, cross-platform tool that pings Claude Code on a schedule to align your rate-limit window resets with your actual work hours.

---

## The Problem

Claude Code's usage limits operate on a **5-hour rolling window**. The window starts when you send your first message. If you don't use Claude until 9 AM, your window runs 9 AM–2 PM and resets right when you're deep in afternoon work. You burn through your fresh budget in the morning, then hit the limit at the worst possible time.

## The Math

**Without claude-ping** — window starts whenever you first open Claude:

```
6AM   7    8    9    10   11   12   1PM  2    3    4    5    6PM
                     ├─── window 1 ───┤  🔒 limit hit
                     ↑ first prompt       ↑ reset at 2 PM
                                          You're locked out during peak hours.
                                          Next fresh budget: 2 PM.
```

**With claude-ping** — `claude-code-ping install --start-at 05:30` pings every 5h:

```
12AM  1    2    3    4    5    6    7    8    9    10   11   12PM
                          ├── ping window ──┤
                          ↑ auto-ping        ↑ resets at 10:30 AM

12PM  1    2    3    4    5    6    7    8    9    10   11   12AM
├─── fresh window ───┤    ├── ping window ──┤
↑ you start work          ↑ auto-ping
Full budget when you                        ↑ resets again at 8:30 PM
need it most.
```

**Key insight:** The rolling window starts on your *first message*. By sending a trivial message early, you control *when* the window starts and therefore *when* it resets. You anchor the cycle so resets happen when you need them.

**Cost of a ping:** One `"hi"` to Haiku ≈ 10-20 tokens. Your 5-hour budget is thousands of times larger. The ping is effectively free.

## How It Works

1. A scheduled task runs `claude -p "hi" --model claude-haiku-4-5-20251001` every 5 hours
2. This anchors your 5-hour rolling window to a predictable cycle
3. When you sit down to work, your window has already been cycling — giving you a fresh or nearly-fresh budget
4. Everything is logged to `~/.claude-ping/claude-ping.log`

## Quick Start

### One-liner (all platforms)

```bash
npx claude-code-ping install
```

### Or install globally

```bash
npm install -g claude-code-ping
claude-code-ping install
```

### Or clone manually

<details>
<summary>Windows (PowerShell — Run as Administrator)</summary>

```powershell
git clone https://github.com/jainilsevalia/claude-ping.git
cd claude-ping
.\scripts\install.ps1
```

</details>

<details>
<summary>macOS / Linux</summary>

```bash
git clone https://github.com/jainilsevalia/claude-ping.git
cd claude-ping
bash scripts/install.sh
```

</details>

## Commands

```bash
claude-code-ping install [options]              # Set up scheduled pinging
claude-code-ping uninstall                      # Remove scheduled task and logs
claude-code-ping ping                           # Run a single ping now
claude-code-ping status                         # Check if scheduler is active
claude-code-ping --help                         # Show help

# Options for install:
#   --interval <hours>    Hours between pings (1-24, default: 5)
#   --start-at <HH:MM>   Anchor pings to a specific time (24-hour format)
```

## Configuration

| Setting | Default | How to change |
|---------|---------|---------------|
| Interval | 5 hours | `claude-code-ping install --interval 4` |
| Start time | Not set (starts immediately) | `claude-code-ping install --start-at 04:00` |
| Model | `claude-haiku-4-5-20251001` | Set `CLAUDE_PING_MODEL` environment variable |
| Log location | `~/.claude-ping/claude-ping.log` | Fixed (logs auto-rotate at 1 MB) |

## Uninstall

```bash
claude-code-ping uninstall
```

Removes the scheduled task and the `~/.claude-ping/` directory completely.

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Active Claude Pro, Max, Team, or Enterprise subscription

## FAQ

**Does this waste my token quota?**

No. A single `"hi"` to Haiku uses ~10-20 tokens. Your 5-hour budget is thousands of times larger. Running 4-5 pings per day has negligible impact.

**Does this work with the weekly limit?**

The weekly limit is a separate, cumulative cap. Pinging optimizes the 5-hour rolling window but does not affect the weekly ceiling. If you're already hitting weekly limits, pinging won't help (but won't hurt either).

**Why not just use cron / Task Scheduler directly?**

You absolutely can. This tool automates the setup, adds logging with rotation, handles cross-platform differences (launchd on macOS, cron on Linux, Task Scheduler on Windows), and provides clean uninstall.

**What if claude CLI isn't in PATH for the scheduled task?**

The install scripts detect Claude's location and configure the scheduler accordingly. On macOS, the launchd plist includes common Claude install paths. On Linux, the ping script sources your shell profile before running.

**How do I choose the best start time?**

Early morning (4–5 AM) works well for most people. The first ping anchors your window, and the reset lands around 9–10 AM — right when you start working. Use `--start-at 04:00` or `--start-at 05:00`.

**What if my auth token expires?**

The ping script logs failures with exit codes. Check `~/.claude-ping/claude-ping.log` — failed pings show `Failed (exit code: X)` instead of `Done.` Re-authenticate with `claude` to fix.

## How It's Implemented

| Platform | Scheduler | Script |
|----------|-----------|--------|
| Windows | Task Scheduler | PowerShell |
| macOS | launchd (LaunchAgent) | Bash |
| Linux | cron | Bash |

Node.js is only used as a thin CLI wrapper. The actual scheduling and pinging uses OS-native tools — no background Node processes.

## License

[MIT](LICENSE) — do whatever you want with it.
