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

import SwiftUI

struct MenuView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Connected Keyboards")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if viewModel.connectedKeyboards.isEmpty {
                Text("No keyboards detected")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                ForEach(viewModel.connectedKeyboards) { keyboard in
                    KeyboardRow(
                        keyboard: keyboard,
                        sources: viewModel.availableSources,
                        selectedID: viewModel.selectedLayout(for: keyboard.identifier),
                        onSelect: { layoutID in
                            viewModel.setLayout(layoutID, for: keyboard.identifier)
                        }
                    )
                }
            }

            Divider()
                .padding(.vertical, 8)

            Toggle("Launch at Login", isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { _ in viewModel.toggleLaunchAtLogin() }
            ))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.bottom, 8)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 320)
    }
}

struct KeyboardRow: View {
    let keyboard: ConnectedKeyboard
    let sources: [InputSource]
    let selectedID: String?
    let onSelect: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(keyboard.name)
                    .fontWeight(.medium)
                if keyboard.isBuiltIn {
                    Text("(built-in)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            Text(keyboard.identifier.description)
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Layout:", selection: Binding(
                get: { selectedID ?? "" },
                set: { value in
                    onSelect(value.isEmpty ? nil : value)
                }
            )) {
                Text("None").tag("")
                ForEach(sources) { source in
                    Text(source.name).tag(source.id)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
