//
//  ProfileTests.swift
//  RubradarTests
//

import Testing
import Foundation
import SwiftData
@testable import Rubradar

@MainActor
struct ProfileTests {
    /// In-memory container with CloudKit disabled, for deterministic tests.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Subscription.self, Profile.self, PriceChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    @Test func ensureDefaultCreatesPersonalAndAdoptsOrphans() throws {
        let context = try makeContext()
        context.insert(Subscription(name: "Netflix"))
        context.insert(Subscription(name: "Spotify"))

        ProfileSetup.ensureDefault(in: context)

        let profiles = try context.fetch(FetchDescriptor<Profile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.name == "Personal")

        let subs = try context.fetch(FetchDescriptor<Subscription>())
        #expect(subs.allSatisfy { $0.profile != nil })
        #expect(subs.allSatisfy { $0.profile?.name == "Personal" })
    }

    @Test func ensureDefaultIsIdempotent() throws {
        let context = try makeContext()
        ProfileSetup.ensureDefault(in: context)
        ProfileSetup.ensureDefault(in: context)

        let profiles = try context.fetch(FetchDescriptor<Profile>())
        #expect(profiles.count == 1) // no duplicate "Personal"
    }

    @Test func ensureDefaultLeavesExistingAssignmentsAlone() throws {
        let context = try makeContext()
        let work = Profile(name: "Business", sortIndex: 0)
        context.insert(work)
        let sub = Subscription(name: "Figma")
        context.insert(sub)
        sub.profile = work

        ProfileSetup.ensureDefault(in: context)

        #expect(sub.profile?.name == "Business") // not reassigned
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        #expect(profiles.count == 1) // Business already covers the fallback
    }

    @Test func belongsToProfileFilters() throws {
        let context = try makeContext()
        let personal = Profile(name: "Personal")
        let business = Profile(name: "Business")
        context.insert(personal)
        context.insert(business)
        let sub = Subscription(name: "Slack")
        context.insert(sub)
        sub.profile = business

        #expect(sub.belongsToProfile(id: "")) // "All" matches everything
        #expect(sub.belongsToProfile(id: business.id.uuidString))
        #expect(!sub.belongsToProfile(id: personal.id.uuidString))
    }
}
