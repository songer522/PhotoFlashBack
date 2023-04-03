//
//  Configuration.swift
//  TodayWidgetExtension
//
//  Created by Yang Song on 4/3/23.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct Configuration: AppIntent, CustomIntentMigratedAppIntent {
    static let intentClassName = "ConfigurationIntent"

    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("")

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        // TODO: Place your refactored intent handler code here.
        return .result()
    }
}


