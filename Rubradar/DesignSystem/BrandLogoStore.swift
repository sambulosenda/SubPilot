//
//  BrandLogoStore.swift
//  Rubradar
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// Fetches real brand logos from logo.dev by domain, with an in-memory cache,
/// on-disk HTTP caching, and in-flight de-duplication. Returns `nil` on a miss
/// or when offline so callers fall back to an SF Symbol.
///
/// logo.dev publishable tokens are designed to ship in the client (like a Stripe
/// publishable key), so embedding the token here is expected and safe.
actor BrandLogoStore {
    static let shared = BrandLogoStore()

    /// 👉 Paste your logo.dev publishable token here (starts with "pk_").
    /// Get one free at https://logo.dev. Until it's set, logos fall back to
    /// SF Symbols and no network requests are made.
    private static let token = "pk_ZDahB2dURZ2q18KZ6Ws17Q"

    /// A single crisp size requested for every brand, shared across all chip
    /// sizes (36–56pt) so the cache holds one entry per domain.
    private static let pixelSize = 256

    private let session: URLSession
    private let memory = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 8 << 20, diskCapacity: 64 << 20)
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    /// True once a real token has been configured.
    var isConfigured: Bool { Self.token != "pk_REPLACE_ME" }

    /// The logo for `domain`, or `nil` if unconfigured / not found / offline.
    func image(for domain: String) async -> UIImage? {
        let key = domain.lowercased()
        guard isConfigured, !key.isEmpty else { return nil }

        if let cached = memory.object(forKey: key as NSString) { return cached }
        if let task = inFlight[key] { return await task.value }

        let task = Task<UIImage?, Never> { [session] in
            guard var components = URLComponents(string: "https://img.logo.dev/\(key)") else { return nil }
            components.queryItems = [
                URLQueryItem(name: "token", value: Self.token),
                URLQueryItem(name: "size", value: String(Self.pixelSize)),
                URLQueryItem(name: "format", value: "png"),
            ]
            guard let url = components.url,
                  let (data, response) = try? await session.data(from: url),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let image = UIImage(data: data)
            else { return nil }
            // Decode the bitmap off the main thread so first draw in a list row
            // doesn't hitch; falls back to the lazily-decoded image if it fails.
            return await image.byPreparingForDisplay() ?? image
        }

        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { memory.setObject(image, forKey: key as NSString) }
        return image
    }
}
#endif
