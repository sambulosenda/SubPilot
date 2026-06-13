//
//  Category.swift
//  Rubradar
//

import SwiftUI

/// Built-in subscription categories. String-backed for stable persistence.
/// User-defined categories are deferred to a later milestone.
/// Named `SubscriptionCategory` to avoid colliding with the global `Category` type.
enum SubscriptionCategory: String, CaseIterable, Identifiable, Codable {
    case streaming
    case music
    case software
    case gaming
    case news
    case fitness
    case cloud
    case utilities
    case finance
    case education
    case food
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .streaming: String(localized: "Streaming")
        case .music: String(localized: "Music")
        case .software: String(localized: "Software")
        case .gaming: String(localized: "Gaming")
        case .news: String(localized: "News")
        case .fitness: String(localized: "Fitness")
        case .cloud: String(localized: "Cloud & Storage")
        case .utilities: String(localized: "Utilities")
        case .finance: String(localized: "Finance")
        case .education: String(localized: "Education")
        case .food: String(localized: "Food & Drink")
        case .other: String(localized: "Other")
        }
    }

    var defaultSymbol: String {
        switch self {
        case .streaming: "play.tv.fill"
        case .music: "music.note"
        case .software: "app.badge.fill"
        case .gaming: "gamecontroller.fill"
        case .news: "newspaper.fill"
        case .fitness: "figure.run"
        case .cloud: "icloud.fill"
        case .utilities: "wrench.and.screwdriver.fill"
        case .finance: "sterlingsign.circle.fill"
        case .education: "graduationcap.fill"
        case .food: "fork.knife"
        case .other: "square.grid.2x2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .streaming: .red
        case .music: .green
        case .software: .blue
        case .gaming: .purple
        case .news: .orange
        case .fitness: .mint
        case .cloud: .cyan
        case .utilities: .gray
        case .finance: .indigo
        case .education: .teal
        case .food: .pink
        case .other: .secondary
        }
    }
}
