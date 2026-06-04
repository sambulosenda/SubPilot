//
//  CatalogueView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// Searchable catalogue of common providers. Tapping one opens a pre-filled
/// add form (FR-01).
struct CatalogueView: View {
    /// When set, tapping a provider hands it back to the caller (to fill an open
    /// form) instead of presenting a fresh pre-filled form. `nil` = standalone.
    var onSelect: ((CatalogueProvider) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var providers: [CatalogueProvider] = []
    @State private var searchText = ""
    @State private var draft: Subscription?

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
                ForEach(grouped, id: \.category) { section in
                    Section(section.category.label) {
                        ForEach(section.items) { provider in
                            Button {
                                if let onSelect {
                                    onSelect(provider)
                                    dismiss()
                                } else {
                                    draft = provider.makeDraft()
                                }
                            } label: {
                                row(provider)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Catalogue")
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
            .sheet(item: $draft) { draft in
                SubscriptionFormView(mode: .create(draft), onSaved: { dismiss() })
            }
        }
        .onAppear {
            if providers.isEmpty { providers = CatalogueLoader.load() }
        }
    }

    private func row(_ provider: CatalogueProvider) -> some View {
        HStack(spacing: Spacing.md) {
            BrandLogoView(
                symbolName: provider.symbolName,
                logoAssetName: provider.logoAssetName,
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
    CatalogueView()
        .modelContainer(.preview)
}
