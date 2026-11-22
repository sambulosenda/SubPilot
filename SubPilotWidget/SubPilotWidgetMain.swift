//
//  SubPilotWidgetMain.swift
//  SubPilotWidget
//
//  The widget bundle entry point. Named so it doesn't collide with Xcode's
//  template `SubPilotWidgetBundle.swift` — delete the template file after
//  creating the target (see the wiring notes in the PR / chat).
//

import WidgetKit
import SwiftUI

@main
struct SubPilotWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextRenewalWidget()
        AddSubscriptionControl()
        TrialEndingLiveActivity()
    }
}
