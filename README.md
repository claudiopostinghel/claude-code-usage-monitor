# Claude Usage Monitor

## Quick Install with Claude Code

Copy and paste the following prompt into Claude Code to automatically build, install, and configure the app:

```
Clone the repo https://github.com/nicolo-postinghel/claude-code-usage-monitor (if not already in the current directory), then build and install it on this Mac. Steps:

1. Check if `xcodegen` is installed, if not install it with `brew install xcodegen`
2. Run `xcodegen generate` in the project root
3. Build with `xcodebuild -scheme ClaudeUsageMonitor -configuration Release build`
4. Find the built .app in the derived data build directory and copy it to /Applications
5. Use AskUserQuestion to ask the user TWO questions:
   - "How often should usage data refresh?" with options: "Every 2 minutes" (120), "Every 5 minutes (Recommended)" (300), "Every 10 minutes" (600), "Every 15 minutes" (900)
   - "Which days do you NOT use Claude?" as multiSelect with options: Monday (2), Tuesday (3), Wednesday (4), Thursday (5), Friday (6), Saturday (7), Sunday (1)
6. Create the directory ~/Library/Application Support/ClaudeUsageMonitor/ if it doesn't exist
7. Write a settings.json file there with:
   {"hasCompletedOnboarding": false, "refreshIntervalSeconds": <chosen value>, "disabledWeekdays": [<chosen day numbers>]}
8. Launch the app with: open "/Applications/Claude Usage Monitor.app"
```

## What is this

A macOS menu bar app that monitors your Claude API usage and rate limits in real-time. It tracks both the 5-hour session window and the 7-day rolling window, and projects when your quota will run out based on your consumption patterns.

## Features

- Real-time monitoring of 5-hour session and 7-day rolling rate limits
- Automatic OAuth integration with Claude Code (preferred) with API key fallback
- 7-day usage history with persistent storage
- Interactive charts showing usage trends and consumption projections
- Weekly quota exhaustion predictions with configurable off-days
- Menu bar icon with at-a-glance status indicator
- Copy usage data to clipboard

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16.0+ with Swift 6.0 (for building from source)
- [Claude Code](https://claude.ai/claude-code) logged in (for automatic OAuth — recommended)

## Manual Installation

```bash
# Install xcodegen if needed
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -scheme ClaudeUsageMonitor -configuration Release build

# Find and copy the app (path may vary)
cp -r ~/Library/Developer/Xcode/DerivedData/ClaudeUsageMonitor-*/Build/Products/Release/Claude\ Usage\ Monitor.app /Applications/

# Launch
open "/Applications/Claude Usage Monitor.app"
```

## Authentication

The app supports two authentication methods, checked in order:

1. **OAuth via Claude Code (recommended)** — If you have Claude Code installed and logged in, the app automatically detects your OAuth credentials from the macOS Keychain. No setup needed. This provides full access to 5-hour and 7-day usage data at zero cost (read-only, no tokens consumed).

2. **API Key (fallback)** — If OAuth credentials are not found, the app prompts you to enter an Anthropic API key manually. Create one at [console.anthropic.com](https://console.anthropic.com) under API Keys. This method provides more limited data.

## Configuration

Settings are stored at:

```
~/Library/Application Support/ClaudeUsageMonitor/settings.json
```

Example:

```json
{
  "hasCompletedOnboarding": true,
  "refreshIntervalSeconds": 300,
  "disabledWeekdays": [1, 7]
}
```

| Field | Description | Default |
|---|---|---|
| `refreshIntervalSeconds` | How often to fetch usage data (in seconds) | `300` (5 min) |
| `disabledWeekdays` | Days you don't use Claude (excluded from projections). `1` = Sunday, `2` = Monday, ..., `7` = Saturday | `[]` |
| `hasCompletedOnboarding` | Whether the initial setup has been completed | `false` |
