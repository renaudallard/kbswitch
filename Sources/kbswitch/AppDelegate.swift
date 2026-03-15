/*
 * Copyright (c) 2026 Renaud Allard <renaud@allard.it>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

import Cocoa

private final class LayoutSelection {
    let keyboard: KeyboardIdentifier
    let layoutID: String?

    init(keyboard: KeyboardIdentifier, layoutID: String?) {
        self.keyboard = keyboard
        self.layoutID = layoutID
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let keyboardMonitor = KeyboardMonitor()
    private let mappingStore = MappingStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "kbswitch")?
                .withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        keyboardMonitor.delegate = self
        keyboardMonitor.start()

        UpdateChecker.checkInBackground()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let sources = InputSourceManager.availableSources()
        let keyboards = keyboardMonitor.keyboards

        if keyboards.isEmpty {
            let item = NSMenuItem(title: "No keyboards detected", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for keyboard in keyboards {
                var title = keyboard.name
                if keyboard.isBuiltIn {
                    title += " (built-in)"
                }
                if #available(macOS 14, *) {
                    menu.addItem(.sectionHeader(title: title))
                } else {
                    let kbItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    kbItem.isEnabled = false
                    menu.addItem(kbItem)
                }

                let selectedLayout = mappingStore.layoutID(for: keyboard.identifier)

                let noneItem = NSMenuItem(title: "None", action: #selector(selectLayout(_:)), keyEquivalent: "")
                noneItem.target = self
                noneItem.representedObject = LayoutSelection(keyboard: keyboard.identifier, layoutID: nil)
                noneItem.state = selectedLayout == nil ? .on : .off
                noneItem.indentationLevel = 1
                menu.addItem(noneItem)

                for source in sources {
                    let item = NSMenuItem(title: source.name, action: #selector(selectLayout(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = LayoutSelection(keyboard: keyboard.identifier, layoutID: source.id)
                    item.state = selectedLayout == source.id ? .on : .off
                    item.indentationLevel = 1
                    menu.addItem(item)
                }

                menu.addItem(NSMenuItem.separator())
            }
        }

        if keyboards.isEmpty {
            menu.addItem(NSMenuItem.separator())
        }

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? LayoutSelection else { return }
        mappingStore.setLayoutID(selection.layoutID, for: selection.keyboard)
        if let layoutID = selection.layoutID {
            InputSourceManager.select(sourceID: layoutID)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.toggle()
    }

    @objc private func checkForUpdates() {
        UpdateChecker.checkNow()
    }

    private func switchLayoutForCurrentState() {
        for kb in keyboardMonitor.keyboards.reversed() {
            if let layout = mappingStore.layoutID(for: kb.identifier) {
                InputSourceManager.select(sourceID: layout)
                return
            }
        }
    }
}

extension AppDelegate: KeyboardMonitorDelegate {
    func keyboardConnected(_ keyboard: ConnectedKeyboard) {
        if let layout = mappingStore.layoutID(for: keyboard.identifier) {
            InputSourceManager.select(sourceID: layout)
        }
    }

    func keyboardDisconnected(_ keyboard: ConnectedKeyboard) {
        switchLayoutForCurrentState()
    }
}
