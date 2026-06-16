//
//  TSSettingsIndex.swift
//  TrollMemo
//
//  Created by Lessica on 2024/1/25.
//

import Foundation

enum TSSettingsIndex: Int, CaseIterable {
    case passthroughMode = 0
    case keepInPlace
    case hideAtSnapshot
    case usesRotation

    static var embeddedEditCases: [TSSettingsIndex] {
        [.passthroughMode, .keepInPlace, .hideAtSnapshot, .usesRotation]
    }

    var key: String {
        switch self {
        case .passthroughMode:
            return HUDUserDefaultsKeyPassthroughMode
        case .keepInPlace:
            return HUDUserDefaultsKeyKeepInPlace
        case .hideAtSnapshot:
            return HUDUserDefaultsKeyHideAtSnapshot
        case .usesRotation:
            return HUDUserDefaultsKeyUsesRotation
        }
    }

    var title: String {
        switch self {
        case .passthroughMode:
            return NSLocalizedString("Pass-through", comment: "TSSettingsIndex")
        case .keepInPlace:
            return NSLocalizedString("Keep In-place", comment: "TSSettingsIndex")
        case .hideAtSnapshot:
            return NSLocalizedString("Hide @snapshot", comment: "TSSettingsIndex")
        case .usesRotation:
            return NSLocalizedString("Landscape", comment: "TSSettingsIndex")
        }
    }

    func subtitle(highlighted: Bool, restartRequired: Bool) -> String {
        switch self {
        case .passthroughMode:
            if restartRequired {
                return NSLocalizedString("Re-open to apply", comment: "TSSettingsIndex")
            } else {
                return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
            }
        case .keepInPlace, .hideAtSnapshot:
            return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
        case .usesRotation:
            return highlighted ? NSLocalizedString("Follow", comment: "TSSettingsIndex") : NSLocalizedString("Hide", comment: "TSSettingsIndex")
        }
    }
}
