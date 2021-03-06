//
//  EmptyStreamViewController.swift
//  Juke
//
//  Created by Conner Smith on 9/16/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import UIKit
import Crashlytics

class EmptyStreamViewController: UIViewController {

    @IBOutlet weak var streamTitleLabel: UILabel!
    @IBOutlet weak var numMembersButton: UIButton!
    @IBOutlet weak var twoDownArrows: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(self.streamDeleted), name: Notification.Name("streamDeleted"), object: nil)
        Answers.logContentView(withName: "Empty Stream Page", contentType: "Empty Stream", contentId: "\(Current.user?.spotifyID ?? "noname"))|emptyStream")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUI()
    }
    
    func streamDeleted() {
        setUI()
    }
    
    private func setUI() {
        guard let stream = Current.stream else {
            //  if user not in stream
            streamTitleLabel.isHidden = true
            numMembersButton.isHidden = true
            return
        }
        
        streamTitleLabel.isHidden = false
        streamTitleLabel.text = stream.title
        numMembersButton.isHidden = false
        let count = stream.members.count+1
        let message = "\(count) member" + ((count > 1) ? "s" : "")
        numMembersButton.setTitle(message, for: .normal)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowMembers" {
            guard let stream = Current.stream else { return }
            let dest = segue.destination as! MembersTableViewController
            dest.stream = stream
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func unwindToViewControllerNameHere(segue: UIStoryboardSegue) {
        //nothing goes here
    }
    
    // set status bar text to white
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
