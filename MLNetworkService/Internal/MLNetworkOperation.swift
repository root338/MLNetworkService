//
//  MLNetworkOperation.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

protocol MLNetworkOperationDelegate: NSObjectProtocol {
    func reset(operation: MLNetworkOperation)
    func moveToWaitQueue(operation: MLNetworkOperation)
    func operation(_ operation: MLNetworkOperation, didChange state: MLNetworkTaskState)
}

class MLNetworkOperation: Operation {
    
    weak var delegate: MLNetworkOperationDelegate?
    var taskIdentifier : Int { task.taskIdentifier }
    /// 开启进度监听
    var isEnableProgressMonitor: Bool { monitorProgressCount > 0 }
    
    let task: URLSessionTask
    private lazy var tasks = [MLNetworkTaskInfo]()
    private var resumeCount: Int = 0
    private var suspendCount: Int = 0
    private var monitorProgressCount: Int = 0
    private var monitorStateCount: Int = 0
    private var taskIndex: Int = 0
    
    required init(task: URLSessionTask) {
        self.task = task
        super.init()
    }
    
    private var lock = NSRecursiveLock()
    private(set) var state: MLNetworkTaskState = .suspend {
        didSet {
            lock.lock()
            defer { lock.unlock() }
            if state == oldValue, monitorStateCount == 0 { return }
            for task in tasks {
                guard let didChangeState = task.didChangeState,
                      task.state == state
                else { continue }
                didChangeState(state)
            }
        }
    }
    /// 挂起标识
    private var _isSuspend: Bool = true
    /// 开始过标识
    private var _isStarted: Bool = false
    private var _isReady: Bool = false
    private var _isFinished: Bool = false
    private var _isCancelled: Bool = false
    private var _isExecuting: Bool = false
    
    //MARK:- 临时处理
    private var resumeData: Data?
}
//MARK:- Public Method
extension MLNetworkOperation {
    func getNewTask() -> MLNetworkTask {
        lock.lock()
        defer { lock.unlock() }
        let task = MLNetworkTaskInfo(identifier:  "\(self.task.taskIdentifier)-\(taskIndex)")
        taskIndex += 1
        task.delegate = self
        tasks.append(task)
        return task
    }
    func getNewOperation(task: (URLSessionTask, Data?) -> URLSessionTask) -> Self {
        lock.lock()
        defer { lock.unlock() }
        let op = type(of: self).init(task: task(self.task, resumeData)) as MLNetworkOperation
        op.delegate = delegate
        for task in tasks {
            task.delegate = op
        }
        op.tasks.append(contentsOf: tasks)
        op.monitorProgressCount = monitorProgressCount
        op.monitorStateCount = monitorStateCount
        op.suspendCount = suspendCount
        op.resumeCount = resumeCount
        op.change(state: state)
//        op._isReady = _isReady
//        op._isFinished = _isFinished
//        op._isCancelled = _isCancelled
//        op._isExecuting = _isExecuting
        return op as! Self
    }
    
    @available(iOS, introduced: 2.0, deprecated: 11.0, message: "iOS 11 以后内部可以直接使用 URLSessionTask 下的 progress 属性")
    func didChangeProgress(didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        lock.lock()
        defer { lock.unlock() }
        for task in tasks {
            task.progress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }
}
//MARK:- Protocol
extension MLNetworkOperation: MLNetworkTaskInfoDelegate {
    func changeState(to toState: MLNetworkTaskState, from oldState: MLNetworkTaskState?) throws {
        lock.lock()
        defer { lock.unlock() }
        if state == .completed {
            throw MLNetworkTaskError.notSupportOperation(msg: "已完成的任务无法再执行操作")
        }
        if let fromState = oldState, fromState == toState { return }
        var count: (resume: Int, suspend: Int, cancel: Int) = (0,0,0)
        func changeCount(isNew: Bool) throws {
            if !isNew && oldState == nil { return }
            switch (isNew ? toState : oldState!) {
            case .ready:
                count.resume = isNew ? 1 : -1
            case .suspend:
                count.suspend = isNew ? 1 : -1
            case .cancel:
                count.cancel = isNew ? 1 : -1
            case .completed: fallthrough
            case .running:
                throw MLNetworkTaskError.notSupportOperation(msg: "不支持直接设置 \(toState)")
            }
        }
        try changeCount(isNew: true)
        try changeCount(isNew: false)
        resumeCount = resumeCount + count.resume - count.cancel
        suspendCount = suspendCount + count.suspend
        let state: MLNetworkTaskState = resumeCount > 0 ? .ready : (
            suspendCount > 0 ? .suspend : .cancel
        )
        if state == self.state { return }
        if state == .suspend && self.state != .suspend && _isStarted {
            /// 只有开始过的任务才执行真正的挂起操作
            suspend()
        }else {
            change(state: state)
        }
    }
    
    func task(_ task: MLNetworkTaskInfo, monitorProgress isEnable: Bool) {
//        var count = 0
//        for task in tasks {
//            count += (task.progress != nil ? 1 : 0)
//        }
        lock.lock()
        defer { lock.unlock() }
        // 在 MLNetworkTaskInfo 中只有状态变化时才回调
        monitorProgressCount += (isEnable ? 1 : 0)
    }
    func task(_ task: MLNetworkTaskInfo, monitorState isEnable: Bool) {
        lock.lock()
        defer { lock.unlock() }
        monitorStateCount += (isEnable ? 1 : 0)
    }
}

//MARK:- Status Control
extension MLNetworkOperation {
    override var isExecuting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isExecuting
    }
    override var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return super.isReady && _isReady
    }
    override var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }
    override var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isFinished
    }
    
    override func start() {
        lock.lock()
        defer { lock.unlock() }
        _isStarted = true
        if state != .ready { return }
        task.resume()
        change(state: .running)
    }
    func suspend() {
        cancel(isSuspend: true)
    }
    func downloadTaskFinish(result: Result<URL, Error>) {
        change(state: .completed)
    }
    
    override func cancel() {
        cancel(isSuspend: false)
    }
    
    private func cancel(isSuspend: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if state == .cancel || state == .completed { return }
        if isSuspend && state == .suspend { return }
//--------------------------------------------------------------
        // 注意 ！！！ 这边调用了下 父类 的 cancel 方法
        super.cancel()
//--------------------------------------------------------------
        if !isSuspend {
            task.cancel()
        }else {
            // 挂起时直接调用 cancel(byProducingResumeData:) 方法是因为 suspend() 方法会导致下载任务超时而失败
            if let task = self.task as? URLSessionDownloadTask {
                task.cancel {[weak self] (data) in
                    guard let weak = self else { return }
                    weak.resumeData = data
                    weak.change(state: isSuspend ? .suspend : .cancel)
                }
            }else {
                task.cancel()
                change(state: isSuspend ? .suspend : .cancel)
            }
        }
    }
}
//MARK:- Edit Private Value
private extension MLNetworkOperation {
    
    func isReady(for state: MLNetworkTaskState) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return super.isReady && resumeCount > 0 && state == .ready
    }
    func change(state: MLNetworkTaskState) {
        lock.lock()
        defer { lock.unlock() }
        if state == self.state { return }
        if state == .ready && _isCancelled && _isSuspend {
            // 恢复之前的下载时需要重新添加任务到队列
            self.state = .ready
            delegate?.reset(operation: self)
            return
        }
        let isReady = state == .running || state == .ready
        let operatioinIsReady = self.isReady(for: state)
        let isFinished = state == .completed || (state == .suspend && _isStarted)
        let isCancelled = state == .cancel || (state == .suspend && _isStarted)
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
        _isSuspend = state == .suspend
        _isReady = isReady
        _isFinished = isFinished
        _isCancelled = isCancelled
        _isExecuting = isExecuting
        
        if changeIsReady { didChangeValue(for: \.isReady) }
        if changeIsExecuting { didChangeValue(for: \.isExecuting) }
        if changeIsCancelled { didChangeValue(for: \.isCancelled) }
        if changeIsFinished { didChangeValue(for: \.isFinished) }
        
        delegate?.operation(self, didChange: state)
        if isCancelled && state == .suspend {
            delegate?.moveToWaitQueue(operation: self)
        }
    }
}
