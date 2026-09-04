//
//  VikuWidgetsBundle.swift
//  Viku-widgets
//
//  The widget extension's entry point. All widget logic lives in the
//  `VikuWidgetKit` package; this file only registers the bundle.
//

import SwiftUI
import VikuWidgetKit
import WidgetKit

@main
struct VikuWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        CalendarWidget()
        QuickAddWidget()
        GlyphWidget()
        if #available(iOS 18.0, *) {
            QuickAddControl()
        }
    }
}
