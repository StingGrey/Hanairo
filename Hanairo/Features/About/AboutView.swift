import SwiftUI

struct AboutView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppUpdateChecker.self) private var updateChecker
    @Environment(\.openURL) private var openURL

    @State private var updateAlert: UpdateCheckAlert?

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(Color.accentColor.gradient)
                    Text("Hanairo")
                        .font(.title.weight(.bold))
                    Text("版本 \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }

            Section("说明") {
                Text("Hanairo 使用 SwiftUI 与系统框架构建，是面向 Pixiv 的第三方客户端。")
                Text("Pixiv、pixiv 及相关标志归 pixiv Inc. 所有。")
            }

            Section {
                Toggle("发现新版本时提醒", isOn: $settings.updateRemindersEnabled)

                Button {
                    Task { await checkForUpdates() }
                } label: {
                    HStack {
                        Label(
                            updateChecker.isChecking ? "正在检查…" : "检查更新",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        Spacer()
                        if updateChecker.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(updateChecker.isChecking)
            } header: {
                Text("更新")
            } footer: {
                Text("开启提醒后，Hanairo 每天最多检查一次 GitHub Release，同一版本只提醒一次。手动检查不受开关限制。")
            }

            Section("开源许可") {
                Text("Hanairo 依据 Mozilla Public License 2.0（MPL-2.0）发布。")
                Link(destination: URL(string: "https://www.mozilla.org/MPL/2.0/")!) {
                    Label("查看 MPL 2.0", systemImage: "doc.text")
                }
            }

            Section("致谢") {
                Text("功能结构参考了 PixEz Flutter 项目。")
                Link(destination: URL(string: "https://github.com/Notsfsssf/pixez-flutter")!) {
                    Label("PixEz Flutter", systemImage: "arrow.up.right.square")
                }
            }
        }
        .navigationTitle("关于")
        .alert(
            updateAlert?.title ?? "检查更新",
            isPresented: updateAlertBinding,
            presenting: updateAlert
        ) { alert in
            if let releaseURL = alert.releaseURL {
                Button("查看发布页") {
                    openURL(releaseURL)
                }
                Button("稍后", role: .cancel) {}
            } else {
                Button("好", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    private var version: String {
        AppUpdateChecker.currentVersion
    }

    private var updateAlertBinding: Binding<Bool> {
        Binding(
            get: { updateAlert != nil },
            set: { if !$0 { updateAlert = nil } }
        )
    }

    private func checkForUpdates() async {
        do {
            switch try await updateChecker.checkForUpdate() {
            case let .available(release):
                updateAlert = UpdateCheckAlert(
                    title: "发现新版本 \(release.version)",
                    message: release.title,
                    releaseURL: release.releaseURL
                )
            case let .upToDate(currentVersion, latestVersion):
                updateAlert = UpdateCheckAlert(
                    title: "已经是最新版本",
                    message: "当前版本 \(currentVersion)，最新发布版本 \(latestVersion)。"
                )
            }
        } catch is CancellationError {
            return
        } catch {
            updateAlert = UpdateCheckAlert(
                title: "检查更新失败",
                message: error.localizedDescription
            )
        }
    }
}

private struct UpdateCheckAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var releaseURL: URL? = nil
}

#Preview("关于") {
    NavigationStack {
        AboutView()
    }
    .withPreviewDependencies()
}
