//
//  ProgressViewController.swift
//  iOS Swift Camera
//
//  Created by Xinyi Ding on 06/01/2018.
//  Copyright © 2018 Jeffrey Berthiaume. All rights reserved.
//

import UIKit

class ProgressViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
