//
//  StreamController.swift
//  Juke
//
//  Created by Conner Smith on 2/23/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import UIKit
import Alamofire
import Unbox
import KYCircularProgress
import AlamofireImage

class MyStreamController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var navBarTitle: String? {
        get {
            return self.navigationItem.title
        }
        set (newValue) {
            self.navigationItem.title = newValue
        }
    }
    
    @IBOutlet var splitButton: UIButton!
    @IBOutlet var onlineButton: UIButton!
    @IBOutlet var circularProgressFrame: UIView!
    @IBOutlet var coverArtImage: UIImageView!
    @IBOutlet var barButton: UIBarButtonItem!
    @IBOutlet var currTimeLabel: UILabel!
    @IBOutlet var currentlyPlayingArtistLabel: UILabel!
    @IBOutlet var currentlyPlayingLabel: UILabel!
    @IBOutlet var currentlyPlayingView: UIView!
    @IBOutlet var tableView: UITableView!
    let jamsPlayer = JamsPlayer.shared
    let socketManager = SocketManager.sharedInstance
    @IBOutlet var listenButton: UIButton!
    var circularProgress = KYCircularProgress()
    var animationTimer = Timer()
    
    @IBAction func toggleListening(_ sender: AnyObject) {
        if CurrentUser.currStream.songs.count == 0 {
            return
        }
        
        let song = CurrentUser.currStream.songs[0]
        let newPlayStatus = !listenButton.isSelected
        listenButton.isSelected = newPlayStatus
        if CurrentUser.currStream.owner.spotifyID == CurrentUser.currUser.spotifyID {
            socketManager.songPlayStatusChanged(streamID: CurrentUser.currStream.streamID, progress: song.progress, isPlaying: newPlayStatus)
            CurrentUser.currStream.isPlaying = newPlayStatus
        }
        
        setSong(play: newPlayStatus && CurrentUser.currStream.isPlaying)
    }
    
    @IBAction func toggleOnlineStatus(_ sender: AnyObject) {
        let newOnlineStatus = !onlineButton.isSelected
        onlineButton.isSelected = newOnlineStatus
        let url = ServerConstants.kJukeServerURL + ServerConstants.kChangeOnlineStatus
        let params: Parameters = ["streamID": CurrentUser.currStream.streamID, "isLive": newOnlineStatus]
        Alamofire.request(url, method: .post, parameters: params).validate().responseJSON { response in
            switch response.result {
            case .success:
                do {
                    let unparsedStream = response.result.value as! UnboxableDictionary
                    let stream: Models.Stream = try unbox(dictionary: unparsedStream)
                    CurrentUser.currStream = stream
                } catch {
                    print("error unboxing new stream after changing online status: ", error)
                }
            case .failure(let error):
                print("error changing live status: ", error)
            }
        }
    }
   
    @IBAction func splitButtonPressed(_ sender: AnyObject) {
        socketManager.splitFromStream(userID: CurrentUser.currUser.id);
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        NotificationCenter.default.addObserver(self, selector: #selector(MyStreamController.songFinished), name: Notification.Name("songFinished"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyStreamController.songPositionChanged), name: Notification.Name("songPositionChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyStreamController.syncPositionWithOwner), name: Notification.Name("syncPositionWithOwner"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyStreamController.refreshMyStream), name: Notification.Name("refreshMyStream"), object: nil)
        currentlyPlayingView.layer.cornerRadius = 10;
        currentlyPlayingView.layer.masksToBounds = true;
        currentlyPlayingView.layer.borderColor = UIColor.gray.cgColor;
        currentlyPlayingView.layer.borderWidth = 0.5;
        currentlyPlayingView.layer.contentsScale = UIScreen.main.scale;
        currentlyPlayingView.layer.shadowColor = UIColor.black.cgColor;
        currentlyPlayingView.layer.shadowRadius = 5.0;
        currentlyPlayingView.layer.shadowOpacity = 0.5;
        currentlyPlayingView.layer.masksToBounds = false;
        currentlyPlayingView.clipsToBounds = false;
        self.circularProgress = KYCircularProgress(frame: self.circularProgressFrame.bounds)
        self.circularProgress.startAngle =  -1 * M_PI_2
        self.circularProgress.endAngle = -1 * M_PI_2 + 2*M_PI
        self.circularProgress.lineWidth = 2.0
        self.circularProgress.colors = [.blue, .yellow, .red]
        self.circularProgressFrame.addSubview(self.circularProgress)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navBarTitle = "My Jam"
        fetchMyStream();
    }
    
    private func setUpControlButtons() {
        if (CurrentUser.currStream.owner.spotifyID == CurrentUser.currUser.spotifyID) {
            // controls for the owner
            listenButton.setImage(UIImage(named: "play.png"), for: .normal)
            listenButton.setImage(UIImage(named: "pause.png"), for: .selected)
            // only let host toggle online/offline
            onlineButton.setImage(UIImage(named: "online.png"), for: .normal)
            onlineButton.setImage(UIImage(named: "offline.png"), for: .selected)
            onlineButton.isSelected = CurrentUser.currStream.isLive
            // allow host to split if more than 1 member
            splitButton.isHidden = (CurrentUser.currStream.members.count == 1)
            // **** TODO: allow host to clear or skip songs ****
        } else {
            onlineButton.isHidden = true
            listenButton.setImage(UIImage(named: "listening.png"), for: .normal)
            listenButton.setImage(UIImage(named: "mute.png"), for: .selected)
        }
    }
    
    private func fetchMyStream() {
        // fetch stream for user. if not tuned in, creates and returns an offline stream by default
        let url = ServerConstants.kJukeServerURL + ServerConstants.kFetchStream
        let params: Parameters = ["ownerSpotifyID": CurrentUser.currUser.spotifyID]
        Alamofire.request(url, method: .get, parameters: params).validate().responseJSON { response in
            switch response.result {
            case .success:
                do {
                    let unparsedStream = response.result.value as! UnboxableDictionary
                    let stream: Models.Stream = try unbox(dictionary: unparsedStream)
                    CurrentUser.currStream = stream
                    CurrentUser.fetched = true
                    DispatchQueue.main.async {
                        self.setUpControlButtons()
                        self.tableView.reloadData()
                        self.loadTopSong()
                    }
                    self.socketManager.joinSocketRoom(streamID: CurrentUser.currStream!.streamID, visitor: false)
                } catch {
                    print("Error unboxing stream: ", error)
                }
                
            case .failure(let error):
                print("Error fetching stream: ", error)
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 0    // hide first row -- should be currently playing track
        }
        return 40
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

//    // MARK: - Table view data source
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if (CurrentUser.fetched == false) {
            return 0
        }
        return CurrentUser.currStream.songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let song = CurrentUser.currStream!.songs[indexPath.row]
        if indexPath.row == 0 {
            // place first song in the currentlyPlayingLabel
            self.currentlyPlayingLabel.text = song.songName
            self.currentlyPlayingArtistLabel.text = song.artistName
        }
        
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath) as! SongTableViewCell
        cell.songName.text = song.songName
        cell.artist.text = song.artistName
        return cell
    }
    
    private func timeIntervalToString(interval: TimeInterval) -> String {
        let ti = NSInteger(interval)
        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        return NSString(format: "%0.2d:%0.2d", minutes, seconds) as String
    }
    
    func syncPositionWithOwner(notification: NSNotification) {
        if CurrentUser.currStream == nil || CurrentUser.currStream!.songs.count == 0 {
            return
        }
        
        if CurrentUser.currUser?.spotifyID == CurrentUser.currStream!.owner.spotifyID {
            return  // owner is already synced with device
        }
        
        if let data = notification.object as? NSDictionary {
            if let eventString = data["event"] as? String {
                switch eventString {
                case "playStatusChanged":
                    let isPlaying = data["isPlaying"] as! Bool
                    CurrentUser.currStream!.isPlaying = isPlaying
                    let progress = data["progress"] as! Double
                    CurrentUser.currStream?.songs[0].progress = progress
                    updateSlider(song: CurrentUser.currStream!.songs[0])
                    setSong(play: isPlaying && listenButton.isSelected)
                default:
                    print("Received unrecognized ownerSongStatusChanged event: ", eventString);
                }
            }
        }
    }
    
    func songPositionChanged(notification: NSNotification) {
        if CurrentUser.currStream == nil || CurrentUser.currStream!.songs.count == 0 {
            return
        }
        
        let stream = CurrentUser.currStream!
        let songs = stream.songs
        let song = songs[0]
        if let data = notification.object as? NSDictionary {
            let progress = data["progress"] as! Double
            CurrentUser.currStream?.songs[0].progress = progress
            // update progress in db if current user is playlist owner
            if CurrentUser.currUser?.spotifyID == stream.owner.spotifyID {
                socketManager.songPositionChanged(streamID: stream.streamID, songID: song.id, position: progress)
            }
            
            // update slider
            updateSlider(song: song)
        }
    }
    
    private func updateSlider(song: Models.Song) {
        let normalizedProgress = song.progress / song.duration
        self.circularProgress.progress = normalizedProgress
        self.circularProgress.set(progress: normalizedProgress, duration: 0.25)
        self.currTimeLabel.text = self.timeIntervalToString(interval: song.progress/1000)
    }
    
    func songFinished() {
        CurrentUser.currStream?.songs.remove(at: 0)
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.circularProgress.progress = 0.0
        }
        
        if CurrentUser.currUser?.spotifyID != CurrentUser.currStream?.owner.spotifyID {
            return; // if you are not the owner, don't post to DB. let owner's device manage DB
        }
        
        let stream = CurrentUser.currStream!
        let params: Parameters = ["streamID": stream.streamID]
        Alamofire.request(ServerConstants.kJukeServerURL + ServerConstants.kPopSong, method: .post, parameters: params).responseJSON { response in
            switch response.result {
            case .success:
                DispatchQueue.main.async {
                    self.loadTopSong()
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    public func setSong(play: Bool) {
        self.jamsPlayer.setPlayStatus(shouldPlay: play, song: CurrentUser.currStream.songs[0])
        if CurrentUser.currUser.spotifyID != CurrentUser.currStream.owner.spotifyID {
            setTimer(run: !play && CurrentUser.currStream.isPlaying)
        }
    }
    
    private func setTimer(run: Bool) {
        DispatchQueue.main.async {
            
            if CurrentUser.currStream.owner.spotifyID == CurrentUser.currUser.spotifyID {
                return  // if owner, don't use timer at all
            }
            
            if (run) {
                if !self.animationTimer.isValid {
                    self.animationTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateAnimationProgress), userInfo: nil, repeats: true)
                }
            } else {
                if self.animationTimer.isValid {
                    self.animationTimer.invalidate()
                }
            }
        }
    }
    
    func updateAnimationProgress() {
        let song = CurrentUser.currStream.songs[0]
        let newProgress = song.progress + 1000
        updateSlider(song: CurrentUser.currStream.songs[0])
        if abs(newProgress - song.duration) < 2000 {
            songFinished()  // force pop song based on timer
        }
    }
    
    private func loadTopSong() {
        let songs = CurrentUser.currStream.songs
        if songs.count > 0 {
            let song = songs[0]
            self.coverArtImage.af_setImage(withURL: URL(string: song.coverArtURL)!, placeholderImage: nil, filter: CircleFilter())
            self.updateSlider(song: song)
            
            if self.jamsPlayer.isPlaying(song: song) {
                listenButton.isSelected = true  // if already playing, let it play
            } else {
                setSong(play: listenButton.isSelected && CurrentUser.currStream.isPlaying)
            }
        } else {
            // **** TODO: no songs left -- display custom UI ****
            
        }
    }
    
    func refreshMyStream(notification: NSNotification) {
        do {
            if let unparsedStream = notification.object as? UnboxableDictionary {
                CurrentUser.currStream = try unbox(dictionary: unparsedStream)
                CurrentUser.currUser.tunedInto = stream.streamID;
                DispatchQueue.main.async {
                    self.loadTopSong()
                    self.tableView.reloadData()
                }
            }
        } catch {
            print("error unboxing new stream: ", error)
        }
    }
}
