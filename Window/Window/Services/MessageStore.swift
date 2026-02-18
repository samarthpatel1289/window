import Foundation

enum MessageStore {
    private static let filename = "messages.json"

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appending(path: filename)
    }

    static func save(_ messages: [Message]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(messages) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> [Message] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Message].self, from: data)) ?? []
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
