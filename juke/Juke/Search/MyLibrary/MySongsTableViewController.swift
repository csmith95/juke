//
//  MySongsTableViewController.swift
//  Juke
//
//  Created by Conner Smith on 9/26/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import UIKit
import XLPagerTabStrip
import Alamofire
import Unbox
import Crashlytics

class MySongsTableViewController: UITableViewController, IndicatorInfoProvider {

    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title: "Songs")
    }
    
    var allSongs:[Models.SpotifySong] = []           // all results
    var displayedSongs:[Models.SpotifySong] = []  // filtered results
    typealias JSONStandard = [String: Any?]
    
    // MARK: view life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSavedTracks()
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        tapRecognizer.cancelsTouchesInView = false
        self.tableView.addGestureRecognizer(tapRecognizer)
        NotificationCenter.default.addObserver(self, selector: #selector(self.libraryChanged), name: Notification.Name("libraryChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.execSearch), name: Notification.Name("MySongsSearchNotification"), object: nil)
        
        // track views of this page
        Answers.logContentView(withName: "Saved Songs Page", contentType: "Saved Songs List", contentId: "\(Current.user?.spotifyID ?? "noname"))|savedSongs")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // reset UI
        execSearchHelper(keywords: "")
        SongKeeper.addedSongs.removeAll()
    }
    
    // MARK: - Table view data source/delegate
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        hideKeyboard()
    }
    
    func threadSafeReloadView() {
        objc_sync_enter(tableView)
        tableView.reloadData()
        objc_sync_exit(tableView)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedSongs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "MyLibrarySearchCell", for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let cell = cell as! SearchCell
        cell.populateCell(song: self.displayedSongs[indexPath.row])
    }
    
    func hideKeyboard() {
        self.view.endEditing(true)
    }
    
    func execSearch(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        self.execSearchHelper(keywords: userInfo["query"] as! String)
    }
    
    private func execSearchHelper(keywords: String) {
        if keywords.isEmpty {
            displayedSongs = allSongs
        } else {
            displayedSongs = allSongs.filter({ (song) -> Bool in
                return song.songName.lowercased().contains(keywords) || song.artistName.lowercased().contains(keywords)
            })
        }
        threadSafeReloadView()
    }
    
    func libraryChanged(notification: Notification) {
        guard let dict = notification.object as? [String: Any?] else { return }
        guard let song = dict["song"] as? Models.FirebaseSong else { return }
        guard let shouldAdd = dict["shouldAdd"] as? Bool else { return }
        if shouldAdd {
            // song wasn't in lib -- insert at first index
            let spotifySong = Models.SpotifySong(songName: song.songName,
                                                 artistName: song.artistName,
                                                 spotifyID: song.spotifyID,
                                                 duration: song.duration,
                                                 coverArtURL: song.coverArtURL)
            allSongs.insert(spotifySong, at: 0)
        } else {
            allSongs.remove(at: 0)    // song was already in lib -- remove it
        }
        
        displayedSongs = allSongs
        DispatchQueue.main.async {
            self.threadSafeReloadView()
        }
    }
    
    func loadSavedTracks() {
        SessionManager.executeWithToken { (token) in
            guard let token = token else { return }
            self.allSongs.removeAll()
            let url = "https://api.spotify.com/v1/me/tracks"
            let headers = [
                "Authorization": "Bearer " + token
            ]
            let params: Parameters = ["limit": 50, "offset": 0]
            Alamofire.request(url, parameters: params, headers: headers).responseJSON { response in
                do {
                    var serializedJSON = try JSONSerialization.jsonObject(with: response.data!, options: .mutableContainers) as! JSONStandard
                    if let items = serializedJSON["items"] as? [JSONStandard] {
                        for i in 0..<items.count {
                            let item = items[i]["track"]
                            let curr = item as! UnboxableDictionary
                            do {
                                let spotifySong: Models.SpotifySong = try unbox(dictionary: curr)
                                self.allSongs.append(spotifySong)
                            } catch {
                                print("error unboxing spotify song: ", error)
                            }
                        }
                        
                        // to make UI more responsive, display first 50 immediately
                        // then load the rest
                        self.displayedSongs = self.allSongs
                        DispatchQueue.main.async {
                            self.threadSafeReloadView()
                        }
                        self.recursiveLoadTracks(urlString: serializedJSON["next"] as? String, headers: headers)
                    }
                } catch {
                    print("error unboxing JSON")
                }
            }
        }
    }
    
    private func recursiveLoadTracks(urlString: String?, headers: HTTPHeaders) {
        if let urlString = urlString, let url = URL(string: urlString) {
            Alamofire.request(url, headers: headers).validate().responseJSON { response in
                do {
                    var serializedJSON = try JSONSerialization.jsonObject(with: response.data!, options: .mutableContainers) as! JSONStandard
                    if let items = serializedJSON["items"] as? [JSONStandard] {
                        objc_sync_enter(self.allSongs)
                        for item in items {
                            let curr = item["track"] as! UnboxableDictionary
                            do {
                                let spotifySong: Models.SpotifySong = try unbox(dictionary: curr)
                                self.allSongs.append(spotifySong)
                            } catch {
                                print("error unboxing spotify song: ", error)
                            }
                        }
                        objc_sync_exit(self.allSongs)
                        self.recursiveLoadTracks(urlString: serializedJSON["next"] as? String, headers: headers)
                    }
                } catch {
                    print("error unboxing JSON")
                }
            }
        } else {
            // url is nil -- all songs have been loaded, so update table on main thread
            self.displayedSongs = self.allSongs
            DispatchQueue.main.async {
                self.threadSafeReloadView()
            }
        }
    }

}
