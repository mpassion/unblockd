import Foundation
import AppKit

/// Simple singleton to manage in-memory caching of avatars
@MainActor
class AvatarService {
    static let shared = AvatarService()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        // Limit cache to ~50 images to be conservative with memory
        cache.countLimit = 50
    }

    func getImage(for url: URL) -> NSImage? {
        return cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    func fetchImage(for url: URL) async throws -> NSImage {
        if let cached = getImage(for: url) {
            return cached
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let originalImage = NSImage(data: data) else {
            throw NSError(domain: "AvatarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }

        // Downsample to max 60x60 (3x for 20pt display)
        let downsampled = self.resize(image: originalImage, to: CGSize(width: 60, height: 60))

        setImage(downsampled, for: url)
        return downsampled
    }

    private func resize(image: NSImage, to maxSize: CGSize) -> NSImage {
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height

        var newSize: CGSize
        if aspectRatio > 1 {
            newSize = CGSize(width: maxSize.width, height: maxSize.width / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize.height * aspectRatio, height: maxSize.height)
        }

        if originalSize.width <= newSize.width && originalSize.height <= newSize.height {
            return image
        }

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()

        return newImage
    }
}

/// Observable object to manage loading state for a specific avatar
@MainActor
class AvatarLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading = false

    private var fetchTask: Task<Void, Never>?

    func load(url: URL?) {
        guard let url = url else { return }

        if let cached = AvatarService.shared.getImage(for: url) {
            self.image = cached
            return
        }

        isLoading = true
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            do {
                let fetchedImage = try await AvatarService.shared.fetchImage(for: url)
                await MainActor.run {
                    self?.image = fetchedImage
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.isLoading = false
                }
            }
        }
    }

    func cancel() {
        fetchTask?.cancel()
    }
}
