import Foundation

/// Thin wrapper around the `security` CLI so passwords live in the login Keychain,
/// never in our JSON. The askpass helper reads the same items at connect time.
enum Keychain {
    static let service = "TunnelBar"

    @discardableResult
    private static func run(_ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return (-1, "") }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let s = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
        return (p.terminationStatus, s)
    }

    static func setPassword(_ password: String, account: String) {
        // -U updates the item if it already exists.
        // -T /usr/bin/security trusts the security CLI (used by the askpass helper)
        // so reads don't trigger a Keychain prompt on every connect.
        _ = run(["add-generic-password", "-U", "-s", service, "-a", account,
                 "-T", "/usr/bin/security", "-w", password])
    }

    static func getPassword(account: String) -> String? {
        let r = run(["find-generic-password", "-s", service, "-a", account, "-w"])
        return r.status == 0 ? r.output : nil
    }

    static func hasPassword(account: String) -> Bool {
        getPassword(account: account)?.isEmpty == false
    }

    static func deletePassword(account: String) {
        _ = run(["delete-generic-password", "-s", service, "-a", account])
    }
}
