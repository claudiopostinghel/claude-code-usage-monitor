import Foundation

struct VersionManifest: Codable, Sendable {
    let version: String
    let releaseURL: String?
}
