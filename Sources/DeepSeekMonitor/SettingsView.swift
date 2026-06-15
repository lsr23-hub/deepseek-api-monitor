import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: BalanceViewModel

    private static let platformURL = URL(string: "https://platform.deepseek.com/")!

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("设置")
                .font(.headline)

            // API Key
            VStack(alignment: .leading, spacing: 4) {
                Text("API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("输入 DeepSeek API Key", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Text("在 platform.deepseek.com 获取")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }

            // Platform Token (userToken for monthly cost data)
            VStack(alignment: .leading, spacing: 4) {
                Text("userToken（可选，获取月度消费详情）")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("输入 userToken", text: $viewModel.platformToken)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Text("浏览器打开 platform.deepseek.com → F12 → Application → Local Storage → 复制 userToken 值")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Actions
            HStack(spacing: 8) {
                Button(action: { viewModel.refresh() }) {
                    Label("测试连接", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11))
                }
                .disabled(viewModel.apiKey.isEmpty || viewModel.isLoading)

                Spacer()

                Link(destination: Self.platformURL) {
                    Label("控制台", systemImage: "arrow.up.forward.square")
                        .font(.system(size: 11))
                }
            }
        }
    }
}
