//
//  ContactsTableViewController.swift
//  Juke
//
//  Created by Conner Smith on 3/28/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import UIKit
import AlamofireImage
import Alamofire
import Unbox
import SCLAlertView
import Firebase
import FirebaseDatabaseUI
import XLPagerTabStrip
import Presentr
import PKHUD

class StreamsTableViewController: UITableViewController, UISearchBarDelegate, IndicatorInfoProvider {
    
    @IBOutlet var streamsTableView: UITableView!
    public var streamsDataSource = StreamsDataSource()
    
    let presenter: Presentr = {
        let presenter = Presentr(presentationType: .alert)
        presenter.dismissAnimated = true
        presenter.cornerRadius = 10
        presenter.transitionType = TransitionType.coverVerticalFromTop
        presenter.keyboardTranslationType = .moveUp
        return presenter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        streamsTableView.dataSource = streamsDataSource
        streamsTableView.delegate = streamsDataSource
        
        print("Filtered collection count", streamsDataSource.filteredCollection.count)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadStreams), name: Notification.Name("reloadStreams"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.newStreamSelected), name: Notification.Name("newStreamSelected"), object: nil)
        NotificationCenter.default.addObserver(forName: Notification.Name("allStreamsSearchNotification"), object: nil, queue: nil, using: execSearchQuery)
        checkNoStreams()
        // Track views of this page
        Answers.logContentView(withName: "All Streams Page", contentType: "All Streams List", contentId: "\(Current.user?.spotifyID ?? "noname"))|AllStreams")

    }
    
    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title: "All")
    }
    
    private func execSearchQuery(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        if let source = tableView.dataSource as? CustomDataSource {
            source.searchBy(query: userInfo["query"] as! String)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        streamsDataSource.listen()
        checkNoStreams()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        streamsDataSource.detach()
    }
    
    // triggered from data source class
    func reloadStreams() {
        DispatchQueue.main.async {
            objc_sync_enter(self.streamsTableView.dataSource)
            self.streamsTableView.reloadData()
            self.checkNoStreams()
            objc_sync_exit(self.streamsTableView.dataSource)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // triggered by CustomDataSource posting a notification
    func newStreamSelected(notification: NSNotification) {
        if let object = notification.object as? [String: Any],
            let stream = object["stream"] as? Models.FirebaseStream
        {
            if Current.isHost() {
                showEndStreamModal(stream: stream)
            } else {
                joinStream(stream: stream)
            }
        }
    }
    
    private func joinStream(stream: Models.FirebaseStream) {
        FirebaseAPI.joinStreamPressed(stream: stream) { success in
            if success {
                HUD.flash(.success, delay: 1.0)
                self.tabBarController?.selectedIndex = 2
            } else {
                HUD.flash(.error, delay: 1.0)
            }
        }
    }
    
    private func showEndStreamModal(stream: Models.FirebaseStream) {
        let title = "Sure you want to join?"
        let body = "You are hosting a stream. The vibe will be lost forever if you do this!"
        let controller = Presentr.alertViewController(title: title, body: body)
        
        let deleteAction = AlertAction(title: "Sure", style: .destructive) { _ in
            self.joinStream(stream: stream)
        }

        let okAction = AlertAction(title: "NO, sorry", style: .cancel) { _ in
            print("Ok!")
        }

        controller.addAction(deleteAction)
        controller.addAction(okAction)
        
        presenter.presentationType = .alert
        customPresentViewController(presenter, viewController: controller, animated: true, completion: nil)
    }
    
    func checkNoStreams() {
        
        //let count = self.streamsTableView.numberOfRows(inSection: 0)
        if streamsTableView.visibleCells.isEmpty {
            let emptyStateLabel = UILabel(frame: self.streamsTableView.frame)
            emptyStateLabel.text = "The whole world has gone quiet... \n \n Start adding some songs to your own stream!"
            emptyStateLabel.textColor = UIColor.white
            emptyStateLabel.textAlignment = .center
            emptyStateLabel.numberOfLines = 0
            self.streamsTableView.backgroundView = emptyStateLabel
        } else {
            self.streamsTableView.backgroundView = nil
        }
        //print("tableView visible cells count", tableView.visibleCells.count)
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}


