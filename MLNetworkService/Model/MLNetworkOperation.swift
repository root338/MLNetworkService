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
            change(state: resumeCount > 0 ? .ready : (isSuspend ? .suspend : .cancel))
        }
    }
    /// 是否挂起，暂停
    private var isSuspend: Bool { resumeCount == 0 && suspendCount > 0 }
    private var suspendCount: UInt = 0 {
        didSet {
            if suspendCount != oldValue {
                resumeCount -= 1
            }
        }
    }
    private var state: State = .suspend {
        willSet {
            if state == newValue { return }
            if newValue == .ready || ready(state: state) != ready(state: newValue) {
                self.willChangeValue(for: \MLNetworkOperation.isReady)
            }
            switch newValue {
            case .running:
                self.willChangeValue(for: \MLNetworkOperation.isExecuting)
            case .suspend:
                self.willChangeValue(for: \MLNetworkOperation.isExecuting)
            case .cancel:
                self.willChangeValue(for: \MLNetworkOperation.isCancelled)
            case .completed:
                self.willChangeValue(for: \MLNetworkOperation.isFinished)
            case .ready:break
            }
            
        }
        didSet {
            if state == oldValue { return }
            if state == .ready || ready(state: state) != ready(state: oldValue) {
                self.didChangeValue(for: \MLNetworkOperation.isReady)
            }
            switch state {
            case .running:
                self.didChangeValue(for: \MLNetworkOperation.isExecuting)
            case .suspend:
                self.didChangeValue(for: \MLNetworkOperation.isExecuting)
            case .cancel:
                self.didChangeValue(for: \MLNetworkOperation.isCancelled)
            case .completed:
                self.didChangeValue(for: \MLNetworkOperation.isFinished)
            case .ready: break
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
        if state == .completed { return }
        resumeCount += 1
    }
    func suspend(task: MLNetworkTaskInfo) {
        if state == .completed { return }
        suspendCount += 1
    }
    func cancel(task: MLNetworkTaskInfo) {
        if state == .completed { return }
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
    
    override var isExecuting: Bool { return state == .running }
    override var isReady: Bool { return super.isReady && (state != .suspend || resumeCount > 0) }
    override var isCancelled: Bool { return state == .cancel }
    override var isFinished: Bool { return state == .completed }
    
    override func start() {
        if !isReady { return }
        state = .running
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

private extension MLNetworkOperation {
    
    func change(state: State) {
        if (state == self.state) { return }
        self.state = state
        switch state {
        case .ready:
            break
//            delegate?.ready(operation: self)
        case .running: break
        case .suspend:
            suspend()
        case .cancel:
            cancel()
        case .completed: break
        }
    }
    func ready(state: State) -> Bool {
        return super.isReady && (state != .suspend || resumeCount > 0)
    }
}
