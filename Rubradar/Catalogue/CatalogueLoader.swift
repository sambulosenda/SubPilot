//
//  CatalogueLoader.swift
//  Rubradar
//

import Foundation

/// Loads the bundled provider catalogue. Remote refresh is a later milestone.
enum CatalogueLoader {
    private struct CatalogueFile: Codable {
        let version: Int
        let providers: [CatalogueProvider]
    }

    static func load(bundle: Bundle = .main) -> [CatalogueProvider] {
        guard let url = bundle.url(forResource: "catalogue", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CatalogueFile.self, from: data)
        else {
            return []
        }
        return file.providers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
