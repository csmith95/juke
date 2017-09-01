//
//  SpotifyLoginController.swift
//  Juke
//
//  Created by Conner Smith on 8/30/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import UIKit

class SpotifyLoginController: UIViewController, UIWebViewDelegate {
    
    let webView: UIWebView = UIWebView(frame: CGRect.zero)
    let kClientID = "77d4489425fe464483f0934f99847c8b"
    let kCallbackURL = URL(string:"juke1231://callback")!
    let kTokenSwapURL = URL(string: "https://juketokenrefresh.herokuapp.com/swap")!
    var completion: ()->Void = { }
    
    override func loadView() {
        super.loadView()
        self.webView.frame = self.view.bounds
        self.webView.isUserInteractionEnabled = true
        self.view = self.webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.webView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(loginSuccessful), name: NSNotification.Name("loginSuccessful"), object: nil)
    }
    
    func login(completion: @escaping(()->Void)) {
        self.completion = completion
        let auth = SPTAuth.defaultInstance()!
        auth.clientID = kClientID
        auth.redirectURL = kCallbackURL
        auth.tokenSwapURL = kTokenSwapURL
        auth.tokenRefreshURL = URL(string: "https://juketokenrefresh.herokuapp.com/refresh")
        auth.requestedScopes = [SPTAuthStreamingScope, SPTAuthUserLibraryReadScope, SPTAuthUserReadPrivateScope, SPTAuthUserLibraryModifyScope]
        let loginURL = SPTAuth.defaultInstance().spotifyWebAuthenticationURL()!
        let request = URLRequest(url: loginURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        self.webView.loadRequest(request)
    }
    
    func loginSuccessful() {
        self.dismiss(animated: true) {
            self.completion()
        }
    }
    
}