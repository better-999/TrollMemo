//
//  TSSettingsController.swift
//  TrollMemo
//
//  Created by Lessica on 2024/1/24.
//

import UIKit

@objc public protocol TSSettingsControllerDelegate {
    func settingHighlighted(key: String) -> Bool
    func settingDidSelect(key: String) -> Void
}

@objc open class TSSettingsController : SPLarkSettingsController
{
    @objc open weak var delegate: TSSettingsControllerDelegate?
    @objc open var alreadyLaunched: Bool = false
    @objc open var embeddedInEditSheet: Bool = false
    internal var restartRequired = false

    open override func viewDidLoad() {
        super.viewDidLoad()
        if embeddedInEditSheet {
            titleLabel.isHidden = true
            closeButton.isHidden = true
            view.backgroundColor = .clear
            collectionView.sideInset = 12
            collectionView.cellSize = CGSize(width: 140, height: 56)
        }
    }

    open override func viewDidLayoutSubviews() {
        if embeddedInEditSheet {
            collectionView.layout(y: 8)
            return
        }
        super.viewDidLayoutSubviews()
    }

    private var visibleSettings: [TSSettingsIndex] {
        embeddedInEditSheet ? TSSettingsIndex.embeddedEditCases : TSSettingsIndex.allCases
    }

    open override func settingsCount() -> Int {
        return visibleSettings.count
    }

    open override func settingTitle(index: Int, highlighted: Bool) -> String {
        return visibleSettings[index].title
    }

    open override func settingSubtitle(index: Int, highlighted: Bool) -> String? {
        return visibleSettings[index].subtitle(highlighted: highlighted, restartRequired: restartRequired)
    }

    private func settingKey(index: Int) -> String {
        return visibleSettings[index].key
    }

    open override func settingHighlighted(index: Int) -> Bool {
        return delegate?.settingHighlighted(key: settingKey(index: index)) ?? false
    }

    open override func settingColorHighlighted(index: Int) -> UIColor {
        return UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 28/255.0, green: 74/255.0, blue: 82/255.0, alpha: 1.0)
            } else {
                return UIColor(red: 22/255.0, green: 160/255.0, blue: 133/255.0, alpha: 1.0)
            }
        }
    }

    open override func settingDidSelect(index: Int, completion: @escaping () -> ()) {
        if index == 0 && alreadyLaunched {
            restartRequired = true
        }
        delegate?.settingDidSelect(key: settingKey(index: index))
        completion()
    }

    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard let currentOrientation = view.window?.windowScene?.interfaceOrientation else {
            return [.portrait]
        }
        switch currentOrientation {
        case .unknown: fallthrough
        case .portrait:
            return [.portrait]
        case .portraitUpsideDown:
            return [.portraitUpsideDown]
        case .landscapeLeft:
            return [.landscapeLeft]
        case .landscapeRight:
            return [.landscapeRight]
        @unknown default:
            return [.portrait]
        }
    }

    open override var shouldAutorotate: Bool { false }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if embeddedInEditSheet {
            return
        }
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != self.traitCollection.userInterfaceStyle {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
