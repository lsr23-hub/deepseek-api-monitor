import Foundation

// MARK: - Balance API Models

struct BalanceInfo: Codable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

struct UserBalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

// MARK: - Platform Usage API Models

/// Daily cost data from platform.deepseek.com internal API.
struct PlatformCostResponse: Codable {
    let code: Int
    let msg: String?
    let data: PlatformCostData?
}

struct PlatformCostData: Codable {
    let bizData: [PlatformBizData]?

    enum CodingKeys: String, CodingKey {
        case bizData = "biz_data"
    }
}

struct PlatformBizData: Codable {
    let currency: String?
    let days: [PlatformDayCost]
    let total: [PlatformModelCost]
}

struct PlatformDayCost: Codable {
    let date: String
    let data: [PlatformModelCost]
}

struct PlatformModelCost: Codable {
    let model: String?
    let usage: [PlatformUsageItem]
}

struct PlatformUsageItem: Codable {
    let amount: String
}

// MARK: - Parsed monthly cost (simplified for display)

struct MonthlyCostSummary: Codable {
    let totalCost: Double
    let currency: String
    let dailyCosts: [DailyCost]
    let modelBreakdown: [ModelCost]

    struct DailyCost: Identifiable, Codable {
        var id: String { date }
        let date: String
        let amount: Double
    }

    struct ModelCost: Identifiable, Codable {
        var id: String { model }
        let model: String
        let amount: Double
    }
}

// MARK: - API Client Errors

enum DeepSeekAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case unauthorized
    case decodingError(String)
    case networkError(String)
    case platformError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .unauthorized:
            return "API Key 无效，请检查后重试"
        case .decodingError(let detail):
            return "数据解析错误: \(detail)"
        case .networkError(let detail):
            return "网络错误: \(detail)"
        case .platformError(let msg):
            return msg
        }
    }
}

// MARK: - API Client

final class DeepSeekClient {
    static let shared = DeepSeekClient()

    private let apiBaseURL = "https://api.deepseek.com"
    private let platformBaseURL = "https://platform.deepseek.com"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Balance API

    func fetchBalance(apiKey: String) async throws -> UserBalanceResponse {
        guard let url = URL(string: "\(apiBaseURL)/user/balance") else {
            throw DeepSeekAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeepSeekAPIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200: break
        case 401, 403: throw DeepSeekAPIError.unauthorized
        default: throw DeepSeekAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(UserBalanceResponse.self, from: data)
        } catch {
            throw DeepSeekAPIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Platform Usage API

    /// Fetches detailed monthly cost data from platform.deepseek.com.
    /// - Parameters:
    ///   - userToken: The `userToken` value from browser localStorage on platform.deepseek.com
    ///   - year: e.g. 2026
    ///   - month: 1-12
    func fetchMonthlyCost(userToken: String, year: Int, month: Int) async throws -> MonthlyCostSummary {
        let monthStr = String(format: "%02d", month)
        guard let url = URL(string: "\(platformBaseURL)/api/v0/usage/cost?month=\(monthStr)&year=\(year)") else {
            throw DeepSeekAPIError.invalidURL
        }

        // Handle localStorage JSON wrapper: {"value":"xxx","__version":"0"}
        var token = userToken
        if let data = userToken.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = json["value"] as? String {
            token = value
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("https://platform.deepseek.com/usage", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeepSeekAPIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200: break
        case 401, 403: throw DeepSeekAPIError.platformError("userToken 无效或已过期，请在浏览器重新获取")
        default: throw DeepSeekAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let platformResponse: PlatformCostResponse
        do {
            platformResponse = try decoder.decode(PlatformCostResponse.self, from: data)
        } catch {
            throw DeepSeekAPIError.decodingError(error.localizedDescription)
        }

        if platformResponse.code != 0 {
            throw DeepSeekAPIError.platformError(platformResponse.msg ?? "平台 API 错误 code=\(platformResponse.code)")
        }

        guard let bizData = platformResponse.data?.bizData?.first else {
            throw DeepSeekAPIError.platformError("本月暂无消费数据")
        }

        return parseMonthlyCost(from: bizData)
    }

    private func parseMonthlyCost(from bizData: PlatformBizData) -> MonthlyCostSummary {
        let currency = bizData.currency ?? "CNY"

        // Daily costs
        let dailyCosts: [MonthlyCostSummary.DailyCost] = bizData.days.map { day in
            var total = 0.0
            for modelItem in day.data {
                for usage in modelItem.usage {
                    total += Double(usage.amount) ?? 0
                }
            }
            return MonthlyCostSummary.DailyCost(date: day.date, amount: total)
        }

        // Model breakdown (monthly total per model)
        let modelBreakdown: [MonthlyCostSummary.ModelCost] = bizData.total.compactMap { modelItem in
            var total = 0.0
            for usage in modelItem.usage {
                total += Double(usage.amount) ?? 0
            }
            let modelName = modelItem.model ?? "unknown"
            return MonthlyCostSummary.ModelCost(model: modelName, amount: total)
        }

        let totalCost = dailyCosts.reduce(0) { $0 + $1.amount }

        return MonthlyCostSummary(
            totalCost: totalCost,
            currency: currency,
            dailyCosts: dailyCosts,
            modelBreakdown: modelBreakdown
        )
    }
}
