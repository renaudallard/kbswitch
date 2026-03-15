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

import Foundation
import SwiftUI

final class KeyboardViewModel: ObservableObject {
    @Published var connectedKeyboards: [ConnectedKeyboard] = []
    @Published var availableSources: [InputSource] = []
    @Published var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var mappingStore: MappingStore?

    func update(keyboards: [ConnectedKeyboard]) {
        connectedKeyboards = keyboards
    }

    func refreshSources() {
        availableSources = InputSourceManager.availableSources()
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func selectedLayout(for keyboard: KeyboardIdentifier) -> String? {
        mappingStore?.layoutID(for: keyboard)
    }

    func setLayout(_ layoutID: String?, for keyboard: KeyboardIdentifier) {
        mappingStore?.setLayoutID(layoutID, for: keyboard)
        if let layoutID = layoutID {
            InputSourceManager.select(sourceID: layoutID)
        }
    }

    func toggleLaunchAtLogin() {
        LaunchAtLogin.toggle()
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
