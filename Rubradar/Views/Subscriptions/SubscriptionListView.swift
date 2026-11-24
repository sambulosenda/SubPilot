//
//  SubscriptionListView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable, Identifiable {
    case nextRenewal, name, amount, category
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nextRenewal: String(localized: "Next renewal")
        case .name: String(localized: "Name")
        case .amount: String(localized: "Amount")
        case .category: String(localized: "Category")
        }
    }
    var symbol: String {
        switch self {
        case .nextRenewal: "calendar"
        case .name: "textformat"
        case .amount: "banknote"   // currency-neutral, unlike sterlingsign
        case .category: "square.grid.2x2"
        }
    }
}

/// The Home screen: a spend dashboard above the list of tracked subscriptions.
struct SubscriptionListView: View {
    /// Requests the parent shell to present an add flow.
    var presentAdd: (AddSheet) -> Void
    /// Asks the shell to switch to the Calendar tab ("View all").
    var onViewAllRenewals: () -> Void = {}

    @Query(animation: .default) private var subscriptions: [Subscription]
    @Query(sort: \Profile.sortIndex, animation: .default) private var profiles: [Profile]
    @Environment(CurrencyService.self) private var currency
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.openURL) private var openURL
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    /// Selected profile's UUID string; empty means "All Profiles".
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    /// Persisted — resetting to "next renewal" every launch reads as a bug to
    /// users who sort by amount.
    @AppStorage("subscriptionSortOption") private var sortOption: SortOption = .nextRenewal
    @State private var searchText = ""
    @State private var showManageProfiles = false
    @State private var showAssistant = false
    /// `dismissToken`s of attention items the user chose to keep
    /// (comma-joined), so they stop asking for a decision.
    @AppStorage("keptAttentionTokens") private var keptAttentionRaw = ""
    /// `UsageCheckIn.monthKey` of the month the check-in was last done (or
    /// skipped) in.
    @AppStorage("lastUsageCheckInMonth") private var lastUsageCheckInMonth = ""
    @State private var showUsageCheckIn = false
    /// One typed path for every push from Home. The cut list used to be a
    /// separate `navigationDestination(isPresented:)`; opening a subscription
    /// from it rewrote this path and popped both screens straight back.
    @State private var path = NavigationPath()
    /// Shared namespace so a tapped row zooms into its detail screen and back.
    @Namespace private var detailTransition

    /// Subscriptions in the selected profile ("" = All), before search/cancel
    /// filtering. Drives the dashboard totals so they scope to the profile.
    private var profileSubscriptions: [Subscription] {
        subscriptions.filter { $0.belongsToProfile(id: selectedProfileID) }
    }

    private var metrics: HomeMetrics {
        HomeMetrics.make(from: profileSubscriptions, preferred: preferredCurrency, rates: currency.rates)
    }

    private var keptAttentionTokens: Set<String> {
        Set(keptAttentionRaw.split(separator: ",").map(String.init))
    }

    private func keep(_ token: String) {
        // Carry over only tokens that could still be flagged, so this never
        // grows past the handful of items inside their windows.
        let live = Set(AttentionRadar.items(in: subscriptions).compactMap(\.dismissToken))
        let kept = keptAttentionTokens.intersection(live).union([token])
        withAnimation {
            keptAttentionRaw = kept.sorted().joined(separator: ",")
        }
    }

    private var visibleSubscriptions: [Subscription] {
        let filtered = profileSubscriptions.filter { sub in
            if searchText.isEmpty {
                return !sub.isCancelled // Home lists active subscriptions only.
            }
            // Search spans the profile, so cancelled subs stay reachable to reopen.
            return sub.name.localizedCaseInsensitiveContains(searchText)
                || sub.category.label.localizedCaseInsensitiveContains(searchText)
        }
        return sorted(filtered)
    }

    private func sorted(_ subs: [Subscription]) -> [Subscription] {
        switch sortOption {
        case .nextRenewal:
            // Decorate-sort-undecorate: projecting the next renewal walks the
            // calendar, so compute it once per row — not once per comparison
            // on every body evaluation (this re-sorts on each search keystroke).
            return subs.map { (sub: $0, next: $0.projectedNextRenewal()) }
                .sorted { $0.next < $1.next }
                .map(\.sub)
        case .name:
            return subs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .amount:
            return subs.sorted { $0.monthlyEquivalent > $1.monthlyEquivalent }
        case .category:
            return subs.sorted { $0.category.label.localizedCaseInsensitiveCompare($1.category.label) == .orderedAscending }
        }
    }

    /// "Up next" only reads true when the default next-renewal order is in effect.
    private var listSectionTitle: LocalizedStringKey {
        sortOption == .nextRenewal && searchText.isEmpty ? "Up next" : "Your subscriptions"
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if subscriptions.isEmpty {
                    SubscriptionsEmptyState(
                        onScan: { presentAdd(.scan) },
                        onBrowseCatalogue: { presentAdd(.catalogue) },
                        onImportStatement: { presentAdd(.bankImport) },
                        onAddManually: { presentAdd(.manual) }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("")
            // No large title: the "Up next" / empty-state headline owns the screen,
            // so we keep the bar inline rather than stranding a title above the content.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showUsageCheckIn) {
                let candidates = sorted(UsageCheckIn.candidates(in: profileSubscriptions))
                UsageCheckInView(subscriptions: candidates,
                                 month: UsageCheckIn.reviewedMonth()) { unused in
                    if let unused {
                        UsageCheckIn.record(unused: unused, among: candidates)
                    }
                    withAnimation { lastUsageCheckInMonth = UsageCheckIn.monthKey(for: Date()) }
                }
            }
            .sheet(isPresented: $showAssistant) {
                AssistantView(showsClose: true, onOpen: { sub in
                    // Close the chat, then land on the subscription it named.
                    showAssistant = false
                    path = NavigationPath([sub])
                })
            }
            .sheet(isPresented: $showManageProfiles) {
                NavigationStack { ManageProfilesView() }
            }
            .onChange(of: profiles.map(\.id)) {
                // A deleted selected profile would otherwise filter to nothing.
                if !selectedProfileID.isEmpty,
                   !profiles.contains(where: { $0.id.uuidString == selectedProfileID }) {
                    selectedProfileID = ""
                }
            }
            #if DEBUG
            // `-StartRoute <name>` pushes the named subscription's detail screen
            // on launch so screenshots of pushed screens need no UI taps (pairs
            // with `-DemoSeed`/`-StartTab`).
            .task {
                let args = ProcessInfo.processInfo.arguments
                guard let i = args.firstIndex(of: "-StartRoute"), i + 1 < args.count,
                      let sub = subscriptions.first(where: {
                          $0.name.localizedCaseInsensitiveContains(args[i + 1])
                      }) else { return }
                path = NavigationPath([sub])
            }
            // `-StartTab assistant` predates the assistant leaving the tab bar;
            // keep it working for the screenshot scripts.
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-StartTab"), i + 1 < args.count, args[i + 1] == "assistant" {
                    showAssistant = true
                }
            }
            #endif
        }
    }

    private var list: some View {
        // Filter+sort once per body pass; reused by the rows and the empty overlay.
        let attention = searchText.isEmpty
            ? AttentionRadar.items(in: profileSubscriptions, dismissed: keptAttentionTokens)
            : []
        // "Up next" skips whatever "Needs attention" already shows right
        // above it. Any other sort is the full inventory, so nothing is
        // left out there.
        let flagged = sortOption == .nextRenewal ? Set(attention.map(\.subscription.id)) : []
        let visible = visibleSubscriptions.filter { !flagged.contains($0.id) }
        let metrics = metrics
        return List {
            if searchText.isEmpty {
                Section {
                    DashboardHeader(metrics: metrics, onOpenCut: { path.append(CutListRoute()) })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if UsageCheckIn.isDue(lastDoneMonthKey: lastUsageCheckInMonth,
                                      subscriptions: profileSubscriptions) {
                    Section {
                        Button { showUsageCheckIn = true } label: {
                            UsageCheckInRow(month: UsageCheckIn.reviewedMonth())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !attention.isEmpty {
                    AttentionSection(items: attention, onKeep: keep)
                }

                if metrics.nextEvent != nil {
                    Section {
                        DashboardStrip(metrics: metrics, onOpenCalendar: onViewAllRenewals)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }

            if !visible.isEmpty {
                Section {
                    ForEach(visible) { sub in
                        NavigationLink(value: sub) {
                            SubscriptionRow(subscription: sub)
                        }
                        .matchedTransitionSource(id: sub.id, in: detailTransition)
                        .contextMenu {
                            if let url = sub.providerURL {
                                Button {
                                    openURL(url)
                                } label: {
                                    Label("Open \(sub.name)", systemImage: "arrow.up.forward.app")
                                }
                            }
                        }
                    }
                } header: {
                    sectionHeader
                }
            }
        }
        .navigationDestination(for: Subscription.self) { sub in
            SubscriptionDetailView(subscription: sub,
                                   transitionID: sub.id,
                                   transitionNamespace: detailTransition)
        }
        .navigationDestination(for: CutListRoute.self) { _ in
            CutListView(subscriptions: sorted(profileSubscriptions.filter(\.isCancelled)),
                        summary: metrics.cut)
        }
        // Keeping an attention item answers its question; confirm the tap.
        .sensoryFeedback(.selection, trigger: keptAttentionRaw)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .searchable(text: $searchText, prompt: "Search subscriptions")
        .searchToolbarBehavior(.minimize)
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            if !searchText.isEmpty && visible.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    /// The list's title doubles as its sort control, where the thing it
    /// changes is. Sort used to live in a "…" menu in the toolbar, two taps
    /// from the list and one more button in an already full bar.
    private var sectionHeader: some View {
        HStack {
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Label(option.label, systemImage: option.symbol).tag(option)
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(listSectionTitle)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 13)
                .contentShape(.rect)
                .padding(.vertical, -13)
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Sort by")
            .accessibilityValue(sortOption.label)
            Spacer()
            // Named for where it goes. It was "View all", which promised the
            // full list and opened the Calendar tab.
            Button("Calendar") { onViewAllRenewals() }
                .font(.subheadline.weight(.semibold))
                // The text is ~18pt tall; pad the tappable area out to 44
                // without letting it push the header's layout.
                .padding(.vertical, 13)
                .padding(.leading, Spacing.md)
                .contentShape(.rect)
                .padding(.vertical, -13)
        }
        .textCase(nil)
    }

    private var currentProfileName: String {
        guard !selectedProfileID.isEmpty,
              let profile = profiles.first(where: { $0.id.uuidString == selectedProfileID })
        else { return "All Profiles" }
        return profile.name
    }

    private var profileMenu: some View {
        Menu {
            Picker("Profile", selection: $selectedProfileID) {
                Label("All Profiles", systemImage: "square.stack.3d.up.fill").tag("")
                ForEach(profiles) { profile in
                    Label(profile.name, systemImage: profile.symbolName).tag(profile.id.uuidString)
                }
            }
            Divider()
            Button("Manage Profiles…", systemImage: "slider.horizontal.3") {
                showManageProfiles = true
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(currentProfileName).fontWeight(.semibold)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
        }
        .accessibilityLabel("Profile: \(currentProfileName)")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Three controls at most. The profile switcher shows only once there
        // is a second profile to switch to (profiles are still managed in
        // Settings); the Assistant has its own button instead of hiding in a
        // "…" menu; Sort moved to the list's header.
        if !subscriptions.isEmpty {
            if profiles.count > 1 {
                ToolbarItem(placement: .topBarLeading) { profileMenu }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Assistant", systemImage: "sparkles") { openAssistant() }
            }
        }
        ToolbarItem(placement: .topBarTrailing) { addMenu }
    }

    /// Primary action: one tap opens the add screen (the searchable catalogue,
    /// with manual, scan and import offered at the top).
    private var addMenu: some View {
        Button { presentAdd(.catalogue) } label: {
            Label("Add subscription", systemImage: "plus")
        }
    }

    /// The assistant is Pro-only. A free user goes straight to the paywall:
    /// it is presented by the app shell, which can't show a sheet over one
    /// already up from here, so the locked screen's own "Unlock" would do
    /// nothing inside our sheet.
    private func openAssistant() {
        if purchases.isPro {
            showAssistant = true
        } else {
            purchases.paywallContext = .assistant
        }
    }
}

#Preview {
    SubscriptionListView(presentAdd: { _ in })
        .modelContainer(.preview)
        .environment(CurrencyService())
}

/// Route value for Home's "What you've cut" screen, so it shares the typed
/// navigation path with the subscription detail pushes.
private struct CutListRoute: Hashable {}
