import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = AppViewModel.shared
    @State private var showPasswordModal = false
    @State private var passwordForm = PasswordForm()
    @State private var passwordError = ""
    
    struct PasswordForm {
        var old = ""
        var new = ""
        var confirm = ""
    }
    
    var body: some View {
        List {
            // Account Security
            Section("账户安全") {
                SettingsRow(
                    icon: "key.fill",
                    title: "修改密码",
                    subtitle: "更新您的登录密码",
                    action: { showPasswordModal = true }
                )
                
                SettingsRow(
                    icon: "person.fill",
                    title: "当前用户",
                    subtitle: "\(viewModel.currentUser ?? "--") (\(viewModel.userRole ?? "--"))",
                    showChevron: false
                )
                
                SettingsRow(
                    icon: "shield.fill",
                    title: "会话安全",
                    subtitle: "会话超时: 1小时 | 仅HTTPS传输",
                    showChevron: false
                )
            }
            
            // Server Config
            Section("服务器配置") {
                HStack {
                    TextField("服务器地址", text: $viewModel.serverURL)
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("保存") {
                        viewModel.saveSettings()
                        Task { await viewModel.refreshAllData() }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.subheadline)
                }
                .padding(.vertical, 4)

                SettingsRow(
                    icon: "folder.fill",
                    title: "服务器目录",
                    subtitle: viewModel.serverConfig?.mcServerDir ?? "--",
                    showChevron: false
                )
                
                SettingsRow(
                    icon: "doc.fill",
                    title: "JAR 文件",
                    subtitle: viewModel.serverConfig?.jarFile ?? "--",
                    showChevron: false
                )
                
                SettingsRow(
                    icon: "terminal.fill",
                    title: "JVM 参数",
                    subtitle: viewModel.serverConfig?.javaOpts ?? "--",
                    showChevron: false
                )
                
                SettingsRow(
                    icon: "doc.text.fill",
                    title: "日志文件",
                    subtitle: viewModel.serverConfig?.logFile ?? "--",
                    showChevron: false
                )
            }
            
            // Danger Zone
            Section("危险操作") {
                SettingsRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "重置所有数据",
                    subtitle: "清除所有历史记录、日志缓存和本地存储",
                    iconColor: .red,
                    action: {
                        if !UserDefaults.standard.bool(forKey: "confirm_danger") {
                            // Show confirmation
                        } else {
                            clearAllData()
                        }
                    }
                )
            }
            
            // About
            Section("关于") {
                InfoRow(label: "版本", value: "1.0.0")
                InfoRow(label: "构建时间", value: "2026.08.28")
                InfoRow(label: "技术栈", value: "SwiftUI + WidgetKit")
                InfoRow(label: "后端", value: "Flask + Python 3.11+")
                InfoRow(label: "许可证", value: "MIT License")
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showPasswordModal) {
            ChangePasswordView(
                passwordForm: $passwordForm,
                error: $passwordError,
                onSave: { form in
                    Task {
                        let success = await self.changePassword(
                            oldPassword: form.old,
                            newPassword: form.new
                        )
                        if success {
                            passwordForm = PasswordForm()
                            passwordError = ""
                        }
                    }
                },
                onCancel: {
                    passwordForm = PasswordForm()
                    passwordError = ""
                }
            )
        }
    }
    
    private func changePassword(oldPassword: String, newPassword: String) async -> Bool {
        let api = APIService.shared
        guard let url = URL(string: "\(api.baseURL)/api/change_password") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !api.apiKey.isEmpty {
            request.setValue("Bearer \(api.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONEncoder().encode([
            "old_password": oldPassword,
            "new_password": newPassword
        ])
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200...299).contains(http.statusCode)
            }
        } catch {
            return false
        }
        return false
    }
    
    private func clearAllData() {
        UserDefaults.standard.removeObject(forKey: "api_base_url")
        UserDefaults.standard.removeObject(forKey: "api_key")
        UserDefaults.standard.removeObject(forKey: "server_url")
        UserDefaults.standard.removeObject(forKey: "api_key")
        viewModel.serverURL = ""
        viewModel.apiKey = ""
        viewModel.crashReports = []
        viewModel.consoleLogs = []
        viewModel.files = []
        viewModel.crashStats = nil
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconColor: Color = .cyan
    var showChevron: Bool = true
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

struct ChangePasswordView: View {
    @Binding var passwordForm: SettingsView.PasswordForm
    @Binding var error: String
    let onSave: (SettingsView.PasswordForm) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("当前密码", text: $passwordForm.old)
                        .textContentType(.password)
                    SecureField("新密码", text: $passwordForm.new)
                        .textContentType(.newPassword)
                    SecureField("确认新密码", text: $passwordForm.confirm)
                        .textContentType(.newPassword)
                } header: {
                    Text("修改密码")
                } footer: {
                    Text("至少6位字符")
                }
                
                if !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("修改密码")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认修改") {
                        onSave(passwordForm)
                    }
                    .disabled(passwordForm.new.count < 6 || passwordForm.new != passwordForm.confirm)
                }
            }
        }
    }
}

struct CrashSettingsView: View {
    @Binding var settings: CrashView.CrashSettings
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("崩溃窗口最大次数: \(settings.maxCrashesPerWindow)", value: $settings.maxCrashesPerWindow, in: 1...10)
                    Text("\(settings.crashWindowSeconds) 秒内允许的最大崩溃次数，超过则停止自动重启")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("崩溃检测设置")
                }
                
                Section {
                    Stepper("崩溃统计窗口: \(settings.crashWindowSeconds) 秒", value: $settings.crashWindowSeconds, in: 60...3600, step: 60)
                    Text("统计最近 N 秒内的崩溃次数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("统计窗口")
                }
                
                Section {
                    Stepper("检测间隔: \(settings.checkInterval) 秒", value: $settings.checkInterval, in: 1...60)
                    Text("检查进程状态的间隔时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("检测间隔")
                }
            }
            .navigationTitle("崩溃检测设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave() }
                }
            }
        }
    }
}