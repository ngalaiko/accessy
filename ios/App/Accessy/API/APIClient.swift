import Foundation

nonisolated enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case networkError
    case decodingFailed
    case invalidResponse
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL"
        case .unauthorized:
            return "Session expired. Please log in again"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later"
        case .serverError:
            return "Server error. Please try again"
        case .networkError:
            return "Network connection failed. Please check your internet"
        case .decodingFailed:
            return "Invalid response from server"
        case .invalidResponse:
            return "Invalid server response"
        case let .unknown(code):
            return "Request failed with code \(code)"
        }
    }
}

/// HTTP client for Accessy API
nonisolated class APIClient {
    private let baseURL = "https://api.accessy.se"

    private let defaultHeaders: [String: String] = [
        "Host": "api.accessy.se",
        "accept": "application/vnd.axessions.v1+json",
        "x-axs-plan": "accessy",
        "content-type": "application/json"
    ]

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func checkNetworkConnection() async throws {
        try await MainActor.run {
            try NetworkMonitor.shared.ensureConnected()
        }
    }

    // MARK: - Authentication Endpoints

    func requestVerification(msisdn: String) async throws -> VerifyResponse {
        let endpoint = "/auth/recover"
        let body = VerifyRequest(msisdn: msisdn)

        return try await post(endpoint: endpoint, body: body, headers: defaultHeaders)
    }

    func submitVerificationCode(code: String, id: String) async throws -> EnrollTokenResponse {
        let endpoint = "/auth/mobile-device/enroll/token"
        let body = EnrollTokenRequest(code: code, id: id.uppercased())

        return try await post(endpoint: endpoint, body: body, headers: defaultHeaders)
    }

    func validateRecoveryKey(recoveryKey: String, enrollToken: String) async throws -> ValidateRecoveryResponse {
        let endpoint = "/auth/validate-recovery-key"
        let body = ValidateRecoveryRequest(recoveryKey: recoveryKey)

        var headers = defaultHeaders
        headers["authorization"] = "Bearer \(enrollToken)"

        return try await post(endpoint: endpoint, body: body, headers: headers)
    }

    func enrollDevice(request: EnrollRequest, enrollToken: String) async throws -> EnrollResponse {
        let endpoint = "/auth/mobile-device/enroll"

        var headers = defaultHeaders
        headers["authorization"] = "Bearer \(enrollToken)"
        headers["accept"] = "application/vnd.axessions.v2+json"

        return try await post(endpoint: endpoint, body: request, headers: headers)
    }

    func login(loginProof: String) async throws -> LoginResponse {
        try await checkNetworkConnection()

        let endpoint = "/auth/mobile-device/login"

        var headers = defaultHeaders
        headers["content-type"] = "text/plain"

        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = loginProof.data(using: .utf8)

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateStatusCode(httpResponse.statusCode)

        do {
            return try JSONDecoder().decode(LoginResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Door Endpoints

    func getDoors(authToken: String) async throws -> DoorsResponse {
        let endpoint = "/asset/my-asset-publication?page_size=100"

        var headers = defaultHeaders
        headers["authorization"] = "Bearer \(authToken)"

        return try await get(endpoint: endpoint, headers: headers)
    }

    func unlockDoor(operationId: String, proof: String, authToken: String) async throws {
        try await checkNetworkConnection()

        let endpoint = "/asset/asset-operation/\(operationId)/invoke"

        var headers = defaultHeaders
        headers["authorization"] = "Bearer \(authToken)"
        headers["x-axs-proof"] = proof

        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = Data("{}".utf8)

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateStatusCode(httpResponse.statusCode)
    }

    func setFavorite(publicationId: String, isFavorite: Bool, authToken: String) async throws {
        try await checkNetworkConnection()

        let endpoint = "/asset/my-asset-publication/\(publicationId)/favorite"

        var headers = defaultHeaders
        headers["authorization"] = "Bearer \(authToken)"

        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = isFavorite ? "PUT" : "DELETE"

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateStatusCode(httpResponse.statusCode)
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(endpoint: String, headers: [String: String]) async throws -> T {
        try await checkNetworkConnection()

        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateStatusCode(httpResponse.statusCode)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func post<T: Encodable, R: Decodable>(
        endpoint: String,
        body: T,
        headers: [String: String]
    ) async throws -> R {
        try await checkNetworkConnection()

        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateStatusCode(httpResponse.statusCode)

        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func validateStatusCode(_ code: Int) throws {
        switch code {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown(code)
        }
    }
}
