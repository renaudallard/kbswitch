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
import IOKit
import IOKit.hid

struct ConnectedKeyboard {
    let identifier: KeyboardIdentifier
    let name: String
    let isBuiltIn: Bool
}

protocol KeyboardMonitorDelegate: AnyObject {
    func keyboardConnected(_ keyboard: ConnectedKeyboard)
    func keyboardDisconnected(_ keyboard: ConnectedKeyboard)
}

final class KeyboardMonitor {
    weak var delegate: KeyboardMonitorDelegate?

    private var manager: IOHIDManager?
    private var connectedDevices: [(device: IOHIDDevice, keyboard: ConnectedKeyboard)] = []

    var keyboards: [ConnectedKeyboard] {
        connectedDevices.map(\.keyboard)
    }

    func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        let matching: [[String: Any]] = [
            [
                kIOHIDPrimaryUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDPrimaryUsageKey as String: kHIDUsage_GD_Keyboard,
            ],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let ctx = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(ctx!).takeUnretainedValue()
            monitor.deviceConnected(device)
        }, ctx)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(ctx!).takeUnretainedValue()
            monitor.deviceDisconnected(device)
        }, ctx)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            NSLog("kbswitch: IOHIDManagerOpen failed with 0x%x", result)
        }
    }

    deinit {
        stop()
    }

    func stop() {
        guard let manager = manager else { return }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        self.manager = nil
        connectedDevices.removeAll()
    }

    private static let mouseNames = [
        "mouse", "trackball",
        "mx master", "mx anywhere", "mx ergo", "mx vertical",
        "deathadder", "naga", "viper", "basilisk",
        "g502", "g903", "g604",
        "dark core", "scimitar", "nightsword",
        "aerox", "surface precision",
    ]

    private func isMouseByName(_ device: IOHIDDevice) -> Bool {
        guard let name = property(device, kIOHIDProductKey) as? String else { return false }
        let lower = name.lowercased()
        if lower.contains("keyboard") { return false }
        return KeyboardMonitor.mouseNames.contains(where: { lower.contains($0) })
    }

    private func deviceConnected(_ device: IOHIDDevice) {
        guard !isMouseByName(device),
              hasEnoughKeys(device),
              let keyboard = extractKeyboard(from: device) else { return }
        connectedDevices.append((device: device, keyboard: keyboard))
        delegate?.keyboardConnected(keyboard)
    }

    private func deviceDisconnected(_ device: IOHIDDevice) {
        guard let idx = connectedDevices.firstIndex(where: { $0.device == device }) else { return }
        let keyboard = connectedDevices[idx].keyboard
        connectedDevices.remove(at: idx)
        delegate?.keyboardDisconnected(keyboard)
    }

    private func extractKeyboard(from device: IOHIDDevice) -> ConnectedKeyboard? {
        guard let vendorID = property(device, kIOHIDVendorIDKey) as? Int,
              let productID = property(device, kIOHIDProductIDKey) as? Int else {
            return nil
        }

        let serial = property(device, kIOHIDSerialNumberKey) as? String ?? ""
        let name = property(device, kIOHIDProductKey) as? String ?? "Unknown Keyboard"
        let isBuiltIn = (property(device, kIOHIDBuiltInKey) as? NSNumber)?.boolValue ?? false

        let identifier = KeyboardIdentifier(
            vendorID: vendorID,
            productID: productID,
            serialNumber: serial
        )

        return ConnectedKeyboard(
            identifier: identifier,
            name: name,
            isBuiltIn: isBuiltIn
        )
    }

    private func hasEnoughKeys(_ device: IOHIDDevice) -> Bool {
        let matching: [String: Any] = [
            kIOHIDElementUsagePageKey as String: Int(kHIDPage_KeyboardOrKeypad),
        ]
        guard let elements = IOHIDDeviceCopyMatchingElements(
            device, matching as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)
        ) else {
            return true
        }
        let count = CFArrayGetCount(elements)
        return count == 0 || count >= 20
    }

    private func property(_ device: IOHIDDevice, _ key: String) -> Any? {
        IOHIDDeviceGetProperty(device, key as CFString)
    }
}
