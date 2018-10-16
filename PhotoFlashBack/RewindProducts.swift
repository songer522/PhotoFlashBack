//
//  RewindProducts.swift
//  PhotoFlashBack
//
//  Created by Song, Yang on 7/22/16.
//  Copyright © 2016 Yang Song. All rights reserved.
//

import Foundation

public struct RewindProducts {
    
    // TODO:  Change this to the BundleID chosen when registering this app's App ID in the Apple Member Center.
    fileprivate static let Prefix = "com.YangSong.PhotoFlashBack."
    
    //UnlockFullFeature
    public static let TipSmall = "TipSmall"
    public static let Unlock = "UnlockFullFeature"
    
    fileprivate static let productIdentifiers: Set<ProductIdentifier> = [RewindProducts.TipSmall]
    
    // TODO: This is the code that would be used if you added iPhoneRage, NightlyRage, and UpdogRage to the list of purchasable
    //       products in iTunesConnect.
    /*
     public static let GirlfriendOfDrummerRage = Prefix + "GirlfriendOfDrummerRage"
     public static let iPhoneRage              = Prefix + "iPhoneRage"
     public static let NightlyRage             = Prefix + "NightlyRage"
     public static let UpdogRage               = Prefix + "UpdogRage"
     
     private static let productIdentifiers: Set<ProductIdentifier> = [RageProducts.GirlfriendOfDrummerRage,
     RageProducts.iPhoneRage,
     RageProducts.NightlyRage,
     RageProducts.UpdogRage]
     */
    public static let store = IAPHelper(productIds: RewindProducts.productIdentifiers)
}

func resourceNameForProductIdentifier(_ productIdentifier: String) -> String? {
    return productIdentifier.components(separatedBy: ".").last
}

