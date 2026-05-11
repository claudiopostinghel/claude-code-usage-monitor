import Foundation

enum RateLimitService {
    enum FetchError: Error, LocalizedError {
        case noCredentials
        case networkError(Error)
        case invalidKey(Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .noCredentials: "Credenziali non trovate (OAuth Claude Code o API key)"
            case .networkError(let error): "Errore di rete: \(error.localizedDescription)"
            case .invalidKey(let code): "Credenziali non valide (HTTP \(code))"
            case .invalidResponse: "Risposta non valida dall'API"
            }
        }
    }

    // MARK: - OAuth (Claude Code credentials)

    static func fetchViaOAuth(accessToken: String) async throws -> RateLimitData {
        let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FetchError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw FetchError.invalidKey(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.invalidResponse
        }

        guard let fiveHour = json["five_hour"] as? [String: Any],
              let util5h = fiveHour["utilization"] as? Double,
              let reset5hStr = fiveHour["resets_at"] as? String
        else {
            throw FetchError.invalidResponse
        }

        let sevenDay = json["seven_day"] as? [String: Any]
        let util7d = sevenDay?["utilization"] as? Double
        let reset7dStr = sevenDay?["resets_at"] as? String

        return RateLimitData(
            fiveHourUtilization: util5h / 100.0,
            fiveHourReset: parseISO8601(reset5hStr) ?? Date().addingTimeInterval(60),
            sevenDayUtilization: util7d.map { $0 / 100.0 },
            sevenDayReset: reset7dStr.flatMap { parseISO8601($0) },
            fetchedAt: Date()
        )
    }

    // MARK: - API Key (fallback)

    static func validate(apiKey: String) async throws {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FetchError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FetchError.networkError(NSError(domain: "RateLimitService", code: -1))
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw FetchError.invalidKey(http.statusCode)
        }
    }

    static func fetchViaAPIKey(apiKey: String) async throws -> RateLimitData {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FetchError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw FetchError.invalidKey(http.statusCode)
        }

        // Try unified headers (Max plan)
        if let util5hStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-unified-5h-utilization"),
           let reset5hStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-unified-5h-reset"),
           let util7dStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-unified-7d-utilization"),
           let reset7dStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-unified-7d-reset"),
           let util5h = Double(util5hStr),
           let reset5h = Double(reset5hStr),
           let util7d = Double(util7dStr),
           let reset7d = Double(reset7dStr) {
            return RateLimitData(
                fiveHourUtilization: util5h,
                fiveHourReset: Date(timeIntervalSince1970: reset5h),
                sevenDayUtilization: util7d,
                sevenDayReset: Date(timeIntervalSince1970: reset7d),
                fetchedAt: Date()
            )
        }

        // Fallback: per-resource headers
        if let tokensLimitStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-limit"),
           let tokensRemainingStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-remaining"),
           let tokensLimit = Double(tokensLimitStr),
           let tokensRemaining = Double(tokensRemainingStr),
           tokensLimit > 0 {
            let tokensResetStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-reset") ?? ""
            let resetDate = parseISO8601(tokensResetStr) ?? Date().addingTimeInterval(60)
            let utilization = (tokensLimit - tokensRemaining) / tokensLimit

            return RateLimitData(
                fiveHourUtilization: utilization,
                fiveHourReset: resetDate,
                sevenDayUtilization: nil,
                sevenDayReset: nil,
                fetchedAt: Date()
            )
        }

        throw FetchError.invalidResponse
    }

    private static func parseISO8601(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
