//
//  MLNetworkTaskInfo.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

protocol MLNetworkTaskInfoDelegate: NSObjectProtocol {
    var taskState: MLNetworkTaskState { get }
    func resume(task: MLNetworkTaskInfo)
    func suspend(task: MLNetworkTaskInfo)
    func cancel(task: MLNetworkTaskInfo)
    func task(_ task: MLNetworkTaskInfo, progressMonitorDidChange isEnable: Bool)
}

class MLNetworkTaskInfo: NSObject, MLNetworkTask {
    
    let taskIdentifier: String
    let originRequest: URLRequest?
    var progress: ((Int64, Int64, Int64) -> Void)? {
        didSet {
            let oldIsEnable = oldValue != nil
            let isEnable = progress != nil
            if oldIsEnable != isEnable {
                delegate?.task(self, progressMonitorDidChange: progress != nil)
            }
        }
    }
    
    weak var delegate: MLNetworkTaskInfoDelegate?
    
    init(identifier: String, request: URLRequest?) {
        taskIdentifier = identifier
        originRequest = request
        super.init()
    }
    
    var state: MLNetworkTaskState { delegate?.taskState ?? .suspend }
    func resume() { delegate?.resume(task: self) }
    func suspend() { delegate?.suspend(task: self) }
    func cancel() { delegate?.cancel(task: self) }
}
