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
    private static var sourceMap: [String: TISInputSource] = [:]

    static func availableSources() -> [InputSource] {
        let (sources, map) = buildSourceList()
        sourceMap = map
        return sources
    }

    static func currentSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    static func select(sourceID: String) {
        if currentSourceID() == sourceID { return }

        if let source = sourceMap[sourceID] {
            let status = TISSelectInputSource(source)
            if status == noErr { return }
        }

        let (_, map) = buildSourceList()
        sourceMap = map

        guard let source = map[sourceID] else { return }
        let status = TISSelectInputSource(source)
        if status != noErr {
            NSLog("kbswitch: TISSelectInputSource failed with status %d for %@", status, sourceID)
        }
    }

    private static func buildSourceList() -> ([InputSource], [String: TISInputSource]) {
        let conditions: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]

        guard let list = TISCreateInputSourceList(conditions as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource] else {
            return ([], [:])
        }

        var sources: [InputSource] = []
        var map: [String: TISInputSource] = [:]

        for source in list {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
                continue
            }
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
            sources.append(InputSource(id: id, name: name))
            map[id] = source
        }

        return (sources, map)
    }
}
