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

    /// One palette of matched weight rather than the raw system colours, which
    /// sat at different saturations and made the Insights donut read as three
    /// unrelated apps next to the brand teal. Each stays a distinct hue so
    /// neighbouring slices never blur together. Two shades per category: the
    /// tint is also used as text on the form's category chips, and the bright
    /// shades that glow on a dark card wash out on a white one.
    var tint: Color {
        switch self {
        case .streaming: Self.adaptive(light: 0xE5484D, dark: 0xFF6B6B)
        case .music: Self.adaptive(light: 0x059669, dark: 0x34D399)
        case .software: Self.adaptive(light: 0x2563EB, dark: 0x60A5FA)
        case .gaming: Self.adaptive(light: 0x7C3AED, dark: 0xA78BFA)
        case .news: Self.adaptive(light: 0xD97706, dark: 0xFBBF24)
        case .fitness: Self.adaptive(light: 0x65A30D, dark: 0xA3E635)
        case .cloud: Self.adaptive(light: 0x0284C7, dark: 0x38BDF8)
        case .utilities: Self.adaptive(light: 0x64748B, dark: 0x94A3B8)
        case .finance: Self.adaptive(light: 0x4F46E5, dark: 0x818CF8)
        case .education: Self.adaptive(light: 0xEA580C, dark: 0xFB923C)
        case .food: Self.adaptive(light: 0xDB2777, dark: 0xF472B6)
        case .other: Self.adaptive(light: 0x475569, dark: 0x94A3B8)
        }
    }

    /// Built here from RGB rather than the app's `Color(hex:)`: this file is
    /// also compiled into the widget, which doesn't have that initialiser.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        func color(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) })
    }
}
