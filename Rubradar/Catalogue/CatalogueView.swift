//
//  CatalogueView.swift
//  Rubradar
//

import SwiftUI
import SwiftData
import StoreKit
import UIKit

/// Searchable catalogue of common providers. Tapping one opens the quick-add
/// sheet, pre-filled with the provider's typical price (FR-01).
struct CatalogueView: View {
    /// When set, tapping a provider hands it back to the caller (to fill an open
    /// form) instead of presenting a fresh pre-filled form. `nil` = standalone.
    var onSelect: ((CatalogueProvider) -> Void)?
    /// Set when this is the app's add screen: the other ways to add (manual,
    /// scan, bank import) are offered above the list and reported here. `nil`
    /// hides them, e.g. when the catalogue is filling an already-open form.
    var onOtherFlow: ((AddSheet) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.openURL) private var openURL

    @State private var providers: [CatalogueProvider] = []
    @State private var searchText = ""
    @State private var quickAdd: CatalogueProvider?

    private var grouped: [(category: SubscriptionCategory, items: [CatalogueProvider])] {
        let filtered = providers.filter { provider in
            searchText.isEmpty
                || provider.name.localizedCaseInsensitiveContains(searchText)
                || provider.category.label.localizedCaseInsensitiveContains(searchText)
        }
        let byCategory = Dictionary(grouping: filtered, by: \.category)
        return SubscriptionCategory.allCases.compactMap { category in
            guard let items = byCategory[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // One screen to add from: search the catalogue, or take one of
                // the other routes. This replaces a chooser sheet that sat in
                // front of every add. Hidden while searching, so results lead.
                if let onOtherFlow, searchText.isEmpty {
                    Section {
                        otherFlow("Add manually", symbol: "square.and.pencil", pro: false) {
                            onOtherFlow(.manual)
                        }
                        otherFlow("Scan a receipt", symbol: "doc.viewfinder", pro: true) {
                            onOtherFlow(.scan)
                        }
                        otherFlow("Import bank statement", symbol: "doc.badge.arrow.up", pro: true) {
                            onOtherFlow(.bankImport)
                        }
                    }
                    // Lived in Settings, where nobody adding a subscription
                    // would look. It's a way to find what to add, so it sits
                    // with the other ways to add.
                    Section {
                        otherFlow("App Store Subscriptions", symbol: "list.bullet.rectangle.portrait", pro: false) {
                            Task { await openAppStoreSubscriptions() }
                        }
                    } footer: {
                        Text("Open Apple's subscription list to see what you pay for through the App Store, then add them here. Apple doesn't let apps import this list automatically.")
                    }
                }
                ForEach(grouped, id: \.category) { section in
                    Section(section.category.label) {
                        ForEach(section.items) { provider in
                            Button {
                                if let onSelect {
                                    onSelect(provider)
                                    dismiss()
                                } else {
                                    quickAdd = provider
                                }
                            } label: {
                                row(provider)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle(onOtherFlow == nil ? "Catalogue" : "Add a subscription")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search providers")
            .overlay {
                if !searchText.isEmpty && grouped.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $quickAdd) { provider in
                QuickAddSheet(provider: provider, onSaved: { dismiss() })
            }
        }
        .task {
            if providers.isEmpty { providers = CatalogueLoader.load() }
        }
    }

    /// Opens Apple's system subscription-management sheet (all the user's App
    /// Store subscriptions). Apple exposes no API to read this list, so we can
    /// only surface it for the user to view; falls back to the account URL.
    private func openAppStoreSubscriptions() async {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
                return
            } catch {
                // Fall through to the deep link below.
            }
        }
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            openURL(url)
        }
    }

    private func otherFlow(_ title: LocalizedStringKey, symbol: String, pro: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.tint)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                Text(title)
                Spacer()
                // Only while it applies: a subscriber shouldn't be sold what
                // they already have.
                if pro && !purchases.isPro { ProBadge() }
            }
        }
        .tint(.primary)
    }

    private func row(_ provider: CatalogueProvider) -> some View {
        HStack(spacing: Spacing.md) {
            BrandLogoView(
                symbolName: provider.symbolName,
                logoAssetName: provider.logoAssetName,
                brandDomain: provider.domain,
                tint: Color(hex: provider.brandColorHex ?? "") ?? provider.category.tint,
                category: provider.category,
                size: 36
            )
            Text(provider.name)
            Spacer()
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    CatalogueView(onOtherFlow: { _ in })
        .modelContainer(.preview)
        .environment(PurchaseManager.preview(isPro: false))
}
