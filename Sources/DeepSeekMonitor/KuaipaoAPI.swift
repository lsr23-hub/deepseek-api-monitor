import Foundation

// MARK: - Kuaipao User Self API Models

/// Response from /api/user/self — account-level balance.
struct KuaipaoUserSelfResponse: Codable {
    let data: KuaipaoUserData?
}

struct KuaipaoUserData: Codable {
    let username: String?
    let displayName: String?
    let quota: Int
    let usedQuota: Int

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case quota
        case usedQuota = "used_quota"
    }

    /// Total granted = remaining + used.
    var totalQuota: Int { quota + usedQuota }
}

// MARK: - Kuaipao Status API Models

struct KuaipaoStatusData: Codable {
    let quotaPerUnit: Int
    let displayInCurrency: Bool

    enum CodingKeys: String, CodingKey {
        case quotaPerUnit = "quota_per_unit"
        case displayInCurrency = "display_in_currency"
    }
}

struct KuaipaoStatusResponse: Codable {
    let data: KuaipaoStatusData?
}

// MARK: - API Client Errors

enum KuaipaoAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case unauthorized
    case decodingError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .unauthorized:
            return "快跑 Access Token 无效，请检查后重试"
        case .decodingError(let detail):
            return "数据解析错误: \(detail)"
        case .networkError(let detail):
            return "网络错误: \(detail)"
        }
    }
}

// MARK: - API Client

final class KuaipaoClient {
    static let shared = KuaipaoClient()

    private let baseURL = "https://kuaipao.ai"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Fetches quota-per-unit conversion from the public status endpoint.
    /// Defaults to 500,000 (new-api standard) on failure.
    func fetchQuotaPerUnit() async -> Int {
        guard let url = URL(string: "\(baseURL)/api/status") else { return 500_000 }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return 500_000
            }
            let status = try JSONDecoder().decode(KuaipaoStatusResponse.self, from: data)
            return status.data?.quotaPerUnit ?? 500_000
        } catch {
            return 500_000
        }
    }

    /// Fetches account-level balance from kuaipao.ai using an access token and user ID.
    /// The access token is generated in the web console (not the same as sk- API keys).
    /// The userId is the numeric account ID required by the New-Api-User header.
    func fetchAccountBalance(accessToken: String, userId: String) async throws -> KuaipaoUserData {
        guard let url = URL(string: "\(baseURL)/api/user/self") else {
            throw KuaipaoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(userId, forHTTPHeaderField: "New-Api-User")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw KuaipaoAPIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KuaipaoAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200: break
        case 401, 403: throw KuaipaoAPIError.unauthorized
        default: throw KuaipaoAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(KuaipaoUserSelfResponse.self, from: data)
            guard let userData = response.data else {
                throw KuaipaoAPIError.invalidResponse
            }
            return userData
        } catch {
            throw KuaipaoAPIError.decodingError(error.localizedDescription)
        }
    }
}
