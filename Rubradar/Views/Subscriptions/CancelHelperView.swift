//
//  CancelHelperView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// Guided cancellation sheet: short generic steps, a button to the provider's
/// account/cancel page, the Apple-subscriptions route (billing may be through
/// the App Store — we can't know), and a closing "mark as cancelled" action so
/// the app's state ends up matching reality.
struct CancelHelperView: View {
    @Bindable var subscription: Subscription
    /// Called after the user confirms they cancelled; the host flips state,
    /// reschedules reminders, and refreshes the widget.
    var onMarkCancelled: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var guide: CancelGuide { CancelGuide.make(for: subscription) }

    var body: some View {
        NavigationStack {
            List {
                stepsSection
                routesSection
                doneSection
            }
            .navigationTitle("Cancel \(subscription.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                Analytics.cancelHelperOpened(direct: guide.isDirect)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var stepsSection: some View {
        Section {
            step(1, "Open your \(subscription.name) account settings.")
            step(2, "Find the subscription or membership section.")
            step(3, "Choose cancel and confirm — you usually keep access until the period ends.")
        } header: {
            Text("How it works")
        } footer: {
            Text("If you subscribed inside the iOS app, the charge goes through Apple — use the Apple subscriptions button below instead.")
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: .circle)
            Text(text)
        }
        .accessibilityElement(children: .combine)
    }

    private var routesSection: some View {
        Section {
            if !guide.isAppleBilled, let url = guide.providerURL {
                Button {
                    openURL(url)
                } label: {
                    Label(guide.isDirect ? "Open cancellation page" : "Open \(subscription.name)",
                          systemImage: "arrow.up.forward.app")
                }
            }
            Button {
                openURL(CancelGuide.appleSubscriptions)
            } label: {
                Label("Manage Apple subscriptions", systemImage: "apple.logo")
            }
        } footer: {
            if guide.isDirect && !guide.isAppleBilled {
                Text("Takes you straight to \(subscription.name)'s account page.")
            }
        }
    }

    private var doneSection: some View {
        Section {
            Button {
                onMarkCancelled()
                dismiss()
            } label: {
                Label("Done — mark as cancelled", systemImage: "checkmark.circle.fill")
            }
        } footer: {
            Text("Stops renewal reminders for this subscription. You can mark it active again any time.")
        }
    }
}

#Preview {
    CancelHelperView(subscription: SampleData.makeSamples()[0], onMarkCancelled: {})
        .modelContainer(.preview)
}
