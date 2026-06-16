//
//  Theme.swift
//  Rubradar
//

import SwiftUI

/// Spacing scale used across the app.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Corner radii.
enum Radius {
    static let chip: CGFloat = 10
    static let card: CGFloat = 16
}

extension Color {
    static let appBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    /// Brand teal and a deeper shade for gradients (e.g. the shareable recap
    /// card). Falls back to the asset accent if the hex ever fails to parse.
    static let brand = Color(hex: "0D9488") ?? .accentColor
    static let brandDeep = Color(hex: "0B6E66") ?? .accentColor
}
