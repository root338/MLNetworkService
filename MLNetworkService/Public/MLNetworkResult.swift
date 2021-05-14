//
//  MLNetworkResult.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/14.
//

import Foundation

public typealias MLNetworkDownloadResult = Result<MLNetworkDownloadSuccessResult, Error>
public typealias MLNetworkDownloadCompletion = (MLNetworkDownloadResult) -> Void

public protocol MLNetworkDownloadSuccessResult {
    var location: URL { get }
    var response: URLResponse? { get }
}

