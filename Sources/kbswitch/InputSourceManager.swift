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

import Carbon
import Foundation

struct InputSource: Identifiable {
    let id: String
    let name: String
}

enum InputSourceManager {
    static func availableSources() -> [InputSource] {
        let conditions: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]

        guard let list = TISCreateInputSourceList(conditions as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        return list.compactMap { source in
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
                return nil
            }
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
            return InputSource(id: id, name: name)
        }
    }

    static func select(sourceID: String) {
        let conditions: [String: Any] = [
            kTISPropertyInputSourceID as String: sourceID,
        ]

        guard let list = TISCreateInputSourceList(conditions as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource],
            let source = list.first else {
            return
        }

        let status = TISSelectInputSource(source)
        if status != noErr {
            NSLog("kbswitch: TISSelectInputSource failed with status %d for %@", status, sourceID)
        }
    }
}
