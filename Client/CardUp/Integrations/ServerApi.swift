//
//  ServerApi.swift
//  CardUp
//
//  Created by Yuval Farangi on 22/02/2026.
//

import Foundation

/// A service class for handling all server API communications
@Observable
final class ServerApi {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = ServerApi()
    
    /// Base URL for the server - loaded from environment configuration
    private var baseURL: String
    
    /// URLSession for network requests
    private let session: URLSession
    
    /// JSON encoder with consistent configuration
    private let encoder: JSONEncoder
    
    /// JSON decoder with consistent configuration
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    private init() {
        // Load base URL from configuration
        if let serverURL = ProcessInfo.processInfo.environment["SERVER_URL"] {
            self.baseURL = serverURL
        } else {
            // Default to localhost:3000 for development
            self.baseURL = "http://localhost:3000"
        }
        
        // Configure URLSession
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        // Configure JSON encoder/decoder
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        print("🌐 ServerApi initialized with base URL: \(baseURL)")
    }
    
    // MARK: - Configuration
    
    /// Update the base URL at runtime if needed
    func updateBaseURL(_ url: String) {
        self.baseURL = url
        print("🌐 ServerApi base URL updated to: \(baseURL)")
    }
    
    // MARK: - HTTP Methods
    
    /// Performs a GET request
    /// - Parameters:
    ///   - endpoint: The API endpoint path (e.g., "/cards")
    ///   - queryItems: Optional query parameters
    /// - Returns: Decoded response of type T
    func get<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let request = try buildRequest(
            endpoint: endpoint,
            method: "GET",
            queryItems: queryItems
        )
        
        return try await performRequest(request)
    }
    
    /// Performs a POST request
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - body: The request body to encode and send
    /// - Returns: Decoded response of type T
    func post<T: Decodable, U: Encodable>(
        endpoint: String,
        body: U
    ) async throws -> T {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "POST"
        )
        
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return try await performRequest(request)
    }
    
    /// Performs a POST request without a response body
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - body: The request body to encode and send
    func post<U: Encodable>(
        endpoint: String,
        body: U
    ) async throws {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "POST"
        )
        
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let _: EmptyResponse = try await performRequest(request)
    }
    
    /// Performs a POST request with multipart/form-data (for file uploads)
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - data: The file data to upload
    ///   - fileName: The name of the file
    ///   - mimeType: The MIME type of the file
    ///   - additionalFields: Optional additional form fields
    /// - Returns: Decoded response of type T
    func postMultipart<T: Decodable>(
        endpoint: String,
        data: Data,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String]? = nil
    ) async throws -> T {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "POST"
        )
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add additional fields if provided
        if let fields = additionalFields {
            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await performRequest(request)
    }
    
    /// Performs a PUT request
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - body: The request body to encode and send
    /// - Returns: Decoded response of type T
    func put<T: Decodable, U: Encodable>(
        endpoint: String,
        body: U
    ) async throws -> T {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "PUT"
        )
        
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return try await performRequest(request)
    }
    
    /// Performs a PUT request without a response body
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - body: The request body to encode and send
    func put<U: Encodable>(
        endpoint: String,
        body: U
    ) async throws {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "PUT"
        )
        
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let _: EmptyResponse = try await performRequest(request)
    }
    
    /// Performs a PATCH request
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - body: The request body to encode and send
    /// - Returns: Decoded response of type T
    func patch<T: Decodable, U: Encodable>(
        endpoint: String,
        body: U
    ) async throws -> T {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "PATCH"
        )
        
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return try await performRequest(request)
    }
    
    /// Performs a PATCH request without a response body
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - body: The request body to encode and send
    func patch<U: Encodable>(
        endpoint: String,
        body: U
    ) async throws {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "PATCH"
        )
        
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let _: EmptyResponse = try await performRequest(request)
    }
    
    /// Performs a DELETE request
    /// - Parameter endpoint: The API endpoint path
    /// - Returns: Decoded response of type T
    func delete<T: Decodable>(endpoint: String) async throws -> T {
        let request = try buildRequest(
            endpoint: endpoint,
            method: "DELETE"
        )
        
        return try await performRequest(request)
    }
    
    /// Performs a DELETE request without a response body
    /// - Parameter endpoint: The API endpoint path
    func delete(endpoint: String) async throws {
        let request = try buildRequest(
            endpoint: endpoint,
            method: "DELETE"
        )
        
        let _: EmptyResponse = try await performRequest(request)
    }
    
    /// Performs a HEAD request (to check if a resource exists)
    /// - Parameter endpoint: The API endpoint path
    /// - Returns: The HTTP status code
    func head(endpoint: String) async throws -> Int {
        let request = try buildRequest(
            endpoint: endpoint,
            method: "HEAD"
        )
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerApiError.invalidResponse
        }
        
        return httpResponse.statusCode
    }
    
    /// Downloads raw data from an endpoint
    /// - Parameter endpoint: The API endpoint path
    /// - Returns: Raw Data
    func downloadData(endpoint: String) async throws -> Data {
        let request = try buildRequest(
            endpoint: endpoint,
            method: "GET"
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerApiError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ServerApiError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return data
    }
    
    // MARK: - Private Helper Methods
    
    /// Builds a URLRequest with the given parameters
    private func buildRequest(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        // Construct full URL
        let urlString = baseURL + endpoint
        
        guard var urlComponents = URLComponents(string: urlString) else {
            throw ServerApiError.invalidURL(urlString)
        }
        
        // Add query items if provided
        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw ServerApiError.invalidURL(urlString)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    /// Performs the actual network request and decodes the response
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        print("📡 \(request.httpMethod ?? "REQUEST") \(request.url?.absoluteString ?? "")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServerApiError.invalidResponse
            }
            
            print("✅ Response: \(httpResponse.statusCode)")
            
            // Check for successful status codes
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error response
                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                    throw ServerApiError.serverError(
                        statusCode: httpResponse.statusCode,
                        message: errorResponse.message
                    )
                }
                throw ServerApiError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Handle empty response types
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            
            // Decode the response
            let decodedResponse = try decoder.decode(T.self, from: data)
            return decodedResponse
            
        } catch let error as ServerApiError {
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw ServerApiError.networkError(error)
        }
    }
}

// MARK: - Supporting Types

/// Empty response type for requests that don't return data
struct EmptyResponse: Decodable {
    init() {}
}

/// Standard error response structure from server
struct ErrorResponse: Decodable {
    let message: String
    let code: String?
}

// MARK: - Error Types

enum ServerApiError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int)
    case serverError(statusCode: Int, message: String)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Endpoints Extension

extension ServerApi {
    
    // MARK: - Health & Status
    
    /// Check if the server is reachable and healthy
    func healthCheck() async throws -> HealthCheckResponse {
        return try await get(endpoint: "/health")
    }
    
    // MARK: - Pass Generation
    
    /// Generate a PassKit pass for a card
    /// - Parameter payload: The pass payload containing card information
    /// - Returns: Raw .pkpass file data
    func generatePass(payload: PassPayload) async throws -> Data {
        return try await post(endpoint: "/generate-pass", body: payload)
    }
    
    // MARK: - Card Management (Example endpoints - implement based on your backend)
    
    /// Fetch all cards for the user
    func fetchCards() async throws -> [CardDTO] {
        return try await get(endpoint: "/cards")
    }
    
    /// Fetch a specific card by ID
    func fetchCard(id: String) async throws -> CardDTO {
        return try await get(endpoint: "/cards/\(id)")
    }
    
    /// Create a new card
    func createCard(request: CreateCardRequest) async throws -> CardDTO {
        return try await post(endpoint: "/cards", body: request)
    }
    
    /// Update an existing card
    func updateCard(id: String, request: UpdateCardRequest) async throws -> CardDTO {
        return try await put(endpoint: "/cards/\(id)", body: request)
    }
    
    /// Delete a card
    func deleteCard(id: String) async throws {
        try await delete(endpoint: "/cards/\(id)")
    }
    
    /// Upload card image (logo, banner, etc.)
    func uploadCardImage(
        cardId: String,
        imageData: Data,
        imageType: CardImageType
    ) async throws -> ImageUploadResponse {
        return try await postMultipart(
            endpoint: "/cards/\(cardId)/images",
            data: imageData,
            fileName: "\(imageType.rawValue).jpg",
            mimeType: "image/jpeg",
            additionalFields: ["type": imageType.rawValue]
        )
    }
    
    // MARK: - Analytics (Optional)
    
    /// Log an analytics event
    func logEvent(event: AnalyticsEvent) async throws {
        try await post(endpoint: "/analytics", body: event)
    }
}

// MARK: - Data Transfer Objects (DTOs)

/// Response type for health check
struct HealthCheckResponse: Decodable {
    let status: String
    let timestamp: String?
    let version: String?
}
/// Card data transfer object
struct CardDTO: Codable {
    let id: String
    let name: String
    let type: String
    let barcodeString: String
    let barcodeFormat: String
    let createdAt: String?
    let updatedAt: String?
}

/// Request to create a new card
struct CreateCardRequest: Encodable {
    let name: String
    let type: String
    let barcodeString: String
    let barcodeFormat: String
    let membershipNumber: String?
    let expirationDate: String?
}

/// Request to update an existing card
struct UpdateCardRequest: Encodable {
    let name: String?
    let membershipNumber: String?
    let expirationDate: String?
}

/// Card image types
enum CardImageType: String, Codable {
    case logo
    case banner
    case icon
}

/// Response from image upload
struct ImageUploadResponse: Decodable {
    let imageUrl: String
    let imageType: String
}

/// Analytics event
struct AnalyticsEvent: Encodable {
    let eventName: String
    let timestamp: Date
    let properties: [String: String]?
}

