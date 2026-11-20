//
//  TrialEndingAttributes.swift
//  Rubradar
//
//  Shared by the app (which requests the Live Activity) and the SubHelm widget
//  extension (which draws it). Foundation + ActivityKit only.
//

import ActivityKit
import Foundation

/// The Live Activity shown on the day a free trial ends: the last point at
/// which cancelling avoids the first charge.
struct TrialEndingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// What the trial converts to, e.g. "£17.99".
        var formattedAmount: String
    }

    /// `Subscription.id`, so the app can tell which trial an activity is for.
    var subscriptionID: String
    var name: String
    /// Localised by the app when the activity is requested, so the extension
    /// needs no strings of its own: "Netflix trial ends today".
    var title: String
    /// "You'll be charged £17.99 today unless you cancel."
    var body: String
    var symbolName: String
    /// Brand colour as "RRGGBB", or nil to fall back to the category tint.
    var brandColorHex: String?
    var categoryRaw: String
    /// End of the trial's last day.
    var endsOn: Date
}
