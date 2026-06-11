import Foundation

/// One `-L` rule: forward a local port to a host:port reachable from the SSH server.
struct PortForward: Codable, Identifiable, Hashable {
    var id = UUID()
    var label: String = ""          // short friendly name, e.g. "web-1"
    var note: String = ""           // free-form memo, e.g. "프로덕션 DB 점프호스트"
    var localBind: String = "localhost"
    var localPort: Int = 0
    var remoteHost: String = ""
    var remotePort: Int = 22

    init(id: UUID = UUID(), label: String = "", note: String = "",
         localBind: String = "localhost", localPort: Int = 0,
         remoteHost: String = "", remotePort: Int = 22) {
        self.id = id; self.label = label; self.note = note
        self.localBind = localBind; self.localPort = localPort
        self.remoteHost = remoteHost; self.remotePort = remotePort
    }

    enum CodingKeys: String, CodingKey {
        case id, label, note, localBind, localPort, remoteHost, remotePort
    }

    // Tolerant decoding so adding new fields never wipes an existing config.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        localBind = try c.decodeIfPresent(String.self, forKey: .localBind) ?? "localhost"
        localPort = try c.decodeIfPresent(Int.self, forKey: .localPort) ?? 0
        remoteHost = try c.decodeIfPresent(String.self, forKey: .remoteHost) ?? ""
        remotePort = try c.decodeIfPresent(Int.self, forKey: .remotePort) ?? 22
    }

    /// Renders the value passed to `ssh -L`.
    var sshArgument: String {
        let bind = localBind.trimmingCharacters(in: .whitespaces)
        let dest = "\(remoteHost):\(remotePort)"
        if bind.isEmpty {
            return "\(localPort):\(dest)"
        }
        return "\(bind):\(localPort):\(dest)"
    }

    var summary: String {
        let name = label.isEmpty ? remoteHost : label
        return "\(localPort) → \(name):\(remotePort)"
    }
}

/// How a tunnel authenticates to the SSH server.
enum AuthMethod: String, Codable, CaseIterable, Hashable {
    case password   // 비밀번호 (Keychain에 저장, askpass로 자동 입력)
    case key        // 키 파일 (-i identityFile)
    case agent      // 기본 ~/.ssh 키 + ssh-agent
}

/// A single SSH connection with a set of port forwards. Mirrors one entry in the old app.
struct Tunnel: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String = "New Tunnel"
    var host: String = ""
    var port: Int = 22
    var user: String = ""
    var forwards: [PortForward] = []

    var authMethod: AuthMethod = .password
    var identityFile: String = ""    // path to private key when authMethod == .key

    var connectTimeout: Int = 15
    var serverAliveInterval: Int = 30
    var serverAliveCountMax: Int = 3
    var autostart: Bool = false
    var extraArgs: String = ""       // free-form extra ssh args, space-separated

    init(id: UUID = UUID(), name: String = "New Tunnel", host: String = "",
         port: Int = 22, user: String = "", forwards: [PortForward] = [],
         authMethod: AuthMethod = .password, identityFile: String = "",
         connectTimeout: Int = 15, serverAliveInterval: Int = 30,
         serverAliveCountMax: Int = 3, autostart: Bool = false, extraArgs: String = "") {
        self.id = id; self.name = name; self.host = host; self.port = port
        self.user = user; self.forwards = forwards
        self.authMethod = authMethod; self.identityFile = identityFile
        self.connectTimeout = connectTimeout; self.serverAliveInterval = serverAliveInterval
        self.serverAliveCountMax = serverAliveCountMax; self.autostart = autostart
        self.extraArgs = extraArgs
    }

    enum CodingKeys: String, CodingKey {
        case id, name, host, port, user, forwards, authMethod, identityFile
        case connectTimeout, serverAliveInterval, serverAliveCountMax, autostart, extraArgs
    }

    // Tolerant decoding so adding new fields never wipes an existing config.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "New Tunnel"
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 22
        user = try c.decodeIfPresent(String.self, forKey: .user) ?? ""
        forwards = try c.decodeIfPresent([PortForward].self, forKey: .forwards) ?? []
        authMethod = try c.decodeIfPresent(AuthMethod.self, forKey: .authMethod) ?? .password
        identityFile = try c.decodeIfPresent(String.self, forKey: .identityFile) ?? ""
        connectTimeout = try c.decodeIfPresent(Int.self, forKey: .connectTimeout) ?? 15
        serverAliveInterval = try c.decodeIfPresent(Int.self, forKey: .serverAliveInterval) ?? 30
        serverAliveCountMax = try c.decodeIfPresent(Int.self, forKey: .serverAliveCountMax) ?? 3
        autostart = try c.decodeIfPresent(Bool.self, forKey: .autostart) ?? false
        extraArgs = try c.decodeIfPresent(String.self, forKey: .extraArgs) ?? ""
    }

    /// Keychain account used to store this tunnel's password.
    var keychainAccount: String { id.uuidString }

    /// Builds the full ssh argument list (executable excluded).
    func sshArguments() -> [String] {
        var args: [String] = ["-v", "-N"]
        args += ["-o", "ConnectTimeout=\(connectTimeout)"]
        args += ["-o", "ServerAliveInterval=\(serverAliveInterval)"]
        args += ["-o", "ServerAliveCountMax=\(serverAliveCountMax)"]
        args += ["-o", "ExitOnForwardFailure=yes"]
        args += ["-o", "StrictHostKeyChecking=accept-new"]

        switch authMethod {
        case .password:
            args += ["-o", "PreferredAuthentications=keyboard-interactive,password"]
            args += ["-o", "PubkeyAuthentication=no"]
            args += ["-o", "NumberOfPasswordPrompts=1"]
        case .key:
            let path = (identityFile as NSString).expandingTildeInPath
            if !path.isEmpty { args += ["-i", path] }
            args += ["-o", "PreferredAuthentications=publickey"]
            args += ["-o", "IdentitiesOnly=yes"]
        case .agent:
            break  // default: agent + ~/.ssh keys
        }

        args += ["-p", String(port)]
        for f in forwards where f.localPort > 0 && !f.remoteHost.isEmpty {
            args += ["-L", f.sshArgument]
        }
        let extra = extraArgs.split(whereSeparator: { $0 == " " }).map(String.init)
        args += extra
        args.append("\(user)@\(host)")
        return args
    }
}

/// Default seed shown on first launch — the user's existing `example-tunnel` tunnel.
extension Tunnel {
    static func seed() -> Tunnel {
        var t = Tunnel()
        t.name = "example-tunnel"
        t.host = "203.0.113.10"
        t.port = 22
        t.user = "user"
        t.forwards = [
            PortForward(label: "host-7",   localBind: "localhost", localPort: 3535, remoteHost: "10.0.0.7",   remotePort: 22),
            PortForward(label: "host-152", localBind: "localhost", localPort: 3737, remoteHost: "10.0.3.152", remotePort: 22),
            PortForward(label: "host-110", localBind: "localhost", localPort: 3333, remoteHost: "10.0.1.110", remotePort: 22),
            PortForward(label: "host-211", localBind: "localhost", localPort: 3334, remoteHost: "10.0.3.211", remotePort: 22),
            PortForward(label: "host-156", localBind: "localhost", localPort: 3338, remoteHost: "10.0.3.156", remotePort: 22),
        ]
        return t
    }
}
