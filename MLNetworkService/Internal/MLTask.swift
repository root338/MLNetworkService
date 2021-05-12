//
//  MLTask.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/11.
//

import Foundation

protocol MLTask {
    associatedtype Task: URLSessionTask
    var task: Task { get }
    
    init(task: Task)
}

extension MLTask {
    
}
