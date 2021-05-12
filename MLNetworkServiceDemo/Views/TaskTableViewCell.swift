//
//  TaskTableViewCell.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import UIKit

class TaskTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var downloadSpeedLabel: UILabel!
    @IBOutlet weak var actionBtn: UIButton!
    
    var didChangeDownloadState: (() -> Void)?
    
    @IBAction func handleDownload(_ sender: UIButton) {
        didChangeDownloadState?()
    }
}
