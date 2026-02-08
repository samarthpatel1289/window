import Foundation

/// REST client for the Window Protocol.
/// Handles GET /status and GET /messages.
class WindowClient {
    private let baseURL: String
    private let apiKey: String

    init(host: String, apiKey: String) {
        // Ensure the host has a scheme
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            self.baseURL = host
        } else {
            self.baseURL = "http://\(host)"
        }
        self.apiKey = apiKey
    }

    // MARK: - GET /status

    func fetchStatus() async -> AgentStatus? {
        guard let url = URL(string: "\(baseURL)/status") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            return try decoder.decode(AgentStatus.self, from: data)
        } catch {
            print("[WindowClient] fetchStatus error: \(error)")
            return nil
        }
    }

    // MARK: - GET /messages

    func fetchMessages(limit: Int = 20, before: Date? = nil) async -> [Message]? {
        var components = URLComponents(string: "\(baseURL)/messages")
        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]

        if let before = before {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "before", value: formatter.string(from: before)))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            struct MessagesResponse: Codable {
                let messages: [MessageDTO]
            }

            struct MessageDTO: Codable {
                let id: String
                let role: String
                let content: String
                let timestamp: String
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(MessagesResponse.self, from: data)

            let formatter = ISO8601DateFormatter()

            return result.messages.compactMap { dto in
                guard let role = Message.Role(rawValue: dto.role),
                      let date = formatter.date(from: dto.timestamp) else {
                    return nil
                }
                return Message(id: dto.id, role: role, content: dto.content, timestamp: date)
            }
        } catch {
            print("[WindowClient] fetchMessages error: \(error)")
            return nil
        }
    }
}
