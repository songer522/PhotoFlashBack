//
//  TodayWidgetBundle.swift
//  TodayWidget
//
//  Created by Yang Song on 3/30/23.
//

import WidgetKit
import SwiftUI

@main
struct TodayWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TodayWidgetLiveActivity()
    }
}
