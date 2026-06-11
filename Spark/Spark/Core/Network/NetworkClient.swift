import Foundation
import OSLog

enum NetworkError: Error {
    case invalidResponse(statusCode: Int)
    case decodingFailed(Error)
}

final class NetworkClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://ios-spark-27-backend.vercel.app")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }()
    }

    /// Performs a request and decodes the response body into `T`.
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let urlRequest = try makeURLRequest(for: endpoint)
        let (data, response) = try await session.data(for: urlRequest)
        do {
            try validate(response)
        } catch {
            AppLogger.network.error("Request failed: \(endpoint.path, privacy: .public) — \(error, privacy: .public)")
            throw error
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            AppLogger.network.error("Decoding failed: \(endpoint.path, privacy: .public) — \(error, privacy: .public)")
            throw NetworkError.decodingFailed(error)
        }
    }

    /// Performs a request and discards the response body.
    func request(_ endpoint: APIEndpoint) async throws {
        let urlRequest = try makeURLRequest(for: endpoint)
        let (_, response) = try await session.data(for: urlRequest)
        do {
            try validate(response)
        } catch {
            AppLogger.network.error("Request failed: \(endpoint.path, privacy: .public) — \(error, privacy: .public)")
            throw error
        }
    }

    // MARK: - Private

    private func makeURLRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: endpoint.path), resolvingAgainstBaseURL: false)!
        components.queryItems = endpoint.queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        // Future: add Authorization header here, e.g.:
        // request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.invalidResponse(statusCode: http.statusCode)
        }
    }
}
