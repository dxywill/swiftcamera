//
//  EntryViewController.swift
//  iOS Swift Camera
//
//  Created by Xinyi Ding on 06/01/2018.
//  Copyright © 2018 Jeffrey Berthiaume. All rights reserved.
//

import UIKit

class EntryViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBOutlet weak var participantID: UITextField!
    
    @IBAction func getParticipantID(_ sender: UIButton) {
        let userDefault = UserDefaults.standard
        let pID = Int(participantID.text!)
        userDefault.set(pID, forKey: "participantID")
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
