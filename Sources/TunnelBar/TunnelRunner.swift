import Foundation

enum TunnelStatus: Equatable {
    case stopped
    case connecting
    case connected
    case error(String)
}

/// Launches and supervises one `ssh -N` process per tunnel.
@MainActor
final class TunnelRunner: ObservableObject {
    @Published private(set) var status: [UUID: TunnelStatus] = [:]
    @Published private(set) var logs: [UUID: String] = [:]

    private var procs: [UUID: Process] = [:]
    private var intentionalStop: Set<UUID> = []

    let askpassPath: String

    init(askpassPath: String) {
        self.askpassPath = askpassPath
    }

    func status(for id: UUID) -> TunnelStatus { status[id] ?? .stopped }
    func isRunning(_ id: UUID) -> Bool { procs[id] != nil }

    func toggle(_ tunnel: Tunnel) {
        if isRunning(tunnel.id) { stop(tunnel.id) } else { start(tunnel) }
    }

    func start(_ tunnel: Tunnel) {
        guard procs[tunnel.id] == nil else { return }
        intentionalStop.remove(tunnel.id)
        logs[tunnel.id] = ""
        status[tunnel.id] = .connecting

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        p.arguments = tunnel.sshArguments()

        var env = ProcessInfo.processInfo.environment
        // Only wire up the Keychain askpass helper for password auth.
        // Key / agent auth must NOT force askpass or ssh will try the password path.
        if tunnel.authMethod == .password {
            env["SSH_ASKPASS"] = askpassPath
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env["DISPLAY"] = env["DISPLAY"] ?? ":0"
            env["TUNNELBAR_KEYCHAIN_SERVICE"] = Keychain.service
            env["TUNNELBAR_KEYCHAIN_ACCOUNT"] = tunnel.keychainAccount
        }
        p.environment = env

        let pipe = Pipe()
        p.standardError = pipe
        p.standardOutput = Pipe()

        let id = tunnel.id
        pipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async { self.ingest(id: id, text: text) }
        }

        p.terminationHandler = { proc in
            // Stop reading here — never touch proc.standardError after launch,
            // Process throws "task already launched" if its I/O is modified.
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { self.handleExit(id: id, code: proc.terminationStatus) }
        }

        do {
            try p.run()
            procs[id] = p
        } catch {
            status[id] = .error("실행 실패: \(error.localizedDescription)")
        }
    }

    func stop(_ id: UUID) {
        intentionalStop.insert(id)
        procs[id]?.terminate()
    }

    func stopAll() {
        for id in procs.keys { stop(id) }
    }

    // MARK: - stderr parsing

    private func ingest(id: UUID, text: String) {
        var buf = (logs[id] ?? "") + text
        if buf.count > 6000 { buf = String(buf.suffix(6000)) }
        logs[id] = buf

        // Only escalate to connected if we haven't already errored.
        if case .error = status[id] { return }

        if text.contains("Entering interactive session") || text.contains("Authenticated to") {
            status[id] = .connected
            return
        }
        for (needle, reason) in Self.errorMarkers where text.contains(needle) {
            status[id] = .error(reason)
            return
        }
    }

    private static let errorMarkers: [(String, String)] = [
        ("Permission denied", "인증 실패 (비밀번호/키 확인)"),
        ("Connection refused", "연결 거부됨"),
        ("Connection timed out", "연결 시간 초과"),
        ("Could not resolve hostname", "호스트를 찾을 수 없음"),
        ("Address already in use", "로컬 포트가 이미 사용 중"),
        ("remote port forwarding failed", "포워딩 실패"),
        ("Operation timed out", "연결 시간 초과"),
        ("Host key verification failed", "호스트 키 검증 실패"),
    ]

    private func handleExit(id: UUID, code: Int32) {
        procs[id] = nil

        if intentionalStop.contains(id) {
            intentionalStop.remove(id)
            status[id] = .stopped
            return
        }
        // Unexpected exit. Keep an existing error reason if we set one; otherwise summarize.
        if case .error = status[id] { return }
        let tail = (logs[id] ?? "")
            .split(separator: "\n")
            .last(where: { !$0.isEmpty })
            .map(String.init) ?? "ssh 종료 (코드 \(code))"
        status[id] = .error(tail)
    }
}
