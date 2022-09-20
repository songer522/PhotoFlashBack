//
//  PhotosViewController+CollectionView.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit

extension PhotosViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
        
        view.backgroundColor = UIColor.clear
        for subView in view.subviews {
            
            subView.removeFromSuperview()
        }
       
        let key = viewModel.assetArray[indexPath.section].0
        let label = UILabel.init(frame: CGRect(x: 10, y: 10, width: view.frame.size.width - 10, height: view.frame.size.height-10))
        label.text = key
        label.font = UIFont(name: "AppleSDGothicNeo-Bold", size: 30)
        label.textColor = .white
        label.textAlignment = .left;
        view.addSubview(label)
        view.tag = indexPath.section
        //findLocation(view, assetArray: viewModel.assetArray[indexPath.section].1, currentIndex: 0)
      
        return view
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        return CGSize(width: collectionView.bounds.width, height: 80)
    }
}

extension PhotosViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.assetArray[section].1.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let collectionCell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCollectionViewCell
        let targetSize = CGSize(width: 300, height: 300)
        let asset =  viewModel.assetArray[indexPath.section].1[indexPath.row]
        viewModel.assetManager.requestImage(for: asset,
                                            targetSize: targetSize,
                                            contentMode: .aspectFill,
                                            options: nil,
                                            resultHandler: { image, info in
            
            //collectionCell?.itemImageView.contentMode = .scaleAspectFill
            collectionCell?.itemImageView.image = image
            //                                        if self.fullFeatureUnlocked == false && self.month != NSCalendar.currentCalendar().component(.Month, fromDate: NSDate()){
            //                                           collectionCell?.blurEffectView.hidden = false
            //                                        }else {
            //                                            collectionCell?.blurEffectView.hidden = true
            //                                        }
            
            
        })
        
        return collectionCell!
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.assetDict.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                          layout collectionViewLayout: UICollectionViewLayout,
                                 sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        
        let width = (UIScreen.main.bounds.width - 6)/3
        
        return CGSize(width: width, height: width)
    }
}
