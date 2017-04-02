//
//  LoginViewController.swift
//  Juke
//
//  Created by Kojo Worai Osei on 4/1/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import UIKit
import Alamofire
import Unbox

class LoginViewController: UIViewController {

    @IBOutlet weak var loginButton: UIButton!
    let kClientID = "77d4489425fe464483f0934f99847c8b"
    let kCallbackURL = "juke1231://callback"
    var session:SPTSession!
    public static var currUser: Models.User? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loginButton.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.updateAfterFirstLogin), name: NSNotification.Name("loginSuccessful"), object: nil)
        
        let userDefaults = UserDefaults.standard
        
        //config SPTAuth default instance with tokenSwap and refresh
        SPTAuth.defaultInstance().tokenSwapURL = URL(string: "https://juketokenrefresh.herokuapp.com/swap")
        SPTAuth.defaultInstance().tokenRefreshURL = URL(string: "https://juketokenrefresh.herokuapp.com/refresh")
        
        //check if session is available everytime you launch app
        if let sessionObj = userDefaults.object(forKey: "SpotifySession") { // session available
            let sessionDataObj = sessionObj as! Data
            
            let session = NSKeyedUnarchiver.unarchiveObject(with: sessionDataObj) as! SPTSession
            
            if !session.isValid() {
                // session is not valid so renew it
                SPTAuth.defaultInstance().renewSession(SPTAuth.defaultInstance().session, callback: { (error, renewedSession) in
                    if let session = renewedSession {
                        SPTAuth.defaultInstance().session = session
                        let sessionData = NSKeyedArchiver.archivedData(withRootObject: session)
                        userDefaults.set(sessionData, forKey: "SpotifySession")
                        userDefaults.synchronize()
                        
                        self.session = renewedSession
                        //fetch user
                        self.fetchSpotifyUser(accessToken: session.accessToken)
                    }
                })
            } else {
                // session is valid. Hide login button and proceed
                loginButton.isHidden = false
                // fetch user or fire or whatever
                fetchSpotifyUser(accessToken: session.accessToken)
                
            }
        }
    }
    
    //if you are logging in for the first time and don't have a session that is going to be renewed
    func updateAfterFirstLogin() {
        loginButton.isHidden = true
        let userDefaults = UserDefaults.standard
        
        if let sessionObj = userDefaults.object(forKey: "SpotifySession") {
            let sessionDataObj = sessionObj as! Data
            let firstTimeSession = NSKeyedUnarchiver.unarchiveObject(with: sessionDataObj) as! SPTSession
            self.session = firstTimeSession
            //fetch user
            fetchSpotifyUser(accessToken: session.accessToken)
        }
        
    }

    @IBAction func loginWithSpotify(_ sender: Any) {
        let auth = SPTAuth.defaultInstance()!
        auth.clientID = kClientID
        auth.redirectURL = NSURL(string:kCallbackURL)! as URL
        auth.requestedScopes = [SPTAuthStreamingScope]
        let loginURL = auth.loginURL!
        
        UIApplication.shared.open(loginURL)
        
    }
    
    func fetchSpotifyUser(accessToken: String) {
        // first retrieve user object from spotify server using access token
        let headers: HTTPHeaders = ["Authorization": "Bearer " + accessToken]
        let url = ServerConstants.kSpotifyBaseURL + ServerConstants.kCurrentUserPath
        Alamofire.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers).validate().responseJSON {
            response in
            switch response.result {
            case .success:
                do {
                    let dictionary = response.result.value as! UnboxableDictionary
                    let spotifyUser: Models.SpotifyUser = try unbox(dictionary: dictionary)
                    self.addUserToJukeServer(spotifyUser: spotifyUser)
                } catch {
                    print("error unboxing spotify user: ", error)
                }
            case .failure(let error):
                print(error)
            }
        };
    }
    
    func addUserToJukeServer(spotifyUser: Models.SpotifyUser) {
        // create new user object in DB. if already exists with spotifyID, returns user object
        let url = ServerConstants.kJukeServerURL + ServerConstants.kAddUser
        let params: Parameters = [
            "spotifyID": spotifyUser.spotifyID,
            "username": spotifyUser.username,
            "imageURL": spotifyUser.imageURL
        ]
        Alamofire.request(url, method: .post, parameters: params).validate().responseJSON { response in
            switch response.result {
            case .success:
                do {
                    let unparsedJukeUser = response.result.value as! UnboxableDictionary
                    let user: Models.User = try unbox(dictionary: unparsedJukeUser)
                    //CurrentUser.currUser = user
                    LoginViewController.currUser = user
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "loginSegue", sender: nil)
                    }
                } catch {
                    print("Error unboxing user: ", error)
                }
            case .failure(let error):
                print("Error adding user to database: ", error)
            }
        };
    }

    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
