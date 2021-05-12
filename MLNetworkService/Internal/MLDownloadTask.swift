//
//  MLDownloadTask.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/11.
//

import Foundation

class MLDownloadTask: NSObject, MLTask {
    typealias Task = URLSessionDownloadTask
    private(set) var task: Task
    
    required init(task: Task) {
        self.task = task
        super.init()
    }
}
