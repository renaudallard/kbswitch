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

    private static func fetchLatestRelease(completion: @escaping ((version: String, url: String)?) -> Void) {
        guard let current = currentVersion else {
            completion(nil)
            return
        }

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else {
                if error != nil {
                    NSLog("kbswitch: update check failed: %@", error!.localizedDescription)
                }
                completion(nil)
                return
            }

            let remote = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            if isNewer(remote, than: current) {
                completion((version: remote, url: htmlURL))
            } else {
                completion(nil)
            }
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

    private static func showUpdateAlert(release: (version: String, url: String)) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "kbswitch \(release.version) is available (you have \(currentVersion ?? "?"))."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: release.url) {
                NSWorkspace.shared.open(url)
            }
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
        alert.messageText = "Update Check Failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
    }
}
