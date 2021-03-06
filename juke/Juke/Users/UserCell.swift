//
//  UserCell.swift
//  Juke
//
//  Created by Conner Smith on 8/26/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import UIKit
import AlamofireImage
import PKHUD
import Firebase

class UserCell: UITableViewCell {

    @IBOutlet var inviteToStreamButton: UIButton!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var userImageView: UIImageView!
    @IBOutlet weak var starButton: UIButton!
    @IBOutlet var starIcon: UIImageView!
    @IBOutlet var hostLabel: UILabel!
    private var member: Models.FirebaseUser!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    @IBAction func starButtonPressed(_ sender: Any) {
        var message = ""
        var shouldHideStar = false
        if Current.isStarred(spotifyID: member.spotifyID) {
            FirebaseAPI.removeFromStarredTable(user: self.member)
            self.starIcon.isHidden = true
            self.starButton.isSelected = false
            message = "Removed \(self.member.username)"
            Current.removeStarredUser(user: self.member)
            shouldHideStar = true
        } else {
            FirebaseAPI.addToStarredTable(user: self.member)
            self.starIcon.isHidden = false
            self.starButton.isSelected = true
            message = "Starred \(self.member.username)"
            Current.addStarredUser(user: self.member)
        }
        
        FirebaseAPI.checkVerified(spotifyID: member.spotifyID) { (isVerified) in
            if isVerified {
                shouldHideStar = false
            }
            self.starIcon.isHidden = shouldHideStar
        }

        HUD.flash(.labeledSuccess(title: nil, subtitle: message), delay: 1.0)
    }
    
    public func populateCell(member: Models.FirebaseUser) {
        if hostLabel != nil {
            if Current.stream!.host.spotifyID == member.spotifyID {
                hostLabel.isHidden = false
            } else {
                hostLabel.isHidden = true
            }
        }
        
        if Current.user!.spotifyID == member.spotifyID {
            // necessary because this cell is used in the stream members table view controller
            starButton.isHidden = true
            starIcon.isHidden = true
        } else {
            starButton.isHidden = false
        }
        
        if Current.isStarred(user: member) {
            starIcon.image = #imageLiteral(resourceName: "Star")
            starButton.isSelected = true
            starIcon.isHidden = false
        } else {
            starButton.isSelected = false
            starIcon.isHidden = true
        }
        
        FirebaseAPI.checkVerified(spotifyID: member.spotifyID) { (isVerified) in
            if isVerified {
                self.starIcon.image = #imageLiteral(resourceName: "verified")
                self.starIcon.isHidden = false
            }
        }
        
        // set elements
        self.member = member
        self.userNameLabel.text = member.username
        loadUserIcon(url: member.imageURL)
    }
    
    private func loadUserIcon(url: String?) {
        ImageCache.downloadUserImage(url: url, callback: { (image) in
            self.userImageView.image = image
        })
    }
}
