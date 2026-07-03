//
//  CancelGuideTests.swift
//  RubradarTests
//

import Testing
import Foundation
@testable import Rubradar

struct CancelGuideTests {
    private func provider(id: String, name: String, domain: String?,
                          cancelURL: String?) -> CatalogueProvider {
        CatalogueProvider(id: id, name: name, category: .streaming,
                          symbolName: "play.tv.fill", logoAssetName: nil,
                          defaultCycle: .monthly, brandColorHex: nil,
                          domain: domain, cancelURL: cancelURL)
    }

    private var netflix: CatalogueProvider {
        provider(id: "netflix", name: "Netflix", domain: "netflix.com",
                 cancelURL: "https://www.netflix.com/cancelplan")
    }

    @Test func curatedURLWinsViaCatalogueID() {
        let sub = Subscription(name: "Netflix", amount: 9.99, catalogueID: "netflix")
        let guide = CancelGuide.make(for: sub, providers: [netflix])
        #expect(guide.isDirect)
        #expect(guide.providerURL?.absoluteString == "https://www.netflix.com/cancelplan")
        #expect(!guide.isAppleBilled)
    }

    @Test func nameMatchFallsBackToCuratedURL() {
        // Manually-typed sub with no catalogue link still gets the curated page.
        let sub = Subscription(name: "My Netflix", amount: 9.99)
        let guide = CancelGuide.make(for: sub, providers: [netflix])
        #expect(guide.isDirect)
        #expect(guide.providerURL?.absoluteString == "https://www.netflix.com/cancelplan")
    }

    @Test func fallsBackToBrandDomainWithoutCuratedURL() {
        let bare = provider(id: "acme", name: "Acme", domain: "acme.com", cancelURL: nil)
        let sub = Subscription(name: "Acme", amount: 5, catalogueID: "acme", brandDomain: "acme.com")
        let guide = CancelGuide.make(for: sub, providers: [bare])
        #expect(!guide.isDirect)
        #expect(guide.providerURL?.absoluteString == "https://acme.com")
    }

    @Test func userLinkBeatsNothing() {
        let sub = Subscription(name: "Tiny SaaS", amount: 3, linkURL: "https://tiny.example/account")
        let guide = CancelGuide.make(for: sub, providers: [])
        #expect(!guide.isDirect)
        #expect(guide.providerURL?.absoluteString == "https://tiny.example/account")
    }

    @Test func unknownProviderHasNoURL() {
        let sub = Subscription(name: "Mystery Box", amount: 3)
        let guide = CancelGuide.make(for: sub, providers: [])
        #expect(guide.providerURL == nil)
        #expect(!guide.isDirect)
    }

    @Test func appleServicesRouteThroughAppleSubscriptions() {
        let appleTV = provider(id: "apple-tv-plus", name: "Apple TV+", domain: "apple.com",
                               cancelURL: "https://apps.apple.com/account/subscriptions")
        let sub = Subscription(name: "Apple TV+", amount: 8.99, catalogueID: "apple-tv-plus")
        let guide = CancelGuide.make(for: sub, providers: [appleTV])
        #expect(guide.isAppleBilled)
    }

    @Test func bundledCatalogueDecodesCancelURLs() {
        // The shipping catalogue must round-trip the new optional field and
        // keep the curated Netflix entry. `.main` is the host app bundle in
        // these hosted tests (same pattern as the detector tests).
        let all = CatalogueLoader.load()
        let netflix = all.first { $0.id == "netflix" }
        #expect(netflix?.cancelURL == "https://www.netflix.com/cancelplan")
    }
}
