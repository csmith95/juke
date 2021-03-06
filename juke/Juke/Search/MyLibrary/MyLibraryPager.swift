//
//  MyLibraryPager.swift
//  Juke
//
//  Created by Conner Smith on 9/26/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import UIKit
import XLPagerTabStrip

class MyLibraryPager: ButtonBarPagerTabStripViewController {

    @IBOutlet var searchBar: UISearchBar!
    var notificationName: String!
    
    override func viewDidLoad() {
        // change selected bar color
        settings.style.buttonBarBackgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        settings.style.buttonBarItemBackgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        settings.style.selectedBarBackgroundColor = .white
        settings.style.buttonBarItemFont = UIFont.systemFont(ofSize: 16)
        settings.style.selectedBarHeight = 2.0
        settings.style.buttonBarMinimumLineSpacing = 0
        settings.style.buttonBarItemTitleColor = .white
        settings.style.buttonBarItemsShouldFillAvailiableWidth = true
        settings.style.buttonBarLeftContentInset = 0
        settings.style.buttonBarRightContentInset = 0
        changeCurrentIndexProgressive = { [weak self] (oldCell: ButtonBarViewCell?, newCell: ButtonBarViewCell?, progressPercentage: CGFloat, changeCurrentIndex: Bool, animated: Bool) -> Void in
            guard changeCurrentIndex == true else { return }
            if oldCell == nil || newCell == nil { return }  // because this block fires on init
            
            //set who receives notification
            if newCell?.label.text == "Songs" {
                self?.notificationName = "MySongsSearchNotification"
            } else {
                self?.notificationName = "MyPlaylistsSearchNotification"
            }
            self?.searchBar.text = ""
            self?.execSearchQuery()
            
        }
        // notification should start as MySongsSearchNotification
        self.notificationName = "MySongsSearchNotification"
        NotificationCenter.default.addObserver(self, selector: #selector(self.hideKeyboard), name: Notification.Name("MyLibraryPager.hideKeyboard"), object: nil)
        
        super.viewDidLoad()
    }
    
    override func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
        let child_1 = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MySongsTableViewController")
        let child_2 = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MyPlaylistsTableViewController")
        return [child_1, child_2]
    }
    
    func hideKeyboard() {
        self.view.endEditing(true)
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    func execSearchQuery() {
        if let query = searchBar.text {
            NotificationCenter.default.post(name: Notification.Name(notificationName), object: nil, userInfo: ["query" : query.lowercased()])
        }
    }
    
    // set status bar content to white text
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

}


extension MyLibraryPager: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        execSearchQuery()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        execSearchQuery()
        hideKeyboard()
    }
    
}


