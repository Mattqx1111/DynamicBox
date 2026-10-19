# DynamicBox 🚀

**DynamicBox** is an open-source, native macOS application that turns your MacBook camera notch into a functional Dynamic Island and productivity hub.

Built with **100% native Swift, SwiftUI, and AppKit**, DynamicBox integrates seamlessly into macOS with zero external dependencies and smooth native physics.

---

## ✨ Features

- 🎵 **Universal Media Island**:
  - Live now-playing status for **Apple Music**, **Spotify**, **YouTube**, **Netflix**, and any browser/system audio output.
  - Dynamic animated waveform with customizable colors (Orange Sunset, Cyber Cyan, Neon Green, Purple Pulse, Monochrome).
  - High-resolution album artwork fetched locally with async fallback.
  - Interactive scrub bar (drag or click to seek) and **-15s / +15s** quick-skip buttons.

- 🪟 **Smart Notch Adaptation**:
  - **Collision-Aware Wings**: Automatically detects long left menu items (like "Справка" / "Help") or crowded right-side status icons, dynamically adapting between Symmetric, Right-Only, Left-Only, and Flush modes.
  - **Outer Island Toggle (👁️)**: Instant one-click toggle to hide the compact wings completely behind the physical MacBook notch (0 pixels protruding into the menu bar).
  - **Full-Screen Detection**: Automatically hides when watching videos or playing games in full-screen mode.
  - **Mission Control / Exposé Integration**: Hides during trackpad multi-finger app-switching gestures.

- 📁 **Temporary File Shelf**:
  - Drag files onto the notch to stash them temporarily.
  - Drag them out into Finder, Telegram, Slack, Mail, or any other app.
  - Dedicated **AirDrop Drop Zone** for instant 1-drop wireless sharing.

- 📋 **Secure Clipboard History**:
  - Keeps history of copied text and copied Finder files with full system fidelity.
  - **Privacy First**: Automatically detects and ignores password managers (1Password, Bitwarden, KeePass, Apple Passwords) and transient/concealed pasteboard data.

- ⏱️ **Timer & Pomodoro**:
  - Focus timer with presets (5m, 15m, 25m, 45m, 60m).
  - Displays remaining countdown directly in the compact notch.

- 🌙 **Do Not Disturb (Focus) Toggle**:
  - Quick 1-click toggle for macOS Focus / Do Not Disturb mode directly from the notch header and quick tools.

- ⌨️ **Global Shortcut**:
  - Press `⌥ Space` (Option + Space) anywhere to expand or collapse the DynamicBox hub.

---

## 🛠️ System Requirements

- **Operating System**: macOS 13.0 (Ventura) or later (macOS Sonoma & macOS Sequoia fully supported).
- **Architecture**: Apple Silicon (M1/M2/M3/M4) & Intel Macs.
- **Hardware**: Designed for notched MacBooks (MacBook Pro 14"/16", MacBook Air 13"/15"), with full support as a floating pill on non-notch Macs and external monitors.

---

## 📦 Building and Installing

Clone the repository and run the automated installer:

```bash
git clone https://github.com/<your-username>/DynamicBox.git
cd DynamicBox
chmod +x install.sh
./install.sh
```

The script will:
1. Compile the native binary using `swiftc`.
2. Package `DynamicBox.app` into `/Applications`.
3. Register a login LaunchAgent for optional automatic startup.
4. Launch the application.

### Manual Packaging

To package the `.app` bundle without installing:

```bash
./package_app.sh
```

---

## 🔒 Privacy & Security

- **100% Local**: No analytics, telemetry, or user tracking.
- **Concealed Data Protection**: Password entries and concealed clipboard types are strictly ignored.
- **No Keystroke Logging**: Global shortcuts use the native Carbon Event Dispatcher target.
- **Sandboxed File References**: Files in the shelf are held by URL without copying or duplicating file data on disk.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
