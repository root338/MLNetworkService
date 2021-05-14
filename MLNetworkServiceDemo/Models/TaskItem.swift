//
//  TaskItem.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import UIKit

class TaskItem: NSObject {
    let name: String
    var task: MLNetworkDownloadTask
    init(name: String, task: MLNetworkDownloadTask) {
        self.name = name
        self.task = task
        super.init()
    }
}
