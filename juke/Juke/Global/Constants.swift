//
//  Constants.swift
//  Juke
//
//  Created by Conner Smith on 3/9/17.
//  Copyright © 2017 csmith. All rights reserved.
//

import Foundation

public class Constants {
    
    static let kSpotifyBaseURL = "https://api.spotify.com/v1/"
    static let kSpotifySearchURL = Constants.kSpotifyBaseURL + "search/"
    static let kSpotifyTrackDataURL = Constants.kSpotifyBaseURL + "tracks/"
    static let kSpotifyMyPlaylistsURL = Constants.kSpotifyBaseURL + "me/playlists"
    static let kCurrentUserPath = "me"
    static let kAddSongByIDPath = "me/tracks?ids="
    static let kDeleteSongByIDPath = "me/tracks?ids="
    static let kContainsSongPath = "me/tracks/contains?ids="
    static let kSpotifySessionKey = "SpotifySession"    // key session is stored as in user defaults
    static let kSpotifyTokenRefreshIntervalSeconds: TimeInterval = 40 * 60 // every 40 minutes
    static let kRecentlyPlayedURL = Constants.kSpotifyBaseURL + "me/player/recently-played"
    
    #if DEVELOPMENT
        static let kSendNotificationsURL = "https://us-central1-juke-9fbd6.cloudfunctions.net/sendNotification"
        static let kClientID = "77d4489425fe464483f0934f99847c8b"
        static let kCallbackURL = "juke1231://callback"
        static let kTokenSwapURL = "https://juketokenrefresh.herokuapp.com/swap"
        static let kTokenRefreshURL = "https://juketokenrefresh.herokuapp.com/refresh"
    #else
        static let kSendNotificationsURL = "https://us-central1-juke-production-72b80.cloudfunctions.net/sendNotification"
        static let kClientID = "1a1c61503dec43c8844713d21486fcce"
        static let kCallbackURL = "jukeproduction://callback"
        static let kTokenSwapURL = "https://jukeproduction.herokuapp.com/swap"
        static let kTokenRefreshURL = "https://jukeproduction.herokuapp.com/refresh"
    #endif
    
}
