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

final class MappingStore {
    private let key = "keyboardMappings"
    private let defaults = UserDefaults.standard
    private var cache: [String: String]?

    func layoutID(for keyboard: KeyboardIdentifier) -> String? {
        let map = cachedMappings()
        if let value = map[keyboard.persistenceKey] {
            return value
        }
        if keyboard.serialNumber.isEmpty {
            return map[keyboard.persistenceKey + ":"]
        }
        return nil
    }

    func setLayoutID(_ layoutID: String?, for keyboard: KeyboardIdentifier) {
        var map = cachedMappings()
        map[keyboard.persistenceKey] = layoutID
        defaults.set(map, forKey: key)
        cache = map
    }

    private func cachedMappings() -> [String: String] {
        if let cache = cache { return cache }
        let map = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        cache = map
        return map
    }
}
