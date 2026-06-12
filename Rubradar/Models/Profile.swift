//
//  Profile.swift
//  Rubradar
//

import Foundation
import SwiftData
import SwiftUI

/// A group of subscriptions the user switches between (e.g. Personal, Business).
/// Stored on-device via SwiftData and mirrored through CloudKit. Designed as the
/// unit we later share with others (CKShare), so it owns its subscriptions.
@Model
final class Profile {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "person.crop.circle.fill"
    var colorHex: String?
    /// Display order in the switcher / management list.
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    /// Owned subscriptions. Optional + nullify keeps it CloudKit-compatible; the
    /// management UI reassigns members before deleting a profile, never orphaning.
    @Relationship(deleteRule: .nullify, inverse: \Subscription.profile)
    var subscriptions: [Subscription]?

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "person.crop.circle.fill",
        colorHex: String? = nil,
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}

extension Profile {
    /// Tint from the stored hex, falling back to the app accent.
    var displayTint: Color { colorHex.flatMap(Color.init(hex:)) ?? .accentColor }

    /// Count of non-cancelled members, for management-list subtitles.
    var activeCount: Int { (subscriptions ?? []).filter { !$0.isCancelled }.count }

    /// Curated icons offered in the profile editor.
    static let symbolChoices = [
        "person.crop.circle.fill", "briefcase.fill", "house.fill", "person.2.fill",
        "creditcard.fill", "star.fill", "heart.fill", "gamecontroller.fill",
        "graduationcap.fill", "airplane", "cart.fill", "building.2.fill"
    ]

    /// Curated colour swatches (hex) offered in the profile editor.
    static let colorChoices = [
        "30B0A6", "0A84FF", "5E5CE6", "BF5AF2", "FF375F",
        "FF453A", "FF9F0A", "32D74B", "8E8E93"
    ]

    /// VoiceOver names for `symbolChoices` — SF Symbol identifiers aren't speakable.
    static func symbolLabel(for symbol: String) -> String {
        [
            "person.crop.circle.fill": "Person", "briefcase.fill": "Briefcase",
            "house.fill": "House", "person.2.fill": "Two people",
            "creditcard.fill": "Credit card", "star.fill": "Star",
            "heart.fill": "Heart", "gamecontroller.fill": "Game controller",
            "graduationcap.fill": "Graduation cap", "airplane": "Airplane",
            "cart.fill": "Shopping cart", "building.2.fill": "Buildings"
        ][symbol] ?? symbol
    }

    /// VoiceOver names for `colorChoices` — a bare hex value is meaningless spoken.
    static func colorLabel(for hex: String) -> String {
        [
            "30B0A6": "Teal", "0A84FF": "Blue", "5E5CE6": "Indigo",
            "BF5AF2": "Purple", "FF375F": "Pink", "FF453A": "Red",
            "FF9F0A": "Orange", "32D74B": "Green", "8E8E93": "Grey"
        ][hex] ?? "Custom colour"
    }
}

extension Subscription {
    /// Whether this subscription belongs to the given profile selection.
    /// An empty `selectedID` means "All Profiles".
    func belongsToProfile(id selectedID: String) -> Bool {
        selectedID.isEmpty || profile?.id.uuidString == selectedID
    }
}
