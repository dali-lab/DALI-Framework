//
//  ViewController.swift
//  DALI
//
//  Created by johnlev on 08/09/2017.
//  Copyright (c) 2017 johnlev. All rights reserved.
//

import UIKit
import DALI

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var label: UILabel!
	
	var members: [DALIMember] = []
	
	var sharedObserver: Observation!
	var timObserver: Observation!

    override func viewDidLoad() {
        super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self
        // Do any additional setup after loading the view, typically from a nib.
    }
	
	override func viewWillAppear(_ animated: Bool) {
		sharedObserver = DALILocation.Shared.observe { (members, error) in
			if let members = members {
				self.members = members
				DispatchQueue.main.async {
					self.tableView.reloadData()
				}
			}
			
			if let error = error {
				print(error)
			}
		}
		
		timObserver = DALILocation.Tim.observe { (tim, error) in
			if let tim = tim {
				DispatchQueue.main.async {
					self.label.text = "Tim inDALI: \(tim.inDALI) inOffice: \(tim.inOffice)"
				}
			}
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		sharedObserver.stop()
		timObserver.stop()
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return members.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
		
		cell.textLabel?.text = members[indexPath.row].name
		
		return cell
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

