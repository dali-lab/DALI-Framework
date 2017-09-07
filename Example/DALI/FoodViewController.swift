//
//  FoodViewController.swift
//  DALI
//
//  Created by John Kotz on 9/6/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import DALI

class FoodViewController: UIViewController {
	@IBOutlet weak var foodTextField: UITextField!
	@IBOutlet weak var foodLabel: UILabel!
	@IBOutlet weak var connectionLabel: UILabel!

	var observer: Observation?
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
	
	override func viewWillAppear(_ animated: Bool) {
		connectionLabel.text = "Connecting..."
		foodLabel.text = "Loading..."
		observer = DALIFood.observeFood { (food) in
			DispatchQueue.main.async {
				self.connectionLabel.text = "Connected"
				self.foodLabel.text = food ?? "No food tonight"
			}
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		observer?.stop()
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	@IBAction func submit(_ sender: UIButton) {
		DALIFood.setFood(food: foodTextField.text!) { (success) in
			print(success)
		}
	}
}
