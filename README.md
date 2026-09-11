# SideDeck

> Ambient floating edge dock utility for macOS. Focus, glanceable stats, hydration rhythm, and micro scratchpads right at your screen's edge. Handcrafted by Tejas Telkar.

![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-black?style=flat&logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange?style=flat&logo=swift)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

---

## Overview

SideDeck is a featherweight, native macOS edge dock utility that stays pinned cleanly to the side of your active display. It provides non-intrusive, glanceable micro-utilities without consuming valuable menu bar or bottom Dock real estate.

### Core Features

1. **Focus Ring & Countdown**: Quick toggle pomodoro and deep-work timer with ambient circular ring progression.
2. **Glanceable Time & Battery**: Monospace live clock with system power and Wi-Fi status indicators.
3. **36-Day Habit Grid**: Interactive daily streak heatmap with toggleable milestones and instant local persistence.
4. **Fluid Hydration Slosh**: Real-time interactive water cup with sine-wave fluid animation, tracking daily intake progress.
5. **Quick Micro Scratchpad**: Ephemeral sticky note buffer pinned to the dock for fast copy-pasting and temporary thoughts.
6. **Zero Bloat, Native Performance**: Written 100% in pure SwiftUI & AppKit (`NSPanel`), running at less than 15 MB of RAM and zero GPU overhead.

---

## Installation

### Direct Download
Download the signed DMG directly from Atlas Studios:
- [Download SideDeck 1.1.1 DMG](https://tejastelkar.is-a.dev/assets/SideDeck-1.1.1.dmg)

### Homebrew Cask
```bash
brew install --cask tejastelkar/tap/sidedeck
```

---

## Architecture

- **Frameless Borderless Panel**: Built with `NSPanel` using `.floating`, `.canJoinAllSpaces`, and `.nonactivatingPanel` styles to ensure it never steals keyboard focus from active full-screen IDEs or browsers.
- **Vibrant HUD Material**: Powered by native `NSVisualEffectView` with `.behindWindow` blending and `.hudWindow` vibrancy.
- **Edge Snapping**: Dynamically snaps to either the left or right display edge based on user preference, with status bar quick controls.

---

## Build from Source

```bash
git clone https://github.com/tejastelkar/sidedeck.git
cd sidedeck
./scripts/package.sh
```

The package script selects the full Xcode toolchain when available and writes
`build/SideDeck.app` plus `build/SideDeck-1.1.1.dmg`. Use `--app-only` for a fast
local app build, or `--install` to explicitly replace `/Applications/SideDeck.app`.

Run the regression suite with:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

---

## License

SideDeck is released under the MIT License. Designed & developed by [Tejas Telkar](https://tejastelkar.is-a.dev).
