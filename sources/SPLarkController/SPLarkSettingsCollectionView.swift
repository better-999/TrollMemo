// The MIT License (MIT)
// Copyright © 2017 Ivan Vorobei (hello@ivanvorobei.by)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

@available(iOS 8.2, *)
open class SPLarkSettingsCollectionView: UICollectionView {
    
    let layout = UICollectionViewFlowLayout()
    let cellIdentificator: String = "SPLarkSettingsCollectionViewCell"
    var cellSize: CGSize = CGSize.init(width: 156, height: 60)
    var sideInset: CGFloat = 27
    var forceSingleRow: Bool = false
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    init() {
        super.init(frame: .zero, collectionViewLayout: self.layout)
        self.commonInit()
    }
    
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: self.layout)
        self.commonInit()
    }
    
    internal func commonInit() {
        self.backgroundColor = UIColor.clear
        self.decelerationRate = UIScrollView.DecelerationRate.fast
        self.delaysContentTouches = false
        self.isPagingEnabled = false
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        
        self.layout.scrollDirection = .horizontal
        self.layout.minimumLineSpacing = 19 / 2
        self.layout.minimumInteritemSpacing = 19 / 2
        self.contentInset = UIEdgeInsets.init(top: 0, left: self.sideInset, bottom: 0, right: self.sideInset)
        
        self.register(SPLarkSettingsCollectionViewCell.self, forCellWithReuseIdentifier: self.cellIdentificator)
    }
    
    func dequeueCell(indexPath: IndexPath) -> SPLarkSettingsCollectionViewCell {
        return self.dequeueReusableCell(withReuseIdentifier: self.cellIdentificator, for: indexPath) as! SPLarkSettingsCollectionViewCell
    }
    
    func layout(y: CGFloat, itemCount: Int = 0) {
        let availableWidth = self.superview?.frame.width ?? 0
        var itemSize = self.cellSize
        var rowCount = 2

        if self.forceSingleRow && itemCount > 0 {
            rowCount = 1
            let spacing = self.layout.minimumLineSpacing
            let totalSpacing = spacing * CGFloat(max(itemCount - 1, 0))
            let horizontalInset = self.sideInset * 2
            let computedWidth = floor((availableWidth - horizontalInset - totalSpacing) / CGFloat(itemCount))
            itemSize = CGSize(width: max(computedWidth, 72), height: itemSize.height)
            self.isScrollEnabled = false
        } else {
            self.isScrollEnabled = true
        }

        let rowSpacing = rowCount > 1 ? self.layout.minimumInteritemSpacing : 0
        let height = itemSize.height * CGFloat(rowCount) + rowSpacing
        self.frame = CGRect(x: 0, y: y, width: availableWidth, height: height)
        self.layout.itemSize = itemSize
        self.layout.invalidateLayout()
    }
}
