<p align="center">
  <kbd>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</kbd>
  <br>
  <b>kbswitch</b>
  <br>
  <sub>Automatic keyboard layout switching for macOS</sub>
  <br>
  <kbd>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</kbd>
</p>

---

A lightweight menu bar app that automatically switches keyboard input layout
based on which physical keyboard is active. Assign a layout to each keyboard
(built-in, USB, Bluetooth) and **kbswitch** switches instantly when keyboards
connect or disconnect.

## Requirements

| | Minimum |
|---|---|
| **macOS** | 13.0 (Ventura) |
| **Architecture** | Apple Silicon (arm64) |

## Install

Download `kbswitch.dmg` from the
[latest release](https://github.com/renaudallard/kbswitch/releases/latest), open it,
and drag `kbswitch.app` to `/Applications`.

> **Note:** On first launch, macOS will prompt for **Input Monitoring**
> permission (System Settings > Privacy & Security > Input Monitoring). This is
> required to detect keyboard connections.

## Build from source

Build the app bundle:

```sh
bash build-app.sh
```

The app bundle is created at `.build/kbswitch.app`.

To build without the bundle (binary only):

```sh
swift build -c release --arch arm64
```

## Usage

1. **kbswitch** runs in the menu bar (keyboard icon, no dock icon).
2. Click the icon to see connected keyboards.
3. For each keyboard, pick the input layout from the native menu.
4. Mappings are saved automatically. When a mapped keyboard connects, its
   layout activates. When it disconnects, the remaining keyboard's layout
   takes over.

Toggle **Launch at Login** in the menu to start kbswitch automatically.

## How it works

| Component | Details |
|---|---|
| **Keyboard detection** | IOKit HID Manager monitors connect/disconnect events in real time. Each keyboard is identified by vendor ID, product ID, and serial number. |
| **Layout switching** | Carbon Text Input Source Services (`TISSelectInputSource`) changes the active input source. |
| **Configuration** | Keyboard-to-layout mappings are stored in UserDefaults. |
| **No dock icon** | Runs as an `LSUIElement` agent app. |

## Project structure

```
Sources/kbswitch/
    main.swift               Application entry point
    AppDelegate.swift        Status bar menu and keyboard events
    KeyboardMonitor.swift    IOKit HID keyboard detection
    InputSourceManager.swift Carbon TIS input source control
    KeyboardIdentifier.swift Vendor/product/serial identifier
    MappingStore.swift       UserDefaults persistence
    LaunchAtLogin.swift      SMAppService login item toggle
    Info.plist               App bundle metadata
```

## License

BSD 2-Clause. See [LICENSE](LICENSE).
