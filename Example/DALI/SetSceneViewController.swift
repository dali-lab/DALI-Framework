//
//  SetSceneViewController.swift
//  DALI
//
//  Created by John Kotz on 9/18/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

class SetSceneViewController: UITableViewController {
	var scenes: [String] = []
	var callback: ((String) -> Void)?
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return scenes.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
		
		cell.textLabel?.text = scenes[indexPath.row].capitalized
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let callback = callback {
			callback(scenes[indexPath.row])
		}
		self.dismiss(animated: true) { 
			
		}
	}
}
