//
//  ServerApi.swift
//  CardUp
//
//  Created by Yuval Farangi on 22/02/2026.
//

import Foundation
import UIKit

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

    /// URLSession with extended timeouts for long-running AI generation requests
    private let longTimeoutSession: URLSession
    
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

        // Configure a separate session for AI generation endpoints (Gemini can take 60-90s)
        let longTimeoutConfiguration = URLSessionConfiguration.default
        longTimeoutConfiguration.timeoutIntervalForRequest = 120
        longTimeoutConfiguration.timeoutIntervalForResource = 180
        self.longTimeoutSession = URLSession(configuration: longTimeoutConfiguration)
        
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
        
        print("📦 Building multipart request:")
        print("  • Boundary: \(boundary)")
        print("  • File name: \(fileName)")
        print("  • MIME type: \(mimeType)")
        print("  • File size: \(data.count) bytes")
        
        var body = Data()
        
        // Add additional fields if provided
        if let fields = additionalFields {
            print("  • Additional fields: \(fields.count)")
            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
                print("    - \(key): \(value)")
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
        
        print("  • Total body size: \(body.count) bytes")
        print("  • Content-Type header: multipart/form-data; boundary=\(boundary)")
        
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
    
    /// Special POST request for card design that can handle both JSON and plain SVG responses
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - body: The request body to encode and send
    /// - Returns: CardDesignResponse with the design image (SVG string)
    private func postCardDesignRequest<U: Encodable>(
        endpoint: String,
        body: U
    ) async throws -> CardDesignResponse {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "POST"
        )
        
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("📡 \(request.httpMethod ?? "REQUEST") \(request.url?.absoluteString ?? "")")
        
        do {
            let (data, response) = try await longTimeoutSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServerApiError.invalidResponse
            }

            print("✅ Response: \(httpResponse.statusCode)")

            // Log content type for debugging
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
            print("📄 Content-Type: \(contentType)")
            print("📦 Response data size: \(data.count) bytes")

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

            // PRIORITY 1: Try to convert to text/string first
            if let responseText = String(data: data, encoding: .utf8), !responseText.isEmpty {
                print("📝 Response as text (first 100 chars): \(String(responseText.prefix(100)))")

                let trimmedText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)

                // PRIORITY 1A: Try JSON decoding FIRST (most common case)
                if trimmedText.hasPrefix("{") || trimmedText.hasPrefix("[") {
                    print("🔍 Response looks like JSON, attempting to decode...")
                    do {
                        let jsonResponse = try decoder.decode(CardDesignResponse.self, from: data)
                        print("✅ Successfully decoded as JSON CardDesignResponse")
                        return jsonResponse
                    } catch {
                        print("⚠️ JSON decoding failed: \(error)")
                        // Fall through to other methods
                    }
                }

                // PRIORITY 1B: Check if it's pure SVG (starts with < tag)
                if trimmedText.hasPrefix("<") {
                    print("✅ Detected pure SVG/XML content in response")
                    print("📦 Parsing as plain SVG text")
                    print("  • Length: \(responseText.count) characters")

                    // Return a CardDesignResponse with the SVG string (bypass Decodable)
                    return CardDesignResponse(designImage: responseText, message: nil)
                }

                // PRIORITY 1C: Check content type hints for text/svg
                let isTextResponse = contentType.contains("text") ||
                                   contentType.contains("svg") ||
                                   contentType.contains("xml") ||
                                   contentType.contains("html")

                if isTextResponse {
                    print("📦 Parsing as plain text response (based on Content-Type: \(contentType))")
                    print("  • Length: \(responseText.count) characters")

                    // Return as-is
                    return CardDesignResponse(designImage: responseText, message: nil)
                }

                // PRIORITY 2: Final fallback - return whatever text we got
                print("📦 Fallback: Returning response as-is")
                return CardDesignResponse(designImage: responseText, message: nil)
            }

            // If we can't convert to text at all, throw an error
            throw ServerApiError.invalidResponse

        } catch let error as ServerApiError {
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw ServerApiError.networkError(error)
        }
    }

    /// Special multipart POST request for card design that can handle both JSON and plain SVG responses
    /// - Parameters:
    ///   - endpoint: The API endpoint path
    ///   - data: The file data to upload
    ///   - fileName: The name of the file
    ///   - mimeType: The MIME type of the file
    ///   - additionalFields: Optional additional form fields
    /// - Returns: CardDesignResponse with the design image (SVG string)
    private func postMultipartCardDesign(
        endpoint: String,
        data: Data,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String]? = nil
    ) async throws -> CardDesignResponse {
        var request = try buildRequest(
            endpoint: endpoint,
            method: "POST"
        )
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        print("📦 Building multipart request:")
        print("  • Boundary: \(boundary)")
        print("  • File name: \(fileName)")
        print("  • MIME type: \(mimeType)")
        print("  • File size: \(data.count) bytes")
        
        var body = Data()
        
        // Add additional fields if provided
        if let fields = additionalFields {
            print("  • Additional fields: \(fields.count)")
            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
                print("    - \(key): \(value.prefix(100))...")
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
        
        print("  • Total body size: \(body.count) bytes")
        print("  • Content-Type header: multipart/form-data; boundary=\(boundary)")
        
        print("📡 \(request.httpMethod ?? "REQUEST") \(request.url?.absoluteString ?? "")")

        do {
            let (responseData, response) = try await longTimeoutSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServerApiError.invalidResponse
            }
            
            print("✅ Response: \(httpResponse.statusCode)")
            
            // Log content type for debugging
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
            print("📄 Content-Type: \(contentType)")
            print("📦 Response data size: \(responseData.count) bytes")
            
            // Check for successful status codes
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode error response
                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: responseData) {
                    throw ServerApiError.serverError(
                        statusCode: httpResponse.statusCode,
                        message: errorResponse.message
                    )
                }
                throw ServerApiError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // PRIORITY 1: Try to convert to text/string first
            if let responseText = String(data: responseData, encoding: .utf8), !responseText.isEmpty {
                print("📝 Response as text (first 100 chars): \(String(responseText.prefix(100)))")
                
                let trimmedText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // PRIORITY 1A: Try JSON decoding FIRST (most common case)
                if trimmedText.hasPrefix("{") || trimmedText.hasPrefix("[") {
                    print("🔍 Response looks like JSON, attempting to decode...")
                    do {
                        let jsonResponse = try decoder.decode(CardDesignResponse.self, from: responseData)
                        print("✅ Successfully decoded as JSON CardDesignResponse")
                        return jsonResponse
                    } catch {
                        print("⚠️ JSON decoding failed: \(error)")
                        // Fall through to other methods
                    }
                }
                
                // PRIORITY 1B: Check if it's pure SVG (starts with < tag)
                if trimmedText.hasPrefix("<") {
                    print("✅ Detected pure SVG/XML content in response")
                    print("📦 Parsing as plain SVG text")
                    print("  • Length: \(responseText.count) characters")
                    
                    // Return a CardDesignResponse with the SVG string (bypass Decodable)
                    return CardDesignResponse(designImage: responseText, message: nil)
                }
                
                // PRIORITY 1C: Check content type hints for text/svg
                let isTextResponse = contentType.contains("text") || 
                                   contentType.contains("svg") || 
                                   contentType.contains("xml") ||
                                   contentType.contains("html")
                
                if isTextResponse {
                    print("📦 Parsing as plain text response (based on Content-Type: \(contentType))")
                    print("  • Length: \(responseText.count) characters")
                    
                    // Return as-is
                    return CardDesignResponse(designImage: responseText, message: nil)
                }
                
                // PRIORITY 2: Final fallback - return whatever text we got
                print("📦 Fallback: Returning response as-is")
                return CardDesignResponse(designImage: responseText, message: nil)
            }
            
            // If we can't convert to text at all, throw an error
            throw ServerApiError.invalidResponse
            
        } catch let error as ServerApiError {
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw ServerApiError.networkError(error)
        }
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
    
    // MARK: - Gemini API Integration
    
    /// Process card image using Gemini AI
    /// - Parameter imageData: The card image data (JPEG or PNG)
    /// - Returns: Complete card analysis from Gemini including format, details, and design image
    /// - Throws: ServerApiError if the request fails
    /// - Note: This method throws errors including quota exceeded (429) errors. Calling code should handle
    ///         these gracefully by catching and continuing with default values for manual entry.
    func analyzeCardWithGemini(imageData: Data) async throws -> GeminiCardAnalysisResponse {
        // Log the request being sent to Gemini
        print("📤 Sending card scan request to Gemini AI")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📋 Request Details:")
        print("  • Endpoint: /api/gemini/cardDataExtraction")
        print("  • Method: POST (multipart/form-data)")
        print("  • Image Size: \(imageData.count) bytes (\(String(format: "%.2f", Double(imageData.count) / 1024.0)) KB)")
        print("  • MIME Type: image/jpeg")
        print("  • File Name: card.jpg")
        print("  • Server URL: \(baseURL)")
        
        // Calculate image dimensions if possible
        if let image = UIImage(data: imageData) {
            print("  • Image Dimensions: \(Int(image.size.width)) x \(Int(image.size.height)) pts")
            print("  • Image Scale: \(image.scale)x")
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("⏳ Waiting for Gemini AI analysis...")
        
        do {
            let response: GeminiCardAnalysisResponse = try await postMultipart(
                endpoint: "/api/gemini/cardDataExtraction",
                data: imageData,
                fileName: "card.jpg",
                mimeType: "image/jpeg"
            )
            
            // Log the response received
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("✅ Gemini AI Response Received")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 Response Summary:")
            print("  • Pass Format: \(response.passFormat.rawValue)")
            print("  • Organization: \(response.cardDetails.organizationName ?? "N/A")")
            print("  • Description: \(response.cardDetails.description ?? "N/A")")
            print("  • Logo Text: \(response.cardDetails.logoText ?? "N/A")")
            
            if let message = response.message {
                print("  • Message: \(message)")
            }
            
            print("\n🎨 Card Details:")
            if let orgName = response.cardDetails.organizationName {
                print("  • Organization Name: \(orgName)")
            }
            if let desc = response.cardDetails.description {
                print("  • Description: \(desc)")
            }
            
            print("\n📊 Barcode Information:")
            print("  • Barcode Message: \(response.cardDetails.barcodeMessage ?? "N/A")")
            print("  • Barcode Format: \(response.cardDetails.barcodeFormat ?? "N/A")")
            if let altText = response.cardDetails.barcodeAltText {
                print("  • Alt Text: \(altText)")
            }
            
            print("\n🎨 Visual Design:")
            print("  • Background Color: \(response.cardDetails.backgroundColor ?? "N/A")")
            print("  • Foreground Color: \(response.cardDetails.foregroundColor ?? "N/A")")
            print("  • Label Color: \(response.cardDetails.labelColor ?? "N/A")")
            
            // Log fields
            if let headerFields = response.cardDetails.headerFields, !headerFields.isEmpty {
                print("\n📌 Header Fields (\(headerFields.count)):")
                for (index, field) in headerFields.enumerated() {
                    print("  \(index + 1). \(field.key): \(field.value) \(field.label != nil ? "(\(field.label!))" : "")")
                }
            }
            
            if let primaryFields = response.cardDetails.primaryFields, !primaryFields.isEmpty {
                print("\n🔵 Primary Fields (\(primaryFields.count)):")
                for (index, field) in primaryFields.enumerated() {
                    print("  \(index + 1). \(field.key): \(field.value) \(field.label != nil ? "(\(field.label!))" : "")")
                }
            }
            
            if let secondaryFields = response.cardDetails.secondaryFields, !secondaryFields.isEmpty {
                print("\n🔸 Secondary Fields (\(secondaryFields.count)):")
                for (index, field) in secondaryFields.enumerated() {
                    print("  \(index + 1). \(field.key): \(field.value) \(field.label != nil ? "(\(field.label!))" : "")")
                }
            }
            
            if let auxiliaryFields = response.cardDetails.auxiliaryFields, !auxiliaryFields.isEmpty {
                print("\n📎 Auxiliary Fields (\(auxiliaryFields.count)):")
                for (index, field) in auxiliaryFields.enumerated() {
                    print("  \(index + 1). \(field.key): \(field.value) \(field.label != nil ? "(\(field.label!))" : "")")
                }
            }
            
            // Log store card specific info
            if let storeInfo = response.cardDetails.storeCardInfo {
                print("\n🏪 Store Card Info:")
                if let memberNumber = storeInfo.membershipNumber {
                    print("  • Membership Number: \(memberNumber)")
                }
                if let memberName = storeInfo.memberName {
                    print("  • Member Name: \(memberName)")
                }
                if let tier = storeInfo.tierLevel {
                    print("  • Tier Level: \(tier)")
                }
                if let points = storeInfo.pointsBalance {
                    print("  • Points Balance: \(points)")
                }
            }
            
            // Log coupon specific info
            if let couponInfo = response.cardDetails.couponInfo {
                print("\n🎟️ Coupon Info:")
                if let code = couponInfo.couponCode {
                    print("  • Coupon Code: \(code)")
                }
                if let discount = couponInfo.discountAmount {
                    print("  • Discount: \(discount)")
                }
                if let expiry = couponInfo.expirationDate {
                    print("  • Expires: \(expiry)")
                }
            }
            
            // Log dates
            if let expirationDate = response.cardDetails.expirationDate {
                print("\n📅 Expiration Date: \(expirationDate)")
            }
            if let relevantDate = response.cardDetails.relevantDate {
                print("📅 Relevant Date: \(relevantDate)")
            }
            
            // Try to encode to JSON for full inspection
            if let jsonData = try? JSONEncoder().encode(response.cardDetails),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("\n📄 Full Card Details JSON:")
                print(jsonString)
            }
            
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            return response
            
        } catch {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("❌ Gemini AI Request Failed")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Error: \(error.localizedDescription)")
            if let serverError = error as? ServerApiError {
                print("Error Type: \(serverError)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            throw error
        }
    }
    
    /// Generate a custom card design/banner image using Gemini AI
    /// - Parameters:
    ///   - cardDetails: The card details to use for design generation (organization name, colors, etc.)
    ///   - imageData: Optional reference image to extract styling from
    /// - Returns: Design image data response containing the generated banner
    /// - Throws: ServerApiError if the request fails
    /// - Note: This method throws errors including quota exceeded (429) errors. Calling code should handle
    ///         these gracefully by catching and continuing without a banner image (using background color instead).
    func generateCardDesign(
        cardDetails: CardDesignRequest,
        imageData: Data? = nil
    ) async throws -> CardDesignResponse {
        // Log the request being sent to Gemini
        print("🎨 Sending card design generation request to Gemini AI")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📋 Request Details:")
        print("  • Endpoint: /api/gemini/cardDesignGenerating")
        print("  • Method: POST (multipart/form-data)")
        print("  • Organization: \(cardDetails.organizationName ?? "N/A")")
        print("  • Description: \(cardDetails.description ?? "N/A")")
        print("  • Background Color: \(cardDetails.backgroundColor ?? "N/A")")
        print("  • Foreground Color: \(cardDetails.foregroundColor ?? "N/A")")
        
        if let imageData = imageData {
            print("  • Reference Image Size: \(imageData.count) bytes (\(String(format: "%.2f", Double(imageData.count) / 1024.0)) KB)")
            if let image = UIImage(data: imageData) {
                print("  • Reference Image Dimensions: \(Int(image.size.width)) x \(Int(image.size.height)) pts")
            }
        } else {
            print("  • Reference Image: None (using card details only)")
        }
        
        print("  • Server URL: \(baseURL)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("⏳ Waiting for Gemini AI to generate design...")
        
        do {
            let response: CardDesignResponse
            
            if let imageData = imageData {
                // Convert card details to JSON for multipart fields
                let cardDetailsJSON = try encoder.encode(cardDetails)
                guard let cardDetailsString = String(data: cardDetailsJSON, encoding: .utf8) else {
                    throw ServerApiError.decodingError(NSError(domain: "ServerApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode card details"]))
                }
                
                // Build multipart fields
                let fields = ["cardDetails": cardDetailsString]
                
                // Use the specialized multipart method that handles SVG responses
                response = try await postMultipartCardDesign(
                    endpoint: "/api/gemini/cardDesignGenerating",
                    data: imageData,
                    fileName: "reference.jpg",
                    mimeType: "image/jpeg",
                    additionalFields: fields
                )
            } else {
                // If no image, just send card details as JSON
                // Use the specialized method that handles SVG responses
                response = try await postCardDesignRequest(endpoint: "/api/gemini/cardDesignGenerating", body: cardDetails)
            }
            
            // Log the response received
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("✅ Gemini AI Design Generation Complete")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 Response Summary:")
            print("  • Design Image Length: \(response.designImage.count) characters")
            print("  • First 50 chars: \(response.designImage.prefix(50))...")
            print("  • Contains SVG: \(response.designImage.contains("<svg"))")
            print("  • Is Base64: \(response.designImage.hasPrefix("data:image"))")
            print("  • Is URL: \(response.designImage.hasPrefix("http"))")
            
            if let message = response.message {
                print("  • Message: \(message)")
            }
            
            // Validate the design image
            if response.designImage.isEmpty {
                print("⚠️ Warning: Design image is empty")
            } else {
                print("✅ Design image generated successfully")
            }
            
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            return response
            
        } catch {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("❌ Gemini AI Design Generation Failed")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Error: \(error.localizedDescription)")
            if let serverError = error as? ServerApiError {
                print("Error Type: \(serverError)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            throw error
        }
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

// MARK: - Gemini API Response Types

/// Response from Gemini card analysis
struct GeminiCardAnalysisResponse: Decodable {
    /// The recommended PassKit format for this card
    let passFormat: GeminiPassFormat
    
    /// Card details in JSON format matching Apple PassKit requirements
    let cardDetails: GeminiCardDetails
    
    /// Optional error message if processing had issues
    let message: String?
}

/// PassKit format recommended by Gemini
enum GeminiPassFormat: String, Codable {
    case generic = "generic"
    case coupon = "coupon"
    case storeCard = "storeCard"
    case eventTicket = "eventTicket"
    case boardingPass = "boardingPass"
}

/// Card details extracted and formatted by Gemini
/// This structure aligns with Apple PassKit's Generic pass format
/// Gemini AI should return JSON matching this exact structure
struct GeminiCardDetails: Codable {
    // MARK: - Required Pass Metadata
    
    /// Organization name (e.g., "My gym name")
    let organizationName: String?
    
    /// Pass description (e.g., "Gym membership pass")
    let description: String?
    
    /// Text to display next to logo (e.g., "My gym")
    let logoText: String?
    
    // MARK: - Barcode Information
    
    /// Barcode message/data (e.g., "12345678")
    let barcodeMessage: String?
    
    /// Barcode format (e.g., "PKBarcodeFormatQR", "PKBarcodeFormatCode128", "PKBarcodeFormatPDF417")
    let barcodeFormat: String?
    
    /// Alternative text for accessibility
    let barcodeAltText: String?
    
    /// Message encoding (typically "iso-8859-1")
    let barcodeMessageEncoding: String?
    
    // MARK: - Generic Pass Fields (Apple PassKit Structure)
    
    /// Header fields displayed at the top of the pass (optional)
    /// Example: [{"key": "points", "label": "POINTS", "value": "1234"}]
    let headerFields: [GeminiPassField]?
    
    /// Primary fields - most prominent information on the pass
    /// Example: [{"key": "memberName", "label": "Name", "value": "Maria Ruiz"}]
    let primaryFields: [GeminiPassField]?
    
    /// Secondary fields - additional information below primary
    /// Example: [{"key": "memberNumber", "label": "Member Number", "value": "7337"}]
    let secondaryFields: [GeminiPassField]?
    
    /// Auxiliary fields - supporting details
    /// Example: [{"key": "memberSince", "label": "Joined", "value": "2026-01-02T00:00-7:00", "dateStyle": "PKDateStyleShort"}]
    let auxiliaryFields: [GeminiPassField]?
    
    /// Back fields - information on the back of the pass
    /// Example: [{"key": "terms", "label": "Terms and Conditions", "value": "Lorem ipsum..."}]
    let backFields: [GeminiPassField]?
    
    // MARK: - Visual Design Colors
    
    /// Foreground color in rgb() or hex format (e.g., "rgb(0, 0, 0)" or "#000000")
    let foregroundColor: String?
    
    /// Background color in rgb() or hex format (e.g., "rgb(245, 197, 67)" or "#F5C543")
    let backgroundColor: String?
    
    /// Label color (optional, defaults to foregroundColor)
    let labelColor: String?
    
    // MARK: - Dates
    
    /// Expiration date in ISO 8601 format (e.g., "2026-12-31T23:59:59-08:00")
    let expirationDate: String?
    
    /// Relevant date - when the pass becomes relevant (ISO 8601 format)
    let relevantDate: String?
    
    // MARK: - Legacy/Specific Format Support
    
    /// Store Card Specific information (for backward compatibility)
    let storeCardInfo: StoreCardInfo?
    
    /// Coupon Specific information (for backward compatibility)
    let couponInfo: CouponInfo?
    
    /// Event Ticket Specific information (for backward compatibility)
    let eventInfo: EventInfo?
}

/// PassKit field structure matching Apple's pass.json format
/// This is what Gemini should return for each field in primaryFields, secondaryFields, etc.
struct GeminiPassField: Codable {
    /// Unique key for this field (e.g., "memberName", "memberNumber")
    let key: String
    
    /// Label text displayed above the value (e.g., "Name", "Member Number")
    let label: String?
    
    /// The actual value to display (e.g., "Maria Ruiz", "7337")
    let value: String
    
    /// Text alignment: "PKTextAlignmentLeft", "PKTextAlignmentCenter", "PKTextAlignmentRight"
    let textAlignment: String?
    
    /// Date style: "PKDateStyleShort", "PKDateStyleMedium", "PKDateStyleLong", "PKDateStyleFull"
    /// Only used when value is a date string in ISO 8601 format
    let dateStyle: String?
    
    /// Time style: "PKDateStyleShort", "PKDateStyleMedium", "PKDateStyleLong", "PKDateStyleFull"
    /// Only used when value is a date string in ISO 8601 format
    let timeStyle: String?
    
    /// Number style: "PKNumberStyleDecimal", "PKNumberStylePercent", "PKNumberStyleScientific", "PKNumberStyleSpellOut"
    let numberStyle: String?
    
    /// ISO 4217 currency code (e.g., "USD", "EUR") when displaying currency
    let currencyCode: String?
    
    /// Message to display when this field's value changes
    let changeMessage: String?
}

/// Store card specific information
struct StoreCardInfo: Codable {
    let membershipNumber: String?
    let memberName: String?
    let tierLevel: String?
    let pointsBalance: String?
}

/// Coupon specific information
struct CouponInfo: Codable {
    let couponCode: String?
    let discountAmount: String?
    let expirationDate: String?
    let termsAndConditions: String?
}

/// Event ticket specific information
struct EventInfo: Codable {
    let eventName: String?
    let venueName: String?
    let venueAddress: String?
    let eventDate: String?
    let eventTime: String?
    let seatInfo: String?
    let gateInfo: String?
}

// MARK: - Card Design Generation Types

/// Request for generating a custom card design/banner image
struct CardDesignRequest: Encodable {
    /// Organization name to display on the card
    let organizationName: String?
    
    /// Pass description
    let description: String?
    
    /// Logo text to include in the design
    let logoText: String?
    
    /// Background color in hex format (e.g., "#3B82F6")
    let backgroundColor: String?
    
    /// Foreground color in hex format (e.g., "#FFFFFF")
    let foregroundColor: String?
    
    /// Optional theme or style hints for the AI (e.g., "modern", "elegant", "playful")
    let designStyle: String?
    
    /// Optional additional context or requirements
    let additionalContext: String?
}

/// Response from card design generation
struct CardDesignResponse: Decodable {
    /// URL or base64-encoded image of the generated design
    /// Format: Either "data:image/png;base64,..." or "https://..." or SVG string
    /// Expected size: 1125 x 432 pixels (@3x resolution) for Generic passes
    let designImage: String
    
    /// Optional message about the generation process
    let message: String?
    
    // Simple initializer for programmatic creation
    init(designImage: String, message: String?) {
        self.designImage = designImage
        self.message = message
    }
    
    // Custom coding keys to handle multiple field name variations
    enum CodingKeys: String, CodingKey {
        case designImage = "designImage"
        case designSvg = "designSvg"  // Alternative field name
        case message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try multiple field name variations
        if let designImageValue = try? container.decode(String.self, forKey: .designImage) {
            self.designImage = designImageValue
        } else if let designSvgValue = try? container.decode(String.self, forKey: .designSvg) {
            self.designImage = designSvgValue
        } else {
            // Fallback: try snake_case by using a dynamic key
            let snakeCaseContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
            if let snakeCaseImage = try? snakeCaseContainer.decode(String.self, forKey: DynamicCodingKey(stringValue: "design_image")!) {
                self.designImage = snakeCaseImage
            } else if let snakeCaseSvg = try? snakeCaseContainer.decode(String.self, forKey: DynamicCodingKey(stringValue: "design_svg")!) {
                self.designImage = snakeCaseSvg
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.designImage,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Could not find designImage, designSvg, design_image, or design_svg in response"
                    )
                )
            }
        }
        
        self.message = try? container.decode(String.self, forKey: .message)
    }
}

// Helper for dynamic coding keys
private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
