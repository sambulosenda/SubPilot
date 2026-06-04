//
//  ProfileSetup.swift
//  Rubradar
//

import Foundation
import SwiftData

/// First-run / migration glue for profiles. Idempotent — safe to call on every
/// launch. Guarantees at least one profile exists and that no subscription is
/// left without one (existing data predates the profile relationship).
@MainActor
enum ProfileSetup {
    static func ensureDefault(in context: ModelContext) {
        let profiles = (try? context.fetch(FetchDescriptor<Profile>())) ?? []
        let fallback: Profile
        if let first = profiles.sorted(by: { $0.sortIndex < $1.sortIndex }).first {
            fallback = first
        } else {
            fallback = Profile(name: "Personal", symbolName: "person.crop.circle.fill", sortIndex: 0)
            context.insert(fallback)
        }

        let subs = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        for sub in subs where sub.profile == nil {
            sub.profile = fallback
        }

        if context.hasChanges { try? context.save() }
    }
}
