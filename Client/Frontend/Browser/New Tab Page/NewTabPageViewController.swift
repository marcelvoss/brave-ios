// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import BraveUI
import CoreData
import Data
import Shared
import Deferred

/// A section that will be shown in the NTP. Sections are responsible for the
/// layout and interaction of their own items
protocol NTPSectionProvider: NSObject, UICollectionViewDelegateFlowLayout & UICollectionViewDataSource {
    func registerCells(to collectionView: UICollectionView)
}
extension NTPSectionProvider {
    /// The bounding size for auto-sizing cells, bound to the maximum available
    /// width in the collection view, taking into account safe area insets and
    /// insets for that given section
    func fittingSizeForCollectionView(_ collectionView: UICollectionView, section: Int) -> CGSize {
        let sectionInset: UIEdgeInsets
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            if let flowLayoutDelegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout {
                sectionInset = flowLayoutDelegate.collectionView?(collectionView, layout: collectionView.collectionViewLayout, insetForSectionAt: section) ?? flowLayout.sectionInset
            } else {
                sectionInset = flowLayout.sectionInset
            }
        } else {
            sectionInset = .zero
        }
        return CGSize(
            width: collectionView.bounds.width -
                collectionView.safeAreaInsets.left -
                collectionView.safeAreaInsets.right -
                sectionInset.left -
                sectionInset.right,
            height: 1000
        )
    }
}

protocol NTPObservableSectionProvider: NTPSectionProvider {
    var sectionDidChange: (() -> Void)? { get set }
}

private class NewTabBackgroundView: UIView, Themeable {
    let imageView = UIImageView()
    let gradient = GradientView(
        colors: [
            UIColor(white: 0.0, alpha: 0.3),
            UIColor(white: 0.0, alpha: 0.0),
            UIColor(white: 0.0, alpha: 0.0)
        ],
        positions: [0, 0.5, 1.0],
        startPoint: .zero,
        endPoint: CGPoint(x: 0, y: 1)
    )
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageView)
        addSubview(gradient)
        imageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        gradient.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.greaterThanOrEqualTo(700)
            $0.bottom.equalToSuperview().priority(.low)
        }
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    func applyTheme(_ theme: Theme) {
        backgroundColor = theme.colors.home
    }
}

private class NewTabCollectionView: UICollectionView {
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        
        backgroundColor = .clear
        delaysContentTouches = false
        contentInsetAdjustmentBehavior = .always
    }
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
}

private class NewTabPageFlowLayout: UICollectionViewFlowLayout {
    var gapSection: Int?
    var gapHeight: CGFloat = 50
    
    override init() {
        super.init()
        estimatedItemSize = Self.automaticSize
    }
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    override var collectionViewContentSize: CGSize {
        var size = super.collectionViewContentSize
        if let gapSection = gapSection, let spacerAttributes = layoutAttributesForItem(at: IndexPath(item: 0, section: gapSection)) {
            size.height += spacerAttributes.frame.height
        }
        return size
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attribute = super.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes,
            let collectionView = collectionView else {
            return nil
        }
        // Left align the cells since they automatically center if there's only
        // 1 item in the section and use automaticSize...
        if estimatedItemSize == UICollectionViewFlowLayout.automaticSize {
            let indexPath = attribute.indexPath
            if collectionView.numberOfItems(inSection: indexPath.section) == 1 {
                let sectionInset: UIEdgeInsets
                let minimumInteritemSpacing: CGFloat
                if let flowLayoutDelegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout {
                    sectionInset = flowLayoutDelegate.collectionView?(collectionView, layout: self, insetForSectionAt: indexPath.section) ?? self.sectionInset
                    minimumInteritemSpacing = flowLayoutDelegate.collectionView?(collectionView, layout: self, minimumInteritemSpacingForSectionAt: indexPath.section) ?? self.minimumInteritemSpacing
                } else {
                    sectionInset = self.sectionInset
                    minimumInteritemSpacing = self.minimumInteritemSpacing
                }
                
                if attribute.indexPath.item == 0 {
                    attribute.frame.origin.x = sectionInset.left
                } else {
                    if let previousItemAttribute = layoutAttributesForItem(at: IndexPath(item: indexPath.item - 1, section: indexPath.section)) {
                        attribute.frame.origin.x = previousItemAttribute.frame.maxX + minimumInteritemSpacing
                    }
                }
            }
        }
        
        if attribute.indexPath.section == gapSection {
            var frame = attribute.frame
            frame.size.height = (collectionView.bounds.height - collectionView.safeAreaInsets.bottom - gapHeight) - frame.origin.y
            if frame.size.height > 0 {
                attribute.frame = frame
            }
        }
        
        return attribute
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let collectionView = collectionView,
            let attributes = super.layoutAttributesForElements(in: rect) else {
            return nil
        }
        attributes.forEach {
            if let frame = self.layoutAttributesForItem(at: $0.indexPath)?.frame {
                $0.frame = frame
            }
        }
        guard let gapSection = gapSection else { return attributes }
        let spacerAttributes = layoutAttributesForItem(at: IndexPath(item: 0, section: gapSection))
        let delta = (collectionView.bounds.height - collectionView.safeAreaInsets.bottom - gapHeight) - (spacerAttributes?.frame.origin.y ?? 0)
        if delta > 0 {
            attributes.forEach { attr in
                if attr.indexPath.section > gapSection {
                    var frame = attr.frame
                    frame.origin.y += delta
                    attr.frame = frame
                }
            }
        }
        return attributes
    }
}

class NewTabCollectionViewCell<View: UIView & Themeable>: UICollectionViewCell, Themeable, CollectionViewReusable {
    let view = View()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    var themeableChildren: [Themeable?]? {
        [view]
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        attributes.size = view.systemLayoutSizeFitting(layoutAttributes.size, withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .fittingSizeLevel)
        return attributes
    }
}

protocol NewTabPageDelegate: AnyObject {
    func focusURLBar()
    func navigateToInput(_ input: String, inNewTab: Bool, switchingToPrivateMode: Bool)
    func presentDuckDuckGoCallout()
    func sponseredImageCalloutActioned(_ state: BrandedImageCalloutState)
}

/// The new tab page. Shows users a variety of information, including stats and
/// favourites
class NewTabPageViewController: UIViewController, Themeable {
    weak var delegate: NewTabPageDelegate?
    
    /// The modules to show on the new tab page
    private var sections: [NTPSectionProvider] = []
    
    private let layout = NewTabPageFlowLayout()
    private let collectionView: NewTabCollectionView
    private let backgroundView = NewTabBackgroundView()
    private let tab: Tab
    
    init(tab: Tab, profile: Profile) {
        self.tab = tab
        collectionView = NewTabCollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
        sections = [
            StatsSectionProvider(),
            FavoritesSectionProvider(action: { [weak self] bookmark, action in
                self?.handleBookmarkAction(bookmark: bookmark, action: action)
            }),
            FavoritesOverflowSectionProvider(action: { [weak self] in
                self?.delegate?.focusURLBar()
            }),
            DuckDuckGoCalloutSectionProvider(profile: profile, action: { [weak self] in
                self?.delegate?.presentDuckDuckGoCallout()
            }),
            SpacerSectionProvider(),
            BackgroundImageCreditSectionProvider(action: { [weak self] control in
                self?.presentImageCredit(from: control)
            }),
        ]
        layout.gapSection = sections.firstIndex(where: { $0 is SpacerSectionProvider })
        sections.enumerated().forEach { (index, provider) in
            provider.registerCells(to: collectionView)
            if let observableProvider = provider as? NTPObservableSectionProvider {
                observableProvider.sectionDidChange = {
                    DispatchQueue.main.async {
                        self.collectionView.reloadSections(IndexSet(integer: index))
                    }
                }
            }
        }
        collectionView.delegate = self
        collectionView.dataSource = self
        applyTheme(Theme.of(tab))
//        modalPresentationStyle = .fullScreen
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(backgroundView)
        view.addSubview(collectionView)
        
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        collectionView.reloadData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *) {
            if UITraitCollection.current.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
                // Reload UI
                applyTheme(Theme.of(tab))
            }
        }
    }
    
    var themeableChildren: [Themeable?]? {
        [backgroundView]
    }
    
    func applyTheme(_ theme: Theme) {
        styleChildren(theme: theme)
        collectionView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        collectionView.reloadData()
    }
    
    // MARK: - Actions
    
    private func handleBookmarkAction(bookmark: Bookmark, action: BookmarksAction) {
        guard let url = bookmark.url else { return }
        switch action {
        case .opened(let inNewTab, let switchingToPrivateMode):
            delegate?.navigateToInput(
                url,
                inNewTab: inNewTab,
                switchingToPrivateMode: switchingToPrivateMode
            )
        case .edited:
            break
        }
    }
    
    private func presentImageCredit(from button: UIControl) {
        print("selected")
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension NewTabPageViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        sections[indexPath.section].collectionView?(collectionView, didSelectItemAt: indexPath)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        sections[indexPath.section].collectionView?(collectionView, layout: collectionViewLayout, sizeForItemAt: indexPath) ?? .zero
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        var inset = sections[section].collectionView?(collectionView, layout: collectionViewLayout, insetForSectionAt: section) ?? .zero
        let isIphone = UIDevice.isPhone
        let isLandscape = traitCollection.horizontalSizeClass == .regular
        if isLandscape {
            let availableWidth = collectionView.bounds.width - collectionView.safeAreaInsets.left - collectionView.safeAreaInsets.right
            if isIphone {
                inset.left = availableWidth / 2.0
            } else {
                inset.right = availableWidth / 2.0
            }
        }
        return inset
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        sections[section].collectionView?(collectionView, layout: collectionViewLayout, minimumLineSpacingForSectionAt: section) ?? 0
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        sections[section].collectionView?(collectionView, layout: collectionViewLayout, minimumInteritemSpacingForSectionAt: section) ?? 0
    }
}

// MARK: - UICollectionViewDataSource
extension NewTabPageViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].collectionView(collectionView, numberOfItemsInSection: section)
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = sections[indexPath.section].collectionView(collectionView, cellForItemAt: indexPath)
        if let themableCell = cell as? Themeable {
            themableCell.applyTheme(Theme.of(tab))
        }
        return cell
    }
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        sections[indexPath.section].collectionView?(collectionView, contextMenuConfigurationForItemAt: indexPath, point: point)
    }
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else {
            return nil
        }
        return sections[indexPath.section].collectionView?(collectionView, previewForHighlightingContextMenuWithConfiguration: configuration)
    }
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else {
            return nil
        }
        return sections[indexPath.section].collectionView?(collectionView, previewForHighlightingContextMenuWithConfiguration: configuration)
    }
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else {
            return
        }
        sections[indexPath.section].collectionView?(collectionView, willPerformPreviewActionForMenuWith: configuration, animator: animator)
    }
}
