//
//  MLNetworkResultInfo.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/14.
//

import Foundation

struct MLNetworkDownloadSuccessResultInfo: MLNetworkDownloadSuccessResult {
    let location: URL
    let response: URLResponse?
}
