import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var viewModel: BalanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            Divider()
                .padding(.vertical, 8)

            // Balance display or state
            if let error = viewModel.errorMessage, viewModel.balance == nil {
                errorStateView(error)
            } else if let balance = viewModel.balance {
                balanceContentView(balance)
            } else if viewModel.isLoading {
                loadingView
            } else {
                emptyStateView
            }

            // Kuaipao balance section
            if showKuaipaoSection {
                kuaipaoSection
            }

            // Footer status bar
            Divider()
                .padding(.vertical, 8)

            footerView

            // Settings (expandable)
            if viewModel.showSettings {
                SettingsView(viewModel: viewModel)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("DeepSeek API")
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            Button(action: { viewModel.showSettings.toggle() }) {
                Image(systemName: viewModel.showSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Balance Content

    private func balanceContentView(_ balance: UserBalanceResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let primary = balance.balanceInfos.first {
                totalBalanceCard(primary)

                HStack(spacing: 8) {
                    subBalanceCard(
                        title: "充值余额",
                        amount: primary.toppedUpBalance,
                        currency: primary.currency,
                        systemImage: "creditcard.fill",
                        color: .blue
                    )
                    monthlyConsumptionCard(primary)
                }
            }
        }
    }

    private func totalBalanceCard(_ info: BalanceInfo) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("总余额")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                statusBadge
            }
            HStack {
                Text(formattedAmount(info.totalBalance, currency: info.currency))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func subBalanceCard(title: String, amount: String, currency: String, systemImage: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Text(formattedAmount(amount, currency: currency))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func monthlyConsumptionCard(_ info: BalanceInfo) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                Text("本月消费")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Group {
                if let formatted = viewModel.monthlyConsumptionFormatted {
                    if let breakdown = viewModel.modelBreakdownText {
                        Text(formatted)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                            .help(breakdown)
                    } else {
                        Text(formatted)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                } else if viewModel.platformToken.isEmpty {
                    Text("设置 userToken")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else if viewModel.monthlyCostError != nil {
                    Text("获取失败")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                } else {
                    Text("--")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }

    // MARK: - Kuaipao Section

    private var showKuaipaoSection: Bool {
        viewModel.kuaipaoUserData != nil || (!viewModel.kuaipaoAccessToken.isEmpty && !viewModel.kuaipaoUserId.isEmpty)
    }

    private var kuaipaoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text("快跑 API")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.bottom, 10)

            if let error = viewModel.kuaipaoError, viewModel.kuaipaoUserData == nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else if let _ = viewModel.kuaipaoUserData {
                VStack(alignment: .leading, spacing: 10) {
                    // Total remaining
                    VStack(spacing: 4) {
                        HStack {
                            Text("剩余额度")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            kuaipaoStatusBadge
                        }
                        HStack {
                            Text(viewModel.kuaipaoFormattedRemaining)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                    )

                    HStack(spacing: 8) {
                        kuaipaoSubCard(
                            title: "已使用",
                            value: viewModel.kuaipaoFormattedUsed,
                            systemImage: "arrow.up.circle.fill",
                            color: .orange
                        )
                        kuaipaoSubCard(
                            title: "总额度",
                            value: viewModel.kuaipaoFormattedTotal,
                            systemImage: "creditcard.fill",
                            color: .blue
                        )
                    }
                }
            } else if viewModel.kuaipaoIsLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("加载中…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var kuaipaoStatusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(viewModel.kuaipaoStatusColor)
                .frame(width: 6, height: 6)
            Text(kuaipaoStatusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(viewModel.kuaipaoStatusColor)
        }
    }

    private var kuaipaoStatusText: String {
        if viewModel.kuaipaoError != nil { return "错误" }
        if viewModel.kuaipaoUserData != nil { return "正常" }
        return "未配置"
    }

    private func kuaipaoSubCard(title: String, value: String, systemImage: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(viewModel.statusColor)
                .frame(width: 6, height: 6)
            Text(viewModel.statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(viewModel.statusColor)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Text("更新于 \(viewModel.formattedLastRefresh)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: { viewModel.refresh() }) {
                HStack(spacing: 3) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    Text("刷新")
                        .font(.system(size: 10))
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("加载中…")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("暂无数据")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("请设置 API Key 后刷新")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func formattedAmount(_ amountString: String, currency: String) -> String {
        CurrencyFormatter.format(amountString, currency: currency)
    }
}
