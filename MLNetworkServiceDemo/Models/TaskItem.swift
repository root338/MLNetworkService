//
//  TaskItem.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import UIKit

class TaskItem: NSObject {
    let name: String
    var task: MLNetworkTask
    init(name: String, task: MLNetworkTask) {
        self.name = name
        self.task = task
        super.init()
    }
}
