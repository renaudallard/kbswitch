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
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let keyboardMonitor = KeyboardMonitor()
    private let mappingStore = MappingStore()
    private let viewModel = KeyboardViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: "kbswitch"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuView(viewModel: viewModel)
        )

        viewModel.mappingStore = mappingStore
        viewModel.refreshSources()

        keyboardMonitor.delegate = self
        keyboardMonitor.start()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            viewModel.refreshSources()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
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
        viewModel.update(keyboards: keyboardMonitor.keyboards)

        if let layout = mappingStore.layoutID(for: keyboard.identifier) {
            InputSourceManager.select(sourceID: layout)
        }
    }

    func keyboardDisconnected(_ keyboard: ConnectedKeyboard) {
        viewModel.update(keyboards: keyboardMonitor.keyboards)
        switchLayoutForCurrentState()
    }
}
