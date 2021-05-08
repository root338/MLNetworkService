//
//  MLNetworkOperation.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

protocol MLNetworkOperationDelegate: NSObjectProtocol {
    func ready(operation: MLNetworkOperation)
    func didStart(operation: MLNetworkOperation)
    func didCancel(operation: MLNetworkOperation)
}

class MLNetworkOperation: Operation {
    
    enum State {
        case ready
        case running
        case suspend
        case cancel
        case completed
    }
    
    weak var delegate: MLNetworkOperationDelegate?
    var taskIdentifier : Int { task.taskIdentifier }
    /// 开启进度监听
    var isEnableProgressMonitor: Bool { progressMonitorCount > 0 }
    
    private let task: URLSessionTask
    private lazy var tasks = [MLNetworkTask]()
    private var resumeCount: UInt = 0 {
        didSet {
            if state == .completed { return }
            state = resumeCount > 0 ? .ready : (isSuspend ? .suspend : .cancel)
        }
    }
    /// 是否挂起，暂停
    private var isSuspend: Bool { suspendCount == 0 }
    private var suspendCount: UInt = 0 {
        didSet {
            if suspendCount != oldValue {
                resumeCount -= 1
            }
        }
    }
    private var state: State = .suspend {
        didSet {
            if (state == oldValue) { return }
            switch state {
            case .ready:
                delegate?.ready(operation: self)
            case .running: break
            case .suspend:
                suspend()
            case .cancel:
                cancel()
            case .completed: break
            }
        }
    }
    private var progressMonitorCount: Int = 0
    
    init(task: URLSessionTask) {
        self.task = task
        super.init()
    }
}

extension MLNetworkOperation {
    
    func getNewTask() -> MLNetworkTask {
        let task = MLNetworkTaskInfo(identifier: "\(self.task.taskIdentifier)-\(tasks.count)", request: self.task.originalRequest)
        task.delegate = self
        tasks.append(task)
        return task
    }
    
    @available(iOS, introduced: 2.0, deprecated: 11.0, message: "iOS 11 以后内部可以直接使用 URLSessionTask 下的 progress 属性")
    func didChangeProgress(didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        for task in tasks {
            task.progress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }
}

extension MLNetworkOperation: MLNetworkTaskInfoDelegate {
    var taskState: MLNetworkTaskState {
        switch state {
        case .ready: return .suspend
        case .running: return .running
        case .suspend: return .suspend
        case .cancel: return .cancel
        case .completed: return .completed
        }
    }
    func resume(task: MLNetworkTaskInfo) {
        resumeCount += 1
    }
    func suspend(task: MLNetworkTaskInfo) {
        suspendCount += 1
    }
    func cancel(task: MLNetworkTaskInfo) {
        resumeCount -= 1
    }
    func task(_ task: MLNetworkTaskInfo, progressMonitorDidChange isEnable: Bool) {
//        var count = 0
//        for task in tasks {
//            count += (task.progress != nil ? 1 : 0)
//        }
        // 在 MLNetworkTaskInfo 中只有状态变化时才回调
        progressMonitorCount += (isEnable ? 1 : 0)
    }
}
//MARK:- Status Control
extension MLNetworkOperation {
    
    override var isCancelled: Bool { return state == .cancel || task.state == .canceling }
    override var isFinished: Bool { return task.state == .completed }
    
    override func start() {
        if state != .ready { return }
        let state = task.state
        if state == .canceling || state == .completed || state == .running
            || !isReady {
            return
        }
        task.resume()
        delegate?.didStart(operation: self)
    }
    
    func suspend() {
        if !isSuspend { return }
        if task.state != .running { return }
        task.suspend()
    }
    
    override func cancel() {
        let state = task.state
        if state != .running {
            return
        }
        task.cancel()
        delegate?.didCancel(operation: self)
    }
    
}
