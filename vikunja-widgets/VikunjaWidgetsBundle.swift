//
//  VikunjaWidgetsBundle.swift
//  vikunja-widgets
//
//  The widget extension's entry point. All widget logic lives in the
//  `VikunjaWidgetKit` package; this file only registers the bundle.
//

import SwiftUI
import VikunjaWidgetKit
import WidgetKit

@main
struct VikunjaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        QuickAddWidget()
        if #available(iOS 18.0, *) {
            QuickAddControl()
        }
    }
}
