//
//  TWTRUserCustom.swift
//  shinigami
//
//  Created by Nathan Chan on 5/31/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import SwiftyJSON

class TWTRUserCustom {
    var idStr: String = ""
    var name: String = ""
    var screenName: String = ""
    var location: String = ""
    var userDescription: String = ""
    var followersCount: Int = 0 // unused
    var followingCount: Int = 0 // friends_count
    var isVerified: Bool = false
    var profileImageNormalSizeUrl: String = ""
    var profileImageOriginalSizeUrl: String = ""
    var following: Bool = false // is the logged-in user following this user?
    
    init?(json: JSON) {
        guard
            let idStr = json["id_str"].string,
            let name = json["name"].string,
            let screenName = json["screen_name"].string,
            let location = json["location"].string,
            let description = json["description"].string,
            let followersCount = json["followers_count"].int,
            let followingCount = json["friends_count"].int,
            let isVerified = json["verified"].bool,
            let profileImageNormalSizeUrl = json["profile_image_url_https"].string
        else {
            return nil
        }
        
        self.idStr = idStr
        self.name = name
        self.screenName = screenName
        self.location = location
        self.userDescription = description
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.isVerified = isVerified
        self.profileImageNormalSizeUrl = profileImageNormalSizeUrl
        self.profileImageOriginalSizeUrl = profileImageNormalSizeUrl.replacingOccurrences(of: "_normal", with: "")
    }
}
