import SwiftUI

// MARK: - Menu bar dropdown

struct MenuContent: View {
    @EnvironmentObject var store: Store
    @ObservedObject var runner: TunnelRunner
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tunnels").font(.headline).padding(.horizontal, 12).padding(.top, 10)

            if store.tunnels.isEmpty {
                Text("터널이 없습니다. ‘편집’에서 추가하세요.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.horizontal, 12)
            }

            ForEach(store.tunnels) { tunnel in
                TunnelRow(tunnel: tunnel, runner: runner)
            }

            Divider().padding(.vertical, 4)

            Button {
                openWindow(id: "editor")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("터널 편집…", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            Button(role: .destructive) {
                runner.stopAll()
                NSApp.terminate(nil)
            } label: {
                Label("종료", systemImage: "power")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(width: 280)
    }
}

private struct TunnelRow: View {
    let tunnel: Tunnel
    @ObservedObject var runner: TunnelRunner

    var body: some View {
        let status = runner.status(for: tunnel.id)
        HStack(spacing: 8) {
            Circle().fill(color(status)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(tunnel.name).fontWeight(.medium)
                Text(subtitle(status)).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(runner.isRunning(tunnel.id) ? "해제" : "연결") {
                runner.toggle(tunnel)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .help(subtitle(status))
    }

    private func color(_ s: TunnelStatus) -> Color {
        switch s {
        case .connected: return .green
        case .connecting: return .yellow
        case .error: return .red
        case .stopped: return .secondary
        }
    }

    private func subtitle(_ s: TunnelStatus) -> String {
        switch s {
        case .connected: return "연결됨 · \(tunnel.forwards.count)개 포워딩"
        case .connecting: return "연결 중…"
        case .stopped: return "\(tunnel.user)@\(tunnel.host)"
        case .error(let m): return "에러: \(m)"
        }
    }
}

// MARK: - Editor window

struct EditorView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var runner: TunnelRunner
    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.tunnels) { t in
                        HStack {
                            Circle().fill(dot(t)).frame(width: 8, height: 8)
                            Text(t.name)
                        }
                        .tag(t.id)
                        .contextMenu {
                            Button("복제") { duplicate(t.id) }
                            Button("삭제", role: .destructive) { deleteTunnel(t.id) }
                        }
                    }
                }
                .onDeleteCommand { if let id = selection { deleteTunnel(id) } }

                Divider()
                // System-Settings-style add/remove bar at the bottom of the list.
                HStack(spacing: 2) {
                    Button { selection = store.addTunnel() } label: {
                        Image(systemName: "plus")
                    }
                    .help("터널 추가")
                    Button { if let id = selection { deleteTunnel(id) } } label: {
                        Image(systemName: "minus")
                    }
                    .help("선택한 터널 삭제")
                    .disabled(selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .frame(minWidth: 190)
        } detail: {
            if let id = selection, let binding = store.binding(for: id) {
                TunnelDetail(tunnel: binding, runner: runner)
                    .environmentObject(store)
                    .id(id)
            } else {
                Text("왼쪽에서 터널을 선택하거나 ‘+’로 추가하세요.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 740, minHeight: 480)
        .onAppear {
            if selection == nil { selection = store.tunnels.first?.id }
            // Menu-bar (accessory) apps don't give their windows keyboard focus.
            // Become a regular app while the editor is open so text fields are editable.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                NSApp.windows.first { $0.title == "Tunnels" }?.makeKeyAndOrderFront(nil)
            }
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func dot(_ t: Tunnel) -> Color {
        switch runner.status(for: t.id) {
        case .connected: return .green
        case .connecting: return .yellow
        case .error: return .red
        case .stopped: return .secondary
        }
    }

    /// Clear selection BEFORE removing so the detail pane drops its binding first,
    /// then delete and pick a neighbour. Avoids evaluating a stale binding.
    private func deleteTunnel(_ id: UUID) {
        let next = store.tunnels.first { $0.id != id }?.id
        selection = nil
        store.delete(id)
        DispatchQueue.main.async { selection = next }
    }

    private func duplicate(_ id: UUID) {
        guard let src = store.tunnels.first(where: { $0.id == id }) else { return }
        var copy = src
        copy.id = UUID()
        copy.name = src.name + " (복사본)"
        copy.autostart = false
        copy.forwards = src.forwards.map { var f = $0; f.id = UUID(); return f }
        store.tunnels.append(copy)
        store.save()
        selection = copy.id
    }
}

private struct TunnelDetail: View {
    @Binding var tunnel: Tunnel
    @ObservedObject var runner: TunnelRunner
    @EnvironmentObject var store: Store
    @State private var password: String = ""
    @State private var passwordDirty = false

    var body: some View {
        Form {
            Section("연결") {
                LabeledContent("이름") {
                    TextField("", text: $tunnel.name, prompt: Text("터널 이름"))
                        .textFieldStyle(.roundedBorder).labelsHidden()
                }
                LabeledContent("호스트") {
                    TextField("", text: $tunnel.host, prompt: Text("예: 203.0.113.10"))
                        .textFieldStyle(.roundedBorder).labelsHidden()
                }
                LabeledContent("사용자") {
                    TextField("", text: $tunnel.user, prompt: Text("예: user"))
                        .textFieldStyle(.roundedBorder).labelsHidden()
                }
                LabeledContent("포트") {
                    TextField("", value: $tunnel.port,
                              format: .number.grouping(.never), prompt: Text("22"))
                        .textFieldStyle(.roundedBorder).labelsHidden().frame(width: 90)
                }
            }

            Section("인증") {
                Picker("방식", selection: $tunnel.authMethod) {
                    Text("비밀번호").tag(AuthMethod.password)
                    Text("키 파일").tag(AuthMethod.key)
                    Text("기본 키/에이전트").tag(AuthMethod.agent)
                }
                .pickerStyle(.segmented)

                switch tunnel.authMethod {
                case .password:
                    LabeledContent("비밀번호") {
                        HStack(spacing: 6) {
                            SecureField("", text: $password, prompt: Text("비밀번호 입력"))
                                .textFieldStyle(.roundedBorder).labelsHidden()
                                .onChange(of: password) { passwordDirty = true }
                            if !passwordDirty && Keychain.hasPassword(account: tunnel.keychainAccount) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    .help("저장된 비밀번호 있음")
                            }
                        }
                    }
                case .key:
                    LabeledContent("키 파일") {
                        HStack(spacing: 6) {
                            TextField("", text: $tunnel.identityFile,
                                      prompt: Text("~/.ssh/id_ed25519"))
                                .textFieldStyle(.roundedBorder).labelsHidden()
                            Button("찾기…") { chooseIdentityFile() }
                        }
                    }
                case .agent:
                    Text("~/.ssh 의 기본 키와 ssh-agent 를 사용합니다. 별도 설정이 필요 없습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                // 표 전체를 Form 행 하나에 — 행마다 쪼개지면 구분선/인셋 때문에 정렬이 깨진다.
                ForwardTable(forwards: $tunnel.forwards)
            } header: {
                Text("포트 포워딩 (-L)")
            } footer: {
                Text("로컬 포트로 접속하면 SSH 서버 너머의 ‘원격 호스트:포트’로 연결됩니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("옵션") {
                Toggle("앱 시작 시 자동 연결", isOn: $tunnel.autostart)
                LabeledContent("Connect Timeout") {
                    TextField("", value: $tunnel.connectTimeout,
                              format: .number.grouping(.never), prompt: Text("15"))
                        .textFieldStyle(.roundedBorder).labelsHidden().frame(width: 90)
                }
                LabeledContent("Alive Interval") {
                    TextField("", value: $tunnel.serverAliveInterval,
                              format: .number.grouping(.never), prompt: Text("30"))
                        .textFieldStyle(.roundedBorder).labelsHidden().frame(width: 90)
                }
                LabeledContent("Alive Count Max") {
                    TextField("", value: $tunnel.serverAliveCountMax,
                              format: .number.grouping(.never), prompt: Text("3"))
                        .textFieldStyle(.roundedBorder).labelsHidden().frame(width: 90)
                }
                LabeledContent("추가 ssh 인자") {
                    TextField("", text: $tunnel.extraArgs, prompt: Text("선택 사항"))
                        .textFieldStyle(.roundedBorder).labelsHidden()
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                statusLabel
                Spacer()
                Button(runner.isRunning(tunnel.id) ? "해제" : "연결") {
                    saveAll()
                    runner.toggle(tunnel)
                }
                Button("저장") { saveAll() }.keyboardShortcut("s")
            }
            .padding(12)
            .background(.bar)
        }
        .onDisappear { saveAll() }
    }

    @ViewBuilder private var statusLabel: some View {
        switch runner.status(for: tunnel.id) {
        case .connected: Label("연결됨", systemImage: "circle.fill").foregroundStyle(.green)
        case .connecting: Label("연결 중…", systemImage: "circle.fill").foregroundStyle(.yellow)
        case .error(let m): Label(m, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        case .stopped: Label("끊김", systemImage: "circle").foregroundStyle(.secondary)
        }
    }

    private func saveAll() {
        if passwordDirty && !password.isEmpty {
            Keychain.setPassword(password, account: tunnel.keychainAccount)
            passwordDirty = false
        }
        store.save()
    }

    private func chooseIdentityFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true     // ~/.ssh and key files are hidden
        panel.directoryURL = URL(fileURLWithPath: ("~/.ssh" as NSString).expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            tunnel.identityFile = url.path
            store.save()
        }
    }
}

/// All port-forwards in one real table layout (Grid), so every column lines up
/// across rows — header included. Lives in a single Form row on purpose.
private struct ForwardTable: View {
    @Binding var forwards: [PortForward]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !forwards.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 12) {
                    GridRow {
                        header("이름")
                        header("로컬")
                        Color.clear.frame(width: 12, height: 1)
                        header("원격 호스트")
                        header("포트")
                        header("메모")
                        Color.clear.frame(width: 20, height: 1)
                    }
                    ForEach($forwards) { $f in
                        GridRow {
                            // 제목을 비우고 prompt만 사용 — grouped Form에선 제목이
                            // placeholder가 아니라 별도 라벨로 그려져 줄이 어긋난다.
                            TextField("", text: $f.label, prompt: Text("web-1"))
                                .textFieldStyle(.roundedBorder).labelsHidden()
                                .frame(width: 84)
                            TextField("", value: $f.localPort,
                                      format: .number.grouping(.never), prompt: Text("3535"))
                                .textFieldStyle(.roundedBorder).labelsHidden()
                                .frame(width: 60)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.tertiary).font(.caption)
                            TextField("", text: $f.remoteHost, prompt: Text("10.0.0.7"))
                                .textFieldStyle(.roundedBorder).labelsHidden()
                                .frame(minWidth: 110, maxWidth: .infinity)
                            TextField("", value: $f.remotePort,
                                      format: .number.grouping(.never), prompt: Text("22"))
                                .textFieldStyle(.roundedBorder).labelsHidden()
                                .frame(width: 54)
                            TextField("", text: $f.note, prompt: Text("선택"))
                                .textFieldStyle(.roundedBorder).labelsHidden()
                                .frame(minWidth: 90, maxWidth: .infinity)
                            Button(role: .destructive) {
                                forwards.removeAll { $0.id == f.id }
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("이 포워딩 삭제")
                        }
                    }
                }
            }
            Button {
                forwards.append(PortForward(label: "", localBind: "localhost",
                                            localPort: 0, remoteHost: "", remotePort: 22))
            } label: {
                Label("포워딩 추가", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    private func header(_ t: String) -> some View {
        Text(t).font(.caption2).foregroundStyle(.secondary)
    }
}
