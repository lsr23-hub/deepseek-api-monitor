import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: BalanceViewModel

    private static let platformURL = URL(string: "https://platform.deepseek.com/")!
    private static let kuaipaoURL = URL(string: "https://kuaipao.ai/console/token")!

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

            // Kuaipao Access Token
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("🚀")
                        .font(.system(size: 10))
                    Text("快跑 Access Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                TextField("输入快跑 Access Token", text: $viewModel.kuaipaoAccessToken)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Text("控制台 → 个人设置 → 生成 Access Token")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }

            // Kuaipao User ID
            VStack(alignment: .leading, spacing: 4) {
                Text("快跑 用户 ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("输入数字用户 ID", text: $viewModel.kuaipaoUserId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Text("浏览器打开 kuaipao.ai → F12 → Application → Local Storage → 查找 user 对象中的 id 字段")
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
                    Label("DS控制台", systemImage: "arrow.up.forward.square")
                        .font(.system(size: 11))
                }

                Link(destination: Self.kuaipaoURL) {
                    Label("快跑控制台", systemImage: "arrow.up.forward.square")
                        .font(.system(size: 11))
                }
            }
        }
    }
}
