import Foundation
import Combine
import SwiftUI
import AppKit

final class BalanceViewModel: ObservableObject {
    // MARK: - Published State

    @Published var balance: UserBalanceResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefresh: Date?
    @Published var apiKey: String {
        didSet {
            KeychainStore.save(apiKey, for: .apiKey)
        }
    }
    @Published var platformToken: String {
        didSet {
            KeychainStore.save(platformToken, for: .platformToken)
        }
    }
    @Published var showSettings = false

    // Monthly cost from platform API
    @Published var monthlyCost: MonthlyCostSummary?
    @Published var monthlyCostError: String?

    // Kuaipao API state (stored in Keychain)
    @Published var kuaipaoAccessToken: String {
        didSet {
            KeychainStore.save(kuaipaoAccessToken, for: .kuaipaoAccessToken)
        }
    }
    @Published var kuaipaoUserId: String {
        didSet {
            KeychainStore.save(kuaipaoUserId, for: .kuaipaoUserId)
        }
    }
    @Published var kuaipaoUserData: KuaipaoUserData?
    @Published var kuaipaoError: String?
    @Published var kuaipaoIsLoading = false
    @Published var kuaipaoQuotaPerUnit: Int = 500_000

    // MARK: - Constants

    static let cachedBalanceKey = "cached_balance_data"
    static let cachedMonthlyCostKey = "cached_monthly_cost"
    static let cachedKuaipaoUsageKey = "cached_kuaipao_usage"
    static let defaultRefreshInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Private

    private let client = DeepSeekClient.shared
    private let kuaipaoClient = KuaipaoClient.shared
    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // One-time migration from UserDefaults to Keychain
        if let legacyApiKey = UserDefaults.standard.string(forKey: "deepseek_api_key"), !legacyApiKey.isEmpty {
            KeychainStore.save(legacyApiKey, for: .apiKey)
            UserDefaults.standard.removeObject(forKey: "deepseek_api_key")
        }
        if let legacyToken = UserDefaults.standard.string(forKey: "deepseek_platform_token"), !legacyToken.isEmpty {
            KeychainStore.save(legacyToken, for: .platformToken)
            UserDefaults.standard.removeObject(forKey: "deepseek_platform_token")
        }

        self.apiKey = KeychainStore.read(.apiKey) ?? ""
        self.platformToken = KeychainStore.read(.platformToken) ?? ""

        // Kuaipao: migrate from UserDefaults to Keychain, then read from Keychain
        if let legacyKpToken = UserDefaults.standard.string(forKey: "kuaipao_access_token"), !legacyKpToken.isEmpty {
            KeychainStore.save(legacyKpToken, for: .kuaipaoAccessToken)
            UserDefaults.standard.removeObject(forKey: "kuaipao_access_token")
        }
        if let legacyKpUid = UserDefaults.standard.string(forKey: "kuaipao_user_id"), !legacyKpUid.isEmpty {
            KeychainStore.save(legacyKpUid, for: .kuaipaoUserId)
            UserDefaults.standard.removeObject(forKey: "kuaipao_user_id")
        }
        self.kuaipaoAccessToken = KeychainStore.read(.kuaipaoAccessToken) ?? ""
        self.kuaipaoUserId = KeychainStore.read(.kuaipaoUserId) ?? ""
        let savedQpu = UserDefaults.standard.integer(forKey: "kuaipao_quota_per_unit")
        kuaipaoQuotaPerUnit = savedQpu > 0 ? savedQpu : 500_000
        loadCachedBalance()
        loadCachedMonthlyCost()
        loadCachedKuaipaoUsage()
        startAutoRefresh()
    }

    deinit {
        refreshTask?.cancel()
        cancellables.removeAll()
    }

    // MARK: - Computed Properties

    var primaryBalance: BalanceInfo? {
        balance?.balanceInfos.first
    }

    var statusColor: Color {
        guard errorMessage == nil else { return .red }
        guard let balance = balance else { return .gray }
        if !balance.isAvailable {
            return .red
        }
        if let first = balance.balanceInfos.first,
           let total = Double(first.totalBalance),
           total < 10.0 {
            return .yellow
        }
        return .green
    }

    var statusText: String {
        if errorMessage != nil { return "错误" }
        guard let balance = balance else { return "加载中…" }
        return balance.isAvailable ? "可用" : "不可用"
    }

    var formattedLastRefresh: String {
        guard let date = lastRefresh else { return "从未刷新" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    /// Monthly consumption total (from platform API if available).
    var monthlyConsumptionTotal: Double? {
        monthlyCost?.totalCost
    }

    var monthlyConsumptionFormatted: String? {
        guard let cost = monthlyCost else { return nil }
        return CurrencyFormatter.format(
            String(format: "%.4f", cost.totalCost),
            currency: cost.currency
        )
    }

    var monthlyConsumptionCurrency: String {
        monthlyCost?.currency ?? "CNY"
    }

    /// Per-model breakdown text for tooltip/hover.
    var modelBreakdownText: String? {
        guard let breakdown = monthlyCost?.modelBreakdown, !breakdown.isEmpty else {
            return nil
        }
        return breakdown.map { m in
            "\(m.model): \(CurrencyFormatter.format(String(format: "%.4f", m.amount), currency: monthlyConsumptionCurrency))"
        }.joined(separator: "\n")
    }

    // MARK: - Kuaipao Computed Properties

    /// Account remaining quota.
    /// Account remaining balance in currency.
    var kuaipaoFormattedRemaining: String {
        guard let user = kuaipaoUserData else { return "$--" }
        let money = Double(user.quota) / Double(kuaipaoQuotaPerUnit)
        return formatMoney(money)
    }

    /// Account used amount in currency.
    var kuaipaoFormattedUsed: String {
        guard let user = kuaipaoUserData else { return "$--" }
        let money = Double(user.usedQuota) / Double(kuaipaoQuotaPerUnit)
        return formatMoney(money)
    }

    /// Account total (remaining + used) in currency.
    var kuaipaoFormattedTotal: String {
        guard let user = kuaipaoUserData else { return "$--" }
        let money = Double(user.totalQuota) / Double(kuaipaoQuotaPerUnit)
        return formatMoney(money)
    }

    /// Usage progress (0.0-1.0) for progress bar.
    var kuaipaoUsageProgress: Double? {
        guard let user = kuaipaoUserData, user.totalQuota > 0 else { return nil }
        return min(Double(user.usedQuota) / Double(user.totalQuota), 1.0)
    }

    var kuaipaoStatusColor: Color {
        guard kuaipaoError == nil else { return .red }
        guard kuaipaoUserData != nil else { return .gray }
        return .green
    }

    /// Display name or username from kuaipao.
    var kuaipaoDisplayName: String {
        kuaipaoUserData?.displayName ?? kuaipaoUserData?.username ?? "快跑"
    }

    // MARK: - Actions

    func refresh() {
        guard !isLoading else { return }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            self.isLoading = true
            self.errorMessage = nil

            defer { self.isLoading = false }

            // DeepSeek balance
            if !self.apiKey.isEmpty {
                do {
                    let result = try await client.fetchBalance(apiKey: apiKey)
                    try Task.checkCancellation()
                    self.balance = result
                    self.lastRefresh = Date()
                    self.errorMessage = nil
                    self.cacheBalance(result)

                    if !self.platformToken.isEmpty {
                        await self.refreshMonthlyCost()
                    }
                } catch is CancellationError {
                    return
                } catch {
                    try? Task.checkCancellation()
                    self.errorMessage = error.localizedDescription
                }
            }

            // Kuaipao balance (independent of DeepSeek)
            if !self.kuaipaoAccessToken.isEmpty, !self.kuaipaoUserId.isEmpty {
                await self.refreshKuaipao()
            }
        }
    }

    func refreshMonthlyCost() async {
        guard !platformToken.isEmpty else {
            monthlyCostError = nil
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        do {
            let summary = try await client.fetchMonthlyCost(
                userToken: platformToken,
                year: year,
                month: month
            )
            try Task.checkCancellation()
            self.monthlyCost = summary
            self.monthlyCostError = nil
            self.cacheMonthlyCost(summary)
        } catch is CancellationError {
            // ignore
        } catch {
            try? Task.checkCancellation()
            self.monthlyCostError = error.localizedDescription
        }
    }

    func refreshKuaipao() async {
        guard !kuaipaoAccessToken.isEmpty, !kuaipaoUserId.isEmpty else {
            kuaipaoError = nil
            return
        }

        kuaipaoIsLoading = true
        defer { kuaipaoIsLoading = false }

        // Refresh quota-per-unit conversion rate
        let qpu = await kuaipaoClient.fetchQuotaPerUnit()
        if qpu > 0 {
            kuaipaoQuotaPerUnit = qpu
            UserDefaults.standard.set(qpu, forKey: "kuaipao_quota_per_unit")
        }

        do {
            let user = try await kuaipaoClient.fetchAccountBalance(
                accessToken: kuaipaoAccessToken,
                userId: kuaipaoUserId
            )
            try Task.checkCancellation()
            self.kuaipaoUserData = user
            self.kuaipaoError = nil
            self.cacheKuaipaoUsage(user)
        } catch is CancellationError {
            // ignore
        } catch {
            try? Task.checkCancellation()
            self.kuaipaoError = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func startAutoRefresh() {
        // Periodic timer (5 minutes)
        Timer.publish(every: Self.defaultRefreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        // Refresh immediately on system wake
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        // Initial refresh after 2 seconds to let UI settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.refresh()
        }
    }

    private func cacheBalance(_ response: UserBalanceResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        UserDefaults.standard.set(data, forKey: Self.cachedBalanceKey)
    }

    private func loadCachedBalance() {
        guard let data = UserDefaults.standard.data(forKey: Self.cachedBalanceKey),
              let cached = try? JSONDecoder().decode(UserBalanceResponse.self, from: data) else {
            return
        }
        self.balance = cached
    }

    private func cacheMonthlyCost(_ summary: MonthlyCostSummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: Self.cachedMonthlyCostKey)
    }

    private func loadCachedMonthlyCost() {
        guard let data = UserDefaults.standard.data(forKey: Self.cachedMonthlyCostKey),
              let cached = try? JSONDecoder().decode(MonthlyCostSummary.self, from: data) else {
            return
        }
        self.monthlyCost = cached
    }

    private func cacheKuaipaoUsage(_ user: KuaipaoUserData) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: Self.cachedKuaipaoUsageKey)
    }

    private func loadCachedKuaipaoUsage() {
        guard let data = UserDefaults.standard.data(forKey: Self.cachedKuaipaoUsageKey),
              let cached = try? JSONDecoder().decode(KuaipaoUserData.self, from: data) else {
            return
        }
        self.kuaipaoUserData = cached
    }

    /// Format quota as money: $X.XX or $X.XX万 for large values.
    private func formatMoney(_ value: Double) -> String {
        if value >= 10_000 {
            return String(format: "$%.2f万", value / 10_000)
        } else if value >= 1 {
            return String(format: "$%.2f", value)
        } else {
            return String(format: "$%.4f", value)
        }
    }
}
