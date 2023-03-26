//
//  CustomLayouts.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 3/26/23.
//

import UIKit

class CustomLayouts {
    
    class func layoutA(size: CGSize) -> NSCollectionLayoutSection {
        let largeItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension:.fractionalHeight(1.0))
        let mediumItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(2/3),
                                                   heightDimension:.fractionalHeight(1.0))
        let smallItemSize2 = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3),
                                                   heightDimension:.fractionalHeight(1.0))
        let smallItemSize1 = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                    heightDimension:.fractionalHeight(0.5))
        let largeItem = NSCollectionLayoutItem(layoutSize: largeItemSize)
        largeItem.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let mediumItem = NSCollectionLayoutItem(layoutSize: mediumItemSize)
        mediumItem.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let samllItem1 = NSCollectionLayoutItem(layoutSize: smallItemSize1)
        samllItem1.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let samllItem2 = NSCollectionLayoutItem(layoutSize: smallItemSize2)
        samllItem2.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let largeGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalHeight(0.25)),
            subitem: largeItem, count: 1)
        
        let smallGroup1 = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3),
                                               heightDimension: .fractionalHeight(1)),
            subitem: samllItem1, count: 2)
        
        let mediumGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalHeight(0.25 * (2/3))),
            subitems: [mediumItem, smallGroup1])
        let mediumGroupReversed = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalHeight(0.25 * (2/3))),
            subitems: [smallGroup1, mediumItem])
        
        let smallGroup2 = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .fractionalHeight(0.25 * (1/3))),
            subitem: samllItem2, count: 3)
        
        let height = size.width * 4
        let megaGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(height)),
            subitems: [largeGroup, mediumGroup, smallGroup2, largeGroup, mediumGroupReversed, smallGroup2])
        
        let section = NSCollectionLayoutSection(group: megaGroup)
        
        let footerHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                      heightDimension: .absolute(50.0))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerHeaderSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
        header.pinToVisibleBounds = true
        section.boundarySupplementaryItems = [header]
        return section
    }
    
    class func layoutB(size: CGSize) -> NSCollectionLayoutSection {
        let largeItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(2/3),
                                                   heightDimension:.fractionalHeight(1.0))
        let mediumItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3),
                                                   heightDimension:.fractionalHeight(1.0))
        let smallItemSize2 = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/6),
                                                   heightDimension:.fractionalHeight(1.0))
        let smallItemSize1 = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                    heightDimension:.fractionalHeight(0.5))
        let largeItem = NSCollectionLayoutItem(layoutSize: largeItemSize)
        largeItem.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let mediumItem = NSCollectionLayoutItem(layoutSize: mediumItemSize)
        mediumItem.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let samllItem1 = NSCollectionLayoutItem(layoutSize: smallItemSize1)
        samllItem1.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let samllItem2 = NSCollectionLayoutItem(layoutSize: smallItemSize2)
        samllItem2.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let smallGroup1 = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3),
                                               heightDimension: .fractionalHeight(1)),
            subitem: samllItem1, count: 2)
        let largeGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalHeight(3/14)),
            subitems: [largeItem, smallGroup1])
        let largeGroupReversed = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalHeight(3/14)),
            subitems: [smallGroup1,largeItem])
        
        
        let mediumGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .fractionalHeight(3/14)),
            subitem: mediumItem, count: 3)

        
        let smallGroup2 = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .fractionalHeight(1/14)),
            subitem: samllItem2, count: 6)
        
        let height = size.height * (14/3)
        let megaGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(height)),
            subitems: [largeGroup, mediumGroup, smallGroup2, largeGroupReversed, mediumGroup,smallGroup2])
        
        let section = NSCollectionLayoutSection(group: megaGroup)
        
        let footerHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                      heightDimension: .absolute(50.0))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerHeaderSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
        header.pinToVisibleBounds = true
        section.boundarySupplementaryItems = [header]
        return section
    }
    
    class func oldLayout(isLandscape: Bool = false, size: CGSize) -> NSCollectionLayoutSection {
        let leadingItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                                     heightDimension: .fractionalHeight(1.0))
        let leadingItem = NSCollectionLayoutItem(layoutSize: leadingItemSize)
        leadingItem.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let trailingItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                      heightDimension: .fractionalHeight(0.3))
        let trailingItem = NSCollectionLayoutItem(layoutSize: trailingItemSize)
        trailingItem.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let trailingLeftGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25),
                                               heightDimension: .fractionalHeight(1.0)),
            subitem: trailingItem, count: 2)
        
        let trailingRightGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25),
                                               heightDimension: .fractionalHeight(1.0)),
            subitem: trailingItem, count: 2)
        
        let fractionalHeight = isLandscape ? NSCollectionLayoutDimension.fractionalHeight(0.8) : NSCollectionLayoutDimension.fractionalHeight(0.4)
        let groupDimensionHeight: NSCollectionLayoutDimension = fractionalHeight
        
        let rightGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: groupDimensionHeight),
            subitems: [leadingItem, trailingLeftGroup, trailingRightGroup])
        
        let leftGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: groupDimensionHeight),
            subitems: [trailingRightGroup, trailingLeftGroup, leadingItem])
        
        let height = isLandscape ? size.height / 0.9 : size.height / 1.25
        let megaGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(height)),
            subitems: [rightGroup, leftGroup])
        
        let section = NSCollectionLayoutSection(group: megaGroup)
        
        let footerHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                      heightDimension: .absolute(50.0))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerHeaderSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
        header.pinToVisibleBounds = true
        section.boundarySupplementaryItems = [header]
        return section
    }
}
