//
//  ProgressViewController.swift
//  iOS Swift Camera
//
//  Created by Xinyi Ding on 06/01/2018.
//  Copyright © 2018 Jeffrey Berthiaume. All rights reserved.
//

import UIKit

class ProgressViewController: UIViewController {

    @IBOutlet weak var itrOneButton: UIButton!
    @IBOutlet weak var itrTwoButton: UIButton!
    @IBOutlet weak var itrThreeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        let userDefault = UserDefaults.standard
        let itr1 = userDefault.bool(forKey: "iter1")
        let itr2 = userDefault.bool(forKey: "iter2")
        let itr3 = userDefault.bool(forKey: "iter3")
        if itr1 == true {
            itrOneButton.backgroundColor = UIColor.green
        }
        if itr2 == true {
            itrTwoButton.backgroundColor = UIColor.green
        }
        if itr3 == true {
            itrThreeButton.backgroundColor = UIColor.green
            let userDefault = UserDefaults.standard
            userDefault.set(false, forKey: "iter1")
            userDefault.set(false, forKey: "iter2")
            userDefault.set(false, forKey: "iter3")
            
            let alertController = UIAlertController(title: "Congratulations!", message: "You have finished all the tests", preferredStyle: .alert)
            
            let yesAction = UIAlertAction(title: "OK", style: .default) { (action) -> Void in
                print("The user has finished all the tests")
            }
            
            alertController.addAction(yesAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func finishExp(_ sender: UIButton) {
//        let userDefault = UserDefaults.standard
//        userDefault.set(false, forKey: "iter1")
//        userDefault.set(false, forKey: "iter2")
//        userDefault.set(false, forKey: "iter3")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let nav2Controller = segue.destination as! RecordVideoViewController
        if segue.identifier == "iter1" {
            nav2Controller.itr = "iter1"
        } else if segue.identifier == "iter2" {
            nav2Controller.itr = "iter2"
        } else {
            nav2Controller.itr = "iter3"
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
