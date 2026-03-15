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

enum UpdateChecker {
    private static let repo = "renaudallard/kbswitch"
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!

    private struct Release {
        let version: String
        let dmgURL: String
    }

    static var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private static var progressObservation: NSKeyValueObservation?
    private static var progressWindow: NSPanel?

    static func checkInBackground() {
        guard currentVersion != nil else { return }
        fetchLatestRelease { result in
            if case .available(let release) = result {
                DispatchQueue.main.async {
                    showUpdateAlert(release: release)
                }
            }
        }
    }

    static func checkNow() {
        guard currentVersion != nil else {
            showErrorAlert("Could not determine current version.")
            return
        }
        fetchLatestRelease { result in
            DispatchQueue.main.async {
                switch result {
                case .available(let release):
                    showUpdateAlert(release: release)
                case .upToDate:
                    showUpToDateAlert()
                case .error(let message):
                    showErrorAlert(message)
                }
            }
        }
    }

    private enum FetchResult {
        case available(Release)
        case upToDate
        case error(String)
    }

    private static func fetchLatestRelease(completion: @escaping (FetchResult) -> Void) {
        guard let current = currentVersion else {
            completion(.error("Could not determine current version."))
            return
        }

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                NSLog("kbswitch: update check failed: %@", error.localizedDescription)
                completion(.error("Could not check for updates: \(error.localizedDescription)"))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                completion(.error("Could not parse update information."))
                return
            }

            let remote = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            guard isNewer(remote, than: current) else {
                completion(.upToDate)
                return
            }

            guard let assets = json["assets"] as? [[String: Any]] else {
                completion(.error("No download available for this release."))
                return
            }

            for asset in assets {
                if let name = asset["name"] as? String,
                   name.hasSuffix(".dmg"),
                   let url = asset["browser_download_url"] as? String {
                    completion(.available(Release(version: remote, dmgURL: url)))
                    return
                }
            }

            completion(.error("No DMG found in the latest release."))
        }.resume()
    }

    private static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }

    // MARK: - Progress window

    private static func showProgressWindow() -> (panel: NSPanel, bar: NSProgressIndicator, label: NSTextField) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "Updating kbswitch"
        panel.isFloatingPanel = true
        panel.center()

        let label = NSTextField(labelWithString: "Downloading update...")
        label.frame = NSRect(x: 20, y: 44, width: 300, height: 17)
        label.font = .systemFont(ofSize: 13)

        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 16, width: 300, height: 20))
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 100
        bar.doubleValue = 0
        bar.isIndeterminate = false

        panel.contentView?.addSubview(label)
        panel.contentView?.addSubview(bar)

        progressWindow = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        return (panel, bar, label)
    }

    private static func closeProgressWindow() {
        progressWindow?.close()
        progressWindow = nil
        progressObservation = nil
    }

    // MARK: - Install

    private static func downloadAndInstall(release: Release) {
        guard let url = URL(string: release.dmgURL) else { return }

        let (panel, bar, label) = showProgressWindow()

        let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            DispatchQueue.main.async {
                progressObservation = nil

                guard let tempURL = tempURL else {
                    closeProgressWindow()
                    showErrorAlert("Download failed: \(error?.localizedDescription ?? "unknown error")")
                    return
                }

                let dmgPath = NSTemporaryDirectory() + "kbswitch-update.dmg"
                try? FileManager.default.removeItem(atPath: dmgPath)

                guard let _ = try? FileManager.default.moveItem(
                    at: tempURL, to: URL(fileURLWithPath: dmgPath)
                ) else {
                    closeProgressWindow()
                    showErrorAlert("Failed to save update.")
                    return
                }

                label.stringValue = "Installing update..."
                bar.isIndeterminate = true
                bar.startAnimation(nil)

                let appPath = Bundle.main.bundlePath

                DispatchQueue.global().async {
                    let error = performInstall(dmgPath: dmgPath, appPath: appPath)
                    DispatchQueue.main.async {
                        if let error = error {
                            closeProgressWindow()
                            showErrorAlert(error)
                        } else {
                            bar.stopAnimation(nil)
                            bar.isIndeterminate = false
                            bar.doubleValue = 100
                            label.stringValue = "Update complete. Restarting..."
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                closeProgressWindow()
                                relaunch(appPath: appPath)
                            }
                        }
                    }
                }
            }
        }

        progressObservation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                bar.doubleValue = progress.fractionCompleted * 100
            }
        }

        task.resume()
    }

    private static func performInstall(dmgPath: String, appPath: String) -> String? {
        let fm = FileManager.default
        let mountPoint = NSTemporaryDirectory() + "kbswitch-mount"

        try? fm.removeItem(atPath: mountPoint)
        try? fm.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

        guard run("/usr/bin/hdiutil", "attach", dmgPath, "-nobrowse", "-quiet", "-mountpoint", mountPoint) else {
            return "Failed to mount update image."
        }

        let newAppPath = mountPoint + "/kbswitch.app"

        guard fm.fileExists(atPath: newAppPath) else {
            detach(mountPoint)
            return "Update image does not contain kbswitch.app."
        }

        let stagedPath = NSTemporaryDirectory() + "kbswitch-staged.app"
        try? fm.removeItem(atPath: stagedPath)

        do {
            try fm.copyItem(atPath: newAppPath, toPath: stagedPath)
        } catch {
            detach(mountPoint)
            return "Failed to stage update."
        }

        detach(mountPoint)
        try? fm.removeItem(atPath: dmgPath)

        do {
            let backupPath = appPath + ".bak"
            try? fm.removeItem(atPath: backupPath)
            try fm.moveItem(atPath: appPath, toPath: backupPath)
            try fm.moveItem(atPath: stagedPath, toPath: appPath)
            try? fm.removeItem(atPath: backupPath)
            _ = run("/usr/bin/xattr", "-dr", "com.apple.quarantine", appPath)
        } catch {
            return "Failed to install update: \(error.localizedDescription)"
        }

        return nil
    }

    static func showPostUpdateAlertIfNeeded() {
        let key = "updateJustCompleted"
        guard UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.removeObject(forKey: key)
        let alert = NSAlert()
        alert.messageText = "Update Complete"
        alert.informativeText = "kbswitch has been updated to version \(currentVersion ?? "?")."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private static func relaunch(appPath: String) {
        UserDefaults.standard.set(true, forKey: "updateJustCompleted")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1 && open \"$1\"", "--", appPath]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    private static func detach(_ mountPoint: String) {
        _ = run("/usr/bin/hdiutil", "detach", mountPoint, "-quiet")
    }

    private static func run(_ path: String, _ arguments: String...) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Alerts

    private static func showUpdateAlert(release: Release) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "kbswitch \(release.version) is available (you have \(currentVersion ?? "?"))."
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational
        if alert.runModal() == .alertFirstButtonReturn {
            downloadAndInstall(release: release)
        }
    }

    private static func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "Up to Date"
        alert.informativeText = "You are running the latest version (\(currentVersion ?? "?"))."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private static func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
    }
}
