//
//  LightsViewController.swift
//  DALI
//
//  Created by John Kotz on 9/17/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import DALI

class LightsViewController: UITableViewController {
	var groups: [DALILights.Group] = []
	
	override func viewWillAppear(_ animated: Bool) {
		DALILights.oberserveAll { (groups) in
			self.groups = groups.sorted(by: { (group1, group2) -> Bool in
				return group1.name > group2.name
			})
			
			self.groups.append(DALILights.Group.all)
			self.groups.append(DALILights.Group.pods)
			
			self.tableView.reloadData()
		}
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return groups.filter({ (group) -> Bool in
			if section == 0 {
				return !group.name.contains("pod")
			}else {
				return group.name.contains("pod")
			}
		}).count
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return groups.filter({ (group) -> Bool in
			return !group.name.contains("pod")
		}).count == 0 ? 1 : 2
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 0 {
			return nil
		}else {
			return "Pods"
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let group = groups.filter({ (group) -> Bool in
			if indexPath.section == 0 {
				return !group.name.contains("pod")
			}else {
				return group.name.contains("pod")
			}
		})[indexPath.row]
		
		let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
		cell.accessoryType = .disclosureIndicator
		
		cell.textLabel?.text = group.formattedName
		cell.detailTextLabel?.text = group.formattedScene ?? group.color
		
		if !group.isOn {
			cell.backgroundColor = #colorLiteral(red: 0.8896380067, green: 0.8840149045, blue: 0.8939549327, alpha: 1)
		}
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let group = groups.filter({ (group) -> Bool in
			if indexPath.section == 0 {
				return !group.name.contains("pod")
			}else {
				return group.name.contains("pod")
			}
		})[indexPath.row]
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let dest = segue.destination as? SetSceneViewController, let group = sender as? DALILights.Group {
			dest.scenes = group.scenes
			
			dest.title = "Set scene for \(group.formattedName)"
			dest.callback = { scene in
				group.set(scene: scene, callback: { (success, error) in
					if let _ = error {
					}
				})
			}
		}
	}
}
