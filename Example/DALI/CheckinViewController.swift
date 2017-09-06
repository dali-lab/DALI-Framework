//
//  CheckinViewController.swift
//  DALI
//
//  Created by John Kotz on 9/6/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import DALI

class CheckinViewController: UITableViewController {

	var members: [DALIMember] = []
	var observer: Observation?
	
    override func viewDidLoad() {
        super.viewDidLoad()
    }
	
	override func viewWillAppear(_ animated: Bool) {
		DALIEvent.getUpcoming { (event, error) in
			if let first = event?.first {
				self.observer = first.observeMembersCheckedIn(callback: { (members) in
					self.members = members
					
					DispatchQueue.main.async {
						self.tableView.reloadData()
					}
				})
			}
		}
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		observer?.stop()
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return members.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
		
		cell.textLabel?.text = members[indexPath.row].name
		
		return cell
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return self.observer != nil ? "Connected" : "Connecting..."
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
