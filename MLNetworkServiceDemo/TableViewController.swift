//
//  TableViewController.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import UIKit

class TableViewController: UITableViewController {
    
    lazy var taskList: [TaskItem] = {
        return [
            TaskItem(name: "任务1", task: try! service.addDownloadTask(url: URL(string: "https://dl.motrix.app/release/Motrix-1.5.15.dmg")!)),
            TaskItem(name: "任务2", task: try! service.addDownloadTask(url: URL(string: "https://dl.motrix.app/release/Motrix-1.5.15.dmg")!)),
            TaskItem(name: "任务3", task: try! service.addDownloadTask(url: URL(string: "https://download.jetbrains.com.cn/idea/ideaIU-2021.1.1.dmg")!)),
            TaskItem(name: "任务4", task: try! service.addDownloadTask(url: URL(string: "https://download.jetbrains.com.cn/idea/ideaIU-2021.1.1.dmg")!)),
        ]
    }()
    lazy var service = MLNetworkService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return taskList.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "TaskTableViewCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as! TaskTableViewCell
        let item = taskList[indexPath.row]
        var task = item.task
        func changeButtonTitle(state: MLNetworkTaskState) {
            DispatchQueue.main.async {
                let title: String
                switch state {
                case .ready:
                    title = "等待下载中"
                case .running:
                    title = "正在下载"
                case .suspend:
                    title = "已暂停"
                case .cancel:
                    title = "已取消"
                case .completed:
                    title = "已完成"
                }
                cell.actionBtn.setTitle(title, for: .normal)
            }
        }
        task.progress = {
            (bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) in
            DispatchQueue.main.async {
                cell.downloadSpeedLabel?.text = "\(bytesWritten / 1024) kB"
                cell.progressView.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            }
        }
        task.didChangeState = {
            changeButtonTitle(state: $0)
        }
        cell.didChangeDownloadState = {
            switch task.state {
            case .ready: fallthrough
            case .running:
                try? task.suspend()
            case .suspend:
                try? task.resume()
            case .cancel: break
            case .completed:break
            }
        }
        cell.nameLabel?.text = item.name
        changeButtonTitle(state: task.state)
        
        return cell
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
