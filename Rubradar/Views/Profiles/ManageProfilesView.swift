//
//  ManageProfilesView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// Create, rename, reorder, recolour, and delete profiles. Deleting reassigns the
/// profile's subscriptions to the first remaining profile (never orphans them) and
/// is blocked for the last profile. Hosts no `NavigationStack` of its own so it can
/// be pushed inside Settings or presented in a sheet's stack.
struct ManageProfilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchases
    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]
    @State private var editorTarget: ProfileEditorTarget?
    @State private var showPaywall = false

    var body: some View {
        List {
            Section {
                ForEach(profiles) { profile in
                    Button {
                        editorTarget = .edit(profile)
                    } label: {
                        ProfileRow(profile: profile)
                    }
                    .tint(.primary)
                }
                .onMove(perform: move)
                .onDelete { offsets in
                    guard profiles.count > 1 else { return }
                    delete(offsets)
                }
            } footer: {
                Text("Deleting a profile moves its subscriptions to the first remaining profile.")
            }
        }
        .navigationTitle("Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(item: $editorTarget) { target in
            ProfileEditorView(target: target)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .profiles)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { EditButton() }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add Profile", systemImage: "plus") {
                if PurchaseGate.canAddProfile(currentCount: profiles.count, isPro: purchases.isPro) {
                    editorTarget = .create
                } else {
                    showPaywall = true
                }
            }
        }
    }

    private func move(_ offsets: IndexSet, to destination: Int) {
        var ordered = profiles
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, profile) in ordered.enumerated() { profile.sortIndex = index }
        try? modelContext.save()
    }

    private func delete(_ offsets: IndexSet) {
        guard profiles.count > 1 else { return }
        for index in offsets {
            let profile = profiles[index]
            let target = profiles.first { $0.id != profile.id }
            for sub in (profile.subscriptions ?? []) { sub.profile = target }
            modelContext.delete(profile)
        }
        try? modelContext.save()
    }
}

private struct ProfileRow: View {
    let profile: Profile

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: profile.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(profile.displayTint, in: .circle)
                // Keep the symbol's auto-derived name out of the combined row label.
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                Text("\(profile.activeCount) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Editor

enum ProfileEditorTarget: Identifiable {
    case create
    case edit(Profile)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let profile): profile.id.uuidString
        }
    }
}

/// Add / edit a profile: name, icon, colour. Wrapped in its own `NavigationStack`
/// because it's always shown as a sheet.
struct ProfileEditorView: View {
    let target: ProfileEditorTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Profile.sortIndex) private var profiles: [Profile]

    @State private var name: String
    @State private var symbolName: String
    @State private var colorHex: String

    init(target: ProfileEditorTarget) {
        self.target = target
        switch target {
        case .create:
            _name = State(initialValue: "")
            _symbolName = State(initialValue: Profile.symbolChoices[0])
            _colorHex = State(initialValue: Profile.colorChoices[0])
        case .edit(let profile):
            _name = State(initialValue: profile.name)
            _symbolName = State(initialValue: profile.symbolName)
            _colorHex = State(initialValue: profile.colorHex ?? Profile.colorChoices[0])
        }
    }

    private var isEditing: Bool { if case .edit = target { return true }; return false }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var tint: Color { Color(hex: colorHex) ?? .accentColor }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(systemName: symbolName)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(tint, in: .circle)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .accessibilityHidden(true)
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: Spacing.md)], spacing: Spacing.md) {
                        ForEach(Profile.symbolChoices, id: \.self, content: iconButton)
                    }
                    .padding(.vertical, Spacing.xs)
                }

                Section("Colour") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: Spacing.md)], spacing: Spacing.md) {
                        ForEach(Profile.colorChoices, id: \.self, content: colorButton)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func iconButton(_ symbol: String) -> some View {
        let selected = symbol == symbolName
        return Button {
            symbolName = symbol
        } label: {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(selected ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(selected ? tint : Color.secondary.opacity(0.15), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Profile.symbolLabel(for: symbol))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func colorButton(_ hex: String) -> some View {
        let selected = hex == colorHex
        return Button {
            colorHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 36, height: 36)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(4)
                .overlay {
                    if selected { Circle().strokeBorder(Color(hex: hex) ?? .gray, lineWidth: 2) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Profile.colorLabel(for: hex))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func save() {
        switch target {
        case .create:
            let next = (profiles.map(\.sortIndex).max() ?? -1) + 1
            let profile = Profile(name: trimmedName, symbolName: symbolName, colorHex: colorHex, sortIndex: next)
            modelContext.insert(profile)
        case .edit(let profile):
            profile.name = trimmedName
            profile.symbolName = symbolName
            profile.colorHex = colorHex
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack { ManageProfilesView() }
        .modelContainer(.preview)
        .environment(PurchaseManager.preview(isPro: true))
}
