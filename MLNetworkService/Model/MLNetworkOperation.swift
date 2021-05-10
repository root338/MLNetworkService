//
//  MLNetworkOperation.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

protocol MLNetworkOperationDelegate: NSObjectProtocol {
    func didIsRead(operation: MLNetworkOperation) -> Bool
    func didStart(operation: MLNetworkOperation)
    func didCancel(operation: MLNetworkOperation, isSuspend: Bool)
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
    /// 是否存在队列中
    var isExistedQueue: Bool = true
    
    private let task: URLSessionTask
    private lazy var tasks = [MLNetworkTaskInfo]()
    private var resumeCount: UInt = 0 {
        didSet {
            let state: State = resumeCount > 0 ? .ready : (
                suspendCount > 0 ? .suspend : .cancel
            )
            if state == .suspend && self.state != .suspend {
                suspend()
            }else {
                change(state: state)
            }
        }
    }
    private var suspendCount: UInt = 0 {
        didSet {
            if suspendCount != oldValue {
                resumeCount -= 1
            }
        }
    }
    private var progressMonitorCount: Int = 0
    
    init(task: URLSessionTask) {
        self.task = task
        super.init()
    }
    
    deinit {
        
    }
    
    private var state: State = .suspend
    private var _isReady: Bool = false
    private var _isFinished: Bool = false
    private var _isCancelled: Bool = false
    private var _isExecuting: Bool = false
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
    func resume(task: MLNetworkTaskInfo) { resumeCount += 1 }
    func suspend(task: MLNetworkTaskInfo) { suspendCount += 1 }
    func cancel(task: MLNetworkTaskInfo) { resumeCount -= 1 }
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
    override var isExecuting: Bool { _isExecuting }
    override var isReady: Bool { super.isReady && _isReady }
    override var isCancelled: Bool { _isCancelled }
    override var isFinished: Bool { _isFinished }
    
    override func start() {
        let state = self.state
        if state == .running || state == .cancel || state == .completed { return }
        task.resume()
        change(state: .running)
        delegate?.didStart(operation: self)
    }
    func suspend() {
        cancel(isSuspend: true)
    }
    func finish(result: Result<URL, Error>) {
        change(state: .completed)
    }
    override func cancel() {
        cancel(isSuspend: false)
    }
    func cancel(isSuspend: Bool) {
        let state = self.state
        if state == .cancel || state == .completed { return }
        super.cancel()
        if !isSuspend {
            task.cancel()
        }else {
            task.suspend()
        }
        change(state: isSuspend ? .suspend : .cancel)
        delegate?.didCancel(operation: self, isSuspend: isSuspend)
    }
}

private extension MLNetworkOperation {
    
    func isReady(for state: State) -> Bool {
        return super.isReady && resumeCount > 0 && state == .ready
    }
    
    func change(state: State) {
        if state == self.state { return }
        let isReady = state == .running || state == .ready
        let operatioinIsReady = self.isReady(for: state)
        let isFinished = state == .completed || state == .suspend
        let isCancelled = state == .cancel || state == .suspend
        let isExecuting = state == .running
        
        let changeIsReady = operatioinIsReady != _isReady
        let changeIsExecuting = isExecuting != _isExecuting
        let changeIsCancelled = isCancelled != _isCancelled
        let changeIsFinished = isFinished != _isFinished
        
        if changeIsReady { willChangeValue(for: \.isReady) }
        if changeIsExecuting { willChangeValue(for: \.isExecuting) }
        if changeIsCancelled { willChangeValue(for: \.isCancelled) }
        if changeIsFinished { willChangeValue(for: \.isFinished) }
        
        self.state = state
        _isReady = isReady
        _isFinished = isFinished
        _isCancelled = isCancelled
        _isExecuting = isExecuting
        
        if changeIsReady { didChangeValue(for: \.isReady) }
        if changeIsExecuting { didChangeValue(for: \.isExecuting) }
        if changeIsCancelled { didChangeValue(for: \.isCancelled) }
        if changeIsFinished { didChangeValue(for: \.isFinished) }
    }
}
