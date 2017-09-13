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
import Firebase

class LoginViewController: UIViewController {

    @IBOutlet weak var loginButton: UIButton!
    let loginController: SpotifyLoginController = SpotifyLoginController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loginController.setSpotifyAppCredentials()
        
        //check if session is available everytime you launch app
        let userDefaults = UserDefaults.standard
        if let sessionObj = userDefaults.object(forKey: Constants.kSpotifySessionKey) { // session available
            let sessionDataObj = sessionObj as! Data
            let session = NSKeyedUnarchiver.unarchiveObject(with: sessionDataObj) as! SPTSession
            if !session.isValid() {
                // session is not valid so renew it
                SPTAuth.defaultInstance().renewSession(session, callback: { (error, renewedSession) in
                    if let session = renewedSession {
                        Current.accessToken = session.accessToken
                        self.fetchSpotifyUser()
                        SPTAuth.defaultInstance().session = session
                        let sessionData = NSKeyedArchiver.archivedData(withRootObject: session)
                        userDefaults.set(sessionData, forKey: Constants.kSpotifySessionKey)
                        userDefaults.synchronize()
                    }
                })
            } else {
                Current.accessToken = session.accessToken
                fetchSpotifyUser()
            }
        } else {
            loginButton.isHidden = false
        }
    }

    @IBAction func loginWithSpotify(_ sender: Any) {
        self.present(loginController, animated: true) {
            self.loginController.login() {
                self.loginButton.isHidden = true
                self.fetchSpotifyUser()
            }
        }
    }
    
    func fetchSpotifyUser() {
        // first retrieve user object from spotify server using access token
        print("Fetching user")
        
        let accessToken = Current.accessToken
        let headers: HTTPHeaders = ["Authorization": "Bearer " + accessToken]
        let url = Constants.kSpotifyBaseURL + Constants.kCurrentUserPath
        Alamofire.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers).validate().responseJSON {
            response in
            switch response.result {
            case .success:
                do {
                    let dictionary = response.result.value as! UnboxableDictionary
                    let spotifyUser: Models.SpotifyUser = try unbox(dictionary: dictionary)
                    FirebaseAPI.loginUser(spotifyUser: spotifyUser) { success in
                        if success {
                            DispatchQueue.main.async {
                                self.performSegue(withIdentifier: "loginSegue", sender: nil)
                            }
                        } else {
                            print("that's life in the city")
                        }
                    }
                    print("Fetched user")
                } catch {
                    print("error unboxing spotify user: ", error)
                }
            case .failure(let error):
                print(error)
            }
        };
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // set status bar text to white
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
}
