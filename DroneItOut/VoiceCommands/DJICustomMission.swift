//
//  DJICustomMission.swift
//  DroneItOut
//
//  Created by Daniel Nguyen on 10/2/17.
//  Copyright © 2017 DJI. All rights reserved.
//

import Foundation

class DJICustomMission
{
    var Id:Int!
    init(id: Int){
        self.Id = id
    }
    var description: String {
        return "{ID=\(Id)}"
    }
}

