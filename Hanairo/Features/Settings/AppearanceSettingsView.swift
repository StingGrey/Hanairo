import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("显示") {
                Picker("显示模式", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
            }

            Section {
                LabeledContent("渐隐位置") {
                    Text(
                        settings.profileBackgroundScreenRatio,
                        format: .percent.precision(.fractionLength(0))
                    )
                    .foregroundStyle(.secondary)
                }

                Slider(
                    value: $settings.profileBackgroundScreenRatio,
                    in: AppSettings.profileBackgroundScreenRatioRange,
                    step: 0.05
                ) {
                    Text("背景显示区域")
                } minimumValueLabel: {
                    Text("短")
                } maximumValueLabel: {
                    Text("长")
                }
            } header: {
                Text("作者主页背景")
            } footer: {
                Text("设置背景图在屏幕高度的哪个位置完全渐隐。")
            }

            Section {
                Picker("预览画质", selection: $settings.previewImageQuality) {
                    ForEach(ArtworkImageQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }

                Picker("详情画质", selection: $settings.imageQuality) {
                    ForEach(ArtworkImageQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }

                Toggle(
                    "高性能图片解码",
                    isOn: $settings.highPerformanceImageDecodingEnabled
                )
            } header: {
                Text("图片")
            } footer: {
                Text("预览画质用于首页、排行和其他作品瀑布流；详情画质用于进入作品后的图片。开启高性能解码后，预览图会在后台按显示尺寸解码，以减少滑动卡顿和内存占用；静态图片是否使用硬件加速由系统自动决定，详情大图不受影响。原图地址不可用时会自动回退，已缓存内容不会重复下载。")
            }

            Section {
                Picker("列数", selection: $settings.artworkGridColumnCount) {
                    Text("自动").tag(0)
                    ForEach(1...6, id: \.self) { count in
                        Text("\(count) 列").tag(count)
                    }
                }
            } header: {
                Text("作品瀑布流")
            } footer: {
                Text("自动模式会在紧凑窗口使用 2 列、宽屏使用 3 列；无障碍超大字号始终使用 1 列。")
            }

            Section {
                Toggle("视差滚动", isOn: $settings.artworkParallaxEnabled)
            } header: {
                Text("作品详情")
            } footer: {
                Text("开启后，信息卡片出现时图片会产生视差并渐隐到页面背景；关闭后图片按普通顺序排列。")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("外观与图片")
    }
}

#Preview("外观与图片") {
    NavigationStack {
        AppearanceSettingsView()
    }
    .withPreviewDependencies()
}
