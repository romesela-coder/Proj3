import Foundation
import UIKit

/// Evidence files are copied into the app container, never referenced by an
/// external link (US-A4). Nothing here touches the network.
enum AttachmentStore {
    static let maxPerEntry = 3

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Re-encodes to JPEG so we store an image, not whatever container the
    /// picker handed us.
    @discardableResult
    static func save(imageData: Data) -> String? {
        guard let image = UIImage(data: imageData),
              let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            try jpeg.write(to: url(for: name), options: .completeFileProtection)
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String) -> UIImage? {
        guard let data = try? Data(contentsOf: url(for: name)) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(for: name))
    }
}
