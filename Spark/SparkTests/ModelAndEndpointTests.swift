import Testing
import Foundation
@testable import Spark

@Suite("Models")
struct ModelTests {
    @Test func storyImageURLUsesSeedAndStorySize() {
        let story = makeStory(id: "s1", seed: "alpine")
        #expect(story.imageURL.absoluteString == "https://picsum.photos/seed/alpine/800/1400")
    }

    @Test func userAvatarURLUsesAvatarSeed() {
        let user = StoryUser(id: "u1", username: "u", avatarSeed: "portrait", stories: [])
        #expect(user.avatarURL.absoluteString == "https://picsum.photos/seed/portrait/300/300")
    }

    @Test func storyUserCodableRoundTrip() throws {
        let user = makeUser(id: "u1", storyCount: 2)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(StoryUser.self, from: encoder.encode(user))
        #expect(decoded == user)
    }

    @Test func userStateStartsEmpty() {
        let state = UserState()
        #expect(state.likedStoryIDs.isEmpty)
        #expect(state.seenStoryIDs.isEmpty)
        #expect(state.pendingActions.isEmpty)
    }

    @Test func pendingActionsGetUniqueIDs() {
        let first = PendingAction(storyID: "s1", type: .like)
        let second = PendingAction(storyID: "s1", type: .like)
        #expect(first.id != second.id)
        #expect(first.storyID == "s1")
        #expect(first.type == .like)
    }
}

@Suite("APIEndpoint")
struct APIEndpointTests {
    @Test func methodsMatchSemantics() {
        #expect(APIEndpoint.stories(page: 1, limit: 10).method == .get)
        #expect(APIEndpoint.state(userID: "d1").method == .get)
        #expect(APIEndpoint.like(userID: "d1", storyID: "s1", isLiked: true).method == .post)
        #expect(APIEndpoint.seen(userID: "d1", storyID: "s1").method == .post)
    }

    @Test func pathsAreStable() {
        #expect(APIEndpoint.stories(page: 1, limit: 10).path == "/api/stories")
        #expect(APIEndpoint.state(userID: "d1").path == "/api/state")
        #expect(APIEndpoint.like(userID: "d1", storyID: "s1", isLiked: true).path == "/api/like")
        #expect(APIEndpoint.seen(userID: "d1", storyID: "s1").path == "/api/seen")
    }

    @Test func storiesQueryCarriesPageAndLimit() throws {
        let items = try #require(APIEndpoint.stories(page: 3, limit: 20).queryItems)
        #expect(items.contains(URLQueryItem(name: "page", value: "3")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "20")))
    }

    @Test func stateQueryCarriesUserID() throws {
        let items = try #require(APIEndpoint.state(userID: "device42").queryItems)
        #expect(items == [URLQueryItem(name: "userID", value: "device42")])
    }

    @Test func getEndpointsHaveNoBody() {
        #expect(APIEndpoint.stories(page: 1, limit: 10).body == nil)
        #expect(APIEndpoint.state(userID: "d1").body == nil)
    }

    @Test func likeBodyEncodesAllFields() throws {
        let body = try #require(APIEndpoint.like(userID: "d1", storyID: "s1", isLiked: true).body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["userID"] as? String == "d1")
        #expect(json["storyID"] as? String == "s1")
        #expect(json["isLiked"] as? Bool == true)
    }

    @Test func seenBodyEncodesAllFields() throws {
        let body = try #require(APIEndpoint.seen(userID: "d1", storyID: "s7").body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["userID"] as? String == "d1")
        #expect(json["storyID"] as? String == "s7")
    }
}

@Suite("DeviceID")
struct DeviceIDTests {
    @Test func deviceIDIsStableAcrossReads() {
        let first = DeviceID.current
        let second = DeviceID.current
        #expect(first == second)
        #expect(first.isEmpty == false)
    }
}
