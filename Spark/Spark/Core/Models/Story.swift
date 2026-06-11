import Foundation

struct Story: Identifiable, Codable, Hashable {
    let id: String
    let imageSeed: String
    let caption: String
    let timestamp: Date

    var imageURL: URL {
        URL(string: "https://picsum.photos/seed/\(imageSeed)/800/1400")!
    }
}
