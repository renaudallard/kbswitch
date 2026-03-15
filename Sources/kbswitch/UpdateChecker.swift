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

    static func checkInBackground() {
        guard currentVersion != nil else { return }
        fetchLatestRelease { release in
            guard let release = release else { return }
            DispatchQueue.main.async {
                showUpdateAlert(release: release)
            }
        }
    }

    static func checkNow() {
        guard currentVersion != nil else {
            showErrorAlert("Could not determine current version.")
            return
        }
        fetchLatestRelease { release in
            DispatchQueue.main.async {
                if let release = release {
                    showUpdateAlert(release: release)
                } else {
                    showUpToDateAlert()
                }
            }
        }
    }

    private static func fetchLatestRelease(completion: @escaping (Release?) -> Void) {
        guard let current = currentVersion else {
            completion(nil)
            return
        }

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                if let error = error {
                    NSLog("kbswitch: update check failed: %@", error.localizedDescription)
                }
                completion(nil)
                return
            }

            let remote = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            guard isNewer(remote, than: current),
                  let assets = json["assets"] as? [[String: Any]] else {
                completion(nil)
                return
            }

            for asset in assets {
                if let name = asset["name"] as? String,
                   name.hasSuffix(".dmg"),
                   let url = asset["browser_download_url"] as? String {
                    completion(Release(version: remote, dmgURL: url))
                    return
                }
            }

            completion(nil)
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

    // MARK: - Install

    private static func downloadAndInstall(release: Release) {
        guard let url = URL(string: release.dmgURL) else { return }

        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            DispatchQueue.main.async {
                guard let tempURL = tempURL else {
                    showErrorAlert("Download failed: \(error?.localizedDescription ?? "unknown error")")
                    return
                }

                let dmgPath = NSTemporaryDirectory() + "kbswitch-update.dmg"
                let fm = FileManager.default
                try? fm.removeItem(atPath: dmgPath)

                do {
                    try fm.moveItem(at: tempURL, to: URL(fileURLWithPath: dmgPath))
                } catch {
                    showErrorAlert("Failed to save update.")
                    return
                }

                installFromDMG(path: dmgPath)
            }
        }.resume()
    }

    private static func installFromDMG(path dmgPath: String) {
        let appPath = Bundle.main.bundlePath
        let fm = FileManager.default
        let mountPoint = NSTemporaryDirectory() + "kbswitch-mount"

        try? fm.removeItem(atPath: mountPoint)
        try? fm.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

        guard run("/usr/bin/hdiutil", "attach", dmgPath, "-nobrowse", "-quiet", "-mountpoint", mountPoint) else {
            showErrorAlert("Failed to mount update image.")
            return
        }

        let newAppPath = mountPoint + "/kbswitch.app"

        guard fm.fileExists(atPath: newAppPath) else {
            detach(mountPoint)
            showErrorAlert("Update image does not contain kbswitch.app.")
            return
        }

        let stagedPath = NSTemporaryDirectory() + "kbswitch-staged.app"
        try? fm.removeItem(atPath: stagedPath)

        do {
            try fm.copyItem(atPath: newAppPath, toPath: stagedPath)
        } catch {
            detach(mountPoint)
            showErrorAlert("Failed to stage update.")
            return
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
            showErrorAlert("Failed to install update: \(error.localizedDescription)")
            return
        }

        relaunch(appPath: appPath)
    }

    private static func relaunch(appPath: String) {
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
