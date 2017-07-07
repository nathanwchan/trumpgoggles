//
//  TWTRList.swift
//  shinigami
//
//  Created by Nathan Chan on 6/13/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import SwiftyJSON
import TwitterKit

class TWTRList {
    var idStr: String = ""
    var name: String = ""
    var uri: String = ""
    var memberCount: Int = 0
    var createdAt: Date?
    var user: TWTRUserCustom?
    
    init?(json: JSON, user: TWTRUserCustom?) {
        guard
            let idStr = json["id_str"].string,
            let name = json["name"].string,
            let uri = json["uri"].string,
            let memberCount = json["member_count"].int,
            let createdAtStr = json["created_at"].string
            else {
                return nil
        }
        
        let formatter  = DateFormatter()
        formatter.dateFormat = "E MMM d HH:mm:ss Z yyyy"
        
        self.idStr = idStr
        self.name = name
        self.uri = uri
        self.memberCount = memberCount
        self.createdAt = formatter.date(from: createdAtStr) ?? Date()
        self.user = user
    }
}
