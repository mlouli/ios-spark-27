import Foundation

nonisolated enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

nonisolated enum APIEndpoint {
    case stories(page: Int, limit: Int)
    case state(userID: String)
    case like(userID: String, storyID: String, isLiked: Bool)
    case seen(userID: String, storyID: String)
}

extension APIEndpoint {
    var method: HTTPMethod {
        switch self {
        case .stories, .state: return .get
        case .like, .seen: return .post
        }
    }

    var path: String {
        switch self {
        case .stories: return "/api/stories"
        case .state: return "/api/state"
        case .like: return "/api/like"
        case .seen: return "/api/seen"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .stories(let page, let limit):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        case .state(let userID):
            return [URLQueryItem(name: "userID", value: userID)]
        case .like, .seen:
            return nil
        }
    }

    var body: Data? {
        switch self {
        case .stories, .state:
            return nil
        case .like(let userID, let storyID, let isLiked):
            return try? JSONEncoder().encode(LikeBody(userID: userID, storyID: storyID, isLiked: isLiked))
        case .seen(let userID, let storyID):
            return try? JSONEncoder().encode(SeenBody(userID: userID, storyID: storyID))
        }
    }
}

// MARK: - Request body types

private nonisolated struct LikeBody: Encodable {
    let userID: String
    let storyID: String
    let isLiked: Bool
}

private nonisolated struct SeenBody: Encodable {
    let userID: String
    let storyID: String
}
