import Foundation

enum APIError: Error {
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
}

class APIClient {
    static let shared = APIClient()
    private let baseURL: String
    
    // Storage mode configuration
    static var isServerOnlyMode: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaultsKeys.serverOnlyMode)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.serverOnlyMode)
        }
    }
    
    // Configured JSON decoder/encoder for dates
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
    
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        encoder.dateEncodingStrategy = .formatted(formatter)
        return encoder
    }()
    
    private init() {
        // Read SERVER_URL from environment variables
        if let serverURL = ProcessInfo.processInfo.environment["SERVER_URL"] {
            self.baseURL = serverURL + "/api"
        } else {
            // Fallback to development IP if environment variable is not set
            #if DEBUG
            self.baseURL = "http://127.0.0.1:8000/api"  // Use this when running in simulator
            // self.baseURL = "http://YOUR_MACHINE_IP:8000/api"  // Uncomment and replace with your IP when running on device
            #else
            self.baseURL = "http://localhost:8000/api"  // Production URL (should be set via SERVER_URL env var)
            #endif
            print("[DEBUG] Using base URL: \(self.baseURL)")
        }
    }
    
    // MARK: - Log Endpoints
    func createLog(_ log: Log) async throws -> LogPayload {
        let url = URL(string: "\(baseURL)/logs")!
        print("[DEBUG] Creating log with URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert tags to TagPayload array
        let tagPayloads = log.tags.map { tag in
            TagPayload(
                id: tag.wrappedId,
                name: tag.wrappedName,
                color: tag.color,
                createdAt: tag.wrappedCreatedAt
            )
        }
        
        let payload = LogPayload(
            id: log.wrappedId,  // Send client-generated ID to server
            content: log.wrappedContent,
            createdAt: log.wrappedCreatedAt,
            updatedAt: log.wrappedUpdatedAt,
            wordCount: log.wordCount,
            processingStatus: log.processingStatus ?? "pending",
            tags: tagPayloads
        )
        
        do {
            let jsonData = try jsonEncoder.encode(payload)
            request.httpBody = jsonData
            print("[DEBUG] Request payload: \(String(data: jsonData, encoding: .utf8) ?? "")")
        } catch {
            print("[ERROR] Failed to encode payload: \(error)")
            throw error
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("[DEBUG] Response status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            print("[DEBUG] Response data: \(String(data: data, encoding: .utf8) ?? "")")
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("[ERROR] Invalid response: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                throw APIError.invalidResponse
            }
            
            // Decode and return the server response
            let serverLog = try jsonDecoder.decode(LogPayload.self, from: data)
            return serverLog
        } catch {
            print("[ERROR] Network request failed: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    func updateLog(_ log: Log) async throws {
        let url = URL(string: "\(baseURL)/logs/\(log.wrappedId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert tags to TagPayload array
        let tagPayloads = log.tags.map { tag in
            TagPayload(
                id: tag.wrappedId,
                name: tag.wrappedName,
                color: tag.color,
                createdAt: tag.wrappedCreatedAt
            )
        }
        
        let payload = LogPayload(
            id: log.wrappedId,
            content: log.wrappedContent,
            createdAt: log.wrappedCreatedAt,
            updatedAt: log.wrappedUpdatedAt,
            wordCount: log.wordCount,
            processingStatus: log.processingStatus ?? "pending",
            tags: tagPayloads
        )
        
        request.httpBody = try jsonEncoder.encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func deleteLog(_ logId: UUID) async throws {
        let url = URL(string: "\(baseURL)/logs/\(logId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func fetchLogs() async throws -> [LogPayload] {
        let url = URL(string: "\(baseURL)/logs")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try jsonDecoder.decode([LogPayload].self, from: data)
    }
    
    // MARK: - Tag Endpoints
    func createTag(_ tag: Tag) async throws {
        let url = URL(string: "\(baseURL)/tags")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = TagPayload(
            id: tag.wrappedId,
            name: tag.wrappedName,
            color: tag.color ?? "",
            createdAt: tag.wrappedCreatedAt
        )
        
        request.httpBody = try jsonEncoder.encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func fetchTags() async throws -> [TagPayload] {
        let url = URL(string: "\(baseURL)/tags")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try jsonDecoder.decode([TagPayload].self, from: data)
    }
    
    // MARK: - Query Endpoints
    func performSearch(query: String) async throws -> SearchResponse {
        let url = URL(string: "\(baseURL)/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["query": query]
        request.httpBody = try jsonEncoder.encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try jsonDecoder.decode(SearchResponse.self, from: data)
    }
}

// MARK: - API Models
struct LogPayload: Codable {
    let id: UUID  // Required field now
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let wordCount: Int32
    let processingStatus: String
    let tags: [TagPayload]
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case wordCount = "word_count"
        case processingStatus = "processing_status"
        case tags
    }
}

struct TagPayload: Codable {
    let id: UUID
    let name: String
    let color: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case createdAt = "created_at"
    }
}

struct SearchResponse: Codable {
    let query: String
    let results: [SearchResult]
    let executionTime: Double
}

struct SearchResult: Codable {
    let logId: UUID
    let snippetText: String
    let snippetStartIndex: Int32
    let snippetEndIndex: Int32
    let contextBefore: String?
    let contextAfter: String?
    let relevanceScore: Double
    let rank: Int32
} 