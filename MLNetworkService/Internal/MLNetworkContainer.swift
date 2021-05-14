//
//  MLNetworkContainer.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/12.
//

import Foundation

class MLNetworkContainer: NSObject, MLNetworkManager {
    let name: String?
    private lazy var session: URLSession = {
        let session = URLSession(configuration: .background(withIdentifier: "com.MLNetworkService\(name != nil ? ("." + name!) : "").download"), delegate: self, delegateQueue: nil)
        seesionConfiguration = nil
        return session
    }()
    private lazy var operationQueue: _OperationQueue = {
        let queue = _OperationQueue()
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    private lazy var runningOperationSet: [Int: MLNetworkOperation] = [:]
    /// 临时保存已开始并挂起的任务的集合，在下次任务开始时重新构建任务并添加到任务队列中
    private lazy var waitOperationSet: [Int: MLNetworkOperation] = [:]
    private var seesionConfiguration: (() -> (URLSessionConfiguration))?
    
    init(name: String? = nil, seesionConfiguration: (() -> (URLSessionConfiguration))? = nil) {
        self.name = name
        super.init()
    }
}

extension MLNetworkContainer {
    /// 添加下载任务，必须调用 resume 才开始任务
    func addDownloadTask(url: URL, completion: MLNetworkDownloadCompletion? = nil) -> MLNetworkDownloadTask {
        let task = session.downloadTask(with: url)
        let opertion = MLNetworkOperation(task: task)
        opertion.delegate = self
        operationQueue.addOperation(opertion)
        return opertion.getNewTask()
    }
    func addDownloadTaskAndResume(url: URL, completion: MLNetworkDownloadCompletion? = nil) -> MLNetworkDownloadTask {
        let task = session.downloadTask(with: url)
        let opertion = MLNetworkOperation(task: task)
        opertion.delegate = self
        let downloadTask = opertion.getNewTask()
        try? downloadTask.resume()
        return downloadTask
    }
    
}

extension MLNetworkContainer {
    func configuration(queue: ((MLNetworkQueue) -> Void)? = nil, manager: ((MLNetworkManager) -> Void)? = nil) {
        if let manager = manager {
            manager(self)
        }
        if let queue = queue {
            queue(operationQueue)
        }
    }
}

extension MLNetworkContainer: URLSessionDownloadDelegate {
    //MARK:- URLSessionTaskDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        print("\(task) 下载失败 \(error.localizedDescription)")
        guard let operation = runningOperationSet[task.taskIdentifier] else { return }
        operation.downloadTaskFinish(result: .failure(error))
    }
    
    //MARK:- URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let operation = runningOperationSet[downloadTask.taskIdentifier] else { return }
        operation.downloadTaskFinish(
            result: .success(
                MLNetworkDownloadSuccessResultInfo(
                    location: location, response: downloadTask.response
                )))
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        if let operation = runningOperationSet[downloadTask.taskIdentifier],
           operation.isEnableProgressMonitor {
            operation.didChangeProgress(didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("")
    }
}

extension MLNetworkContainer: MLNetworkOperationDelegate {
    //MARK:- MLNetworkOperationDelegate
    func reset(operation: MLNetworkOperation) {
        let op = operation.getNewOperation { (task, data) -> URLSessionTask in
            if let data = data {
                return session.downloadTask(withResumeData: data)
            }
            return session.downloadTask(with: task.originalRequest!)
        }
        operationQueue.addOperation(op)
        waitOperationSet.removeValue(forKey: operation.taskIdentifier)
    }
    func moveToWaitQueue(operation: MLNetworkOperation) {
        waitOperationSet[operation.taskIdentifier] = operation
    }
    func operation(_ operation: MLNetworkOperation, didChange state: MLNetworkTaskState) {
        switch state {
        case .running:
            runningOperationSet[operation.taskIdentifier] = operation
        case .suspend:fallthrough
        case .cancel: fallthrough
        case .completed:
            runningOperationSet.removeValue(forKey: operation.taskIdentifier)
        case .ready: break
        }
    }
}

fileprivate class _OperationQueue: OperationQueue, MLNetworkQueue {}
