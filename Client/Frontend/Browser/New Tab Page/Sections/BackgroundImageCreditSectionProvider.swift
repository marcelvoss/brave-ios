// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import BraveUI

private class ImageCreditButton: SpringButton, Themeable {
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .light)).then {
        $0.clipsToBounds = true
        $0.isUserInteractionEnabled = false
        $0.layer.cornerRadius = 4
    }
    
    let label = UILabel().then {
        $0.text = "Test"
        $0.appearanceTextColor = .white
        $0.font = UIFont.systemFont(ofSize: 12.0, weight: .medium)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(backgroundView)
        backgroundView.contentView.addSubview(label)
        
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        label.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10))
        }
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
}

class BackgroundImageCreditSectionProvider: NSObject, NTPSectionProvider {
    var tappedImageCreditButton: (UIControl) -> Void
    
    init(action: @escaping (UIControl) -> Void) {
        self.tappedImageCreditButton = action
        super.init()
    }
    
    @objc private func tappedButton(_ sender: ImageCreditButton) {
        self.tappedImageCreditButton(sender)
    }
    
    func registerCells(to collectionView: UICollectionView) {
        collectionView.register(NewTabCollectionViewCell<ImageCreditButton>.self)
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath) as NewTabCollectionViewCell<ImageCreditButton>
        cell.view.addTarget(self, action: #selector(tappedButton(_:)), for: .touchUpInside)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return fittingSizeForCollectionView(collectionView, section: indexPath.section)
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(equalInset: 16)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("selected")
    }
}