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
    
    var didChangeDownloadState: ((Bool) -> Void)?
    
    @IBAction func handleDownload(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        didChangeDownloadState?(sender.isSelected)
    }
}
