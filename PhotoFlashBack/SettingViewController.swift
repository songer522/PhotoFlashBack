//
//  SettingViewController.swift
//  PhotoFlashBack
//
//  Created by Song, Yang on 7/22/16.
//  Copyright © 2016 Yang Song. All rights reserved.
//

import UIKit
import MessageUI

class SettingViewController: UIViewController {
 @IBOutlet weak var settingTableView : UITableView!
 let titles = ["Rate","Feedback","Other App"]
 let subtitles = ["If you enjoy this app, please rate it in App Store.","Email us if you have any suggestion for the app.","Check out another app of ours Fun Collages, it allows you to make collages and photo booth style strips!"]
    override func viewDidLoad() {
        super.viewDidLoad()
        let title = UILabel.init(frame: CGRect(x: 0, y: 0, width: 120, height: 30))
        title.text = "Rewind"
        title.textAlignment = .center
        title.textColor = UIColor.white
        title.font = UIFont(name: "AppleSDGothicNeo-Bold", size: 20)
        self.navigationItem.titleView = title
        settingTableView.estimatedRowHeight = 70
        settingTableView.rowHeight = UITableViewAutomaticDimension
        settingTableView.tableFooterView = UIView(frame: CGRect.zero)
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(dismiss(sender:)))
        if let font = UIFont(name: "AppleSDGothicNeo-Regular", size: 20) {
            navigationItem.rightBarButtonItem!.setTitleTextAttributes([NSFontAttributeName: font], for: UIControlState())
        }
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func numberOfSectionsInTableView(_ tableView: UITableView) -> Int {
        
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell: SettingCell = tableView.dequeueReusableCell(withIdentifier: "setting") as! SettingCell
        
        cell.title.text = titles[indexPath.row]
        cell.subTitle.text = subtitles[indexPath.row]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: IndexPath) -> CGFloat {
        return settingTableView.estimatedRowHeight
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        
        if indexPath.row == 0 {
            UIApplication.shared.openURL(URL.init(string: "https://itunes.apple.com/us/app/rewind-all-your-photos-taken/id1137168287?ls=1&mt=8")!)
        }
        
        if indexPath.row == 1 {
            email()
        }
        
        if indexPath.row == 2 {
            UIApplication.shared.openURL(URL.init(string: "https://itunes.apple.com/us/app/fun-collages/id471290783?ls=1&mt=8")!)
        }
 
    }
    
    func dismiss(sender: AnyObject){
        self.dismiss(animated: true, completion: nil)
    }
    
    func email() {
     
            if MFMailComposeViewController.canSendMail() {
                let mailVC = MFMailComposeViewController()
                // if let emailAddress = personalShopperProfile?.emailAddress {
                mailVC.setToRecipients(["rewind.feedback@gmail.com"])
                //  }
                mailVC.mailComposeDelegate = self
                self.present(mailVC, animated: true, completion: nil)
            } else {
                let email = "rewind.feedback@gmail.com"
                let url = URL(string: "mailto:\(email)")
                if UIApplication.shared.canOpenURL(url!) {
                    UIApplication.shared.openURL(url!)
                } else {
                    
                }
            }
         
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension SettingViewController: MFMailComposeViewControllerDelegate {
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
}
