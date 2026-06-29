import Foundation
import UIKit

actor ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()

    // Limit concurrency by using a simple semaphore count via in-flight tasks dictionary
    private var inFlightTasks: [NSURL: Task<UIImage, Error>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 6
        self.session = URLSession(configuration: config)

        cache.countLimit = 300 // tune as needed
        cache.totalCostLimit = 64 * 1024 * 1024 // ~64MB
    }

    func image(from url: URL, retries: Int = 2) async throws -> UIImage {
        let key = url as NSURL

        if let cached = cache.object(forKey: key) {
            return cached
        }

        if let existing = inFlightTasks[key] {
            return try await existing.value
        }

        let task = Task { () throws -> UIImage in
            var attempts = 0
            var delay: UInt64 = 300_000_000 // 0.3s
            while true {
                do {
                    let (data, response) = try await session.data(from: url)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                          let image = UIImage(data: data) else {
                        throw URLError(.badServerResponse)
                    }
                    cache.setObject(image, forKey: key, cost: data.count)
                    return image
                } catch let error as URLError where error.code == .networkConnectionLost || error.code == .timedOut {
                    if attempts < retries {
                        try await Task.sleep(nanoseconds: delay)
                        attempts += 1
                        delay = min(delay * 2, 2_000_000_000)
                        continue
                    } else {
                        throw error
                    }
                } catch {
                    throw error
                }
            }
        }

        inFlightTasks[key] = task
        defer { inFlightTasks[key] = nil }
        return try await task.value
    }
}
