//
//  PageContentViewController.swift
//  Park Here
//
//  Created by Aditya Bansod on 1/17/15.
//  Copyright (c) 2015 Aditya Bansod. All rights reserved.
//

import UIKit

class IntroContentViewController: UIViewController {

    @IBOutlet weak var label: UILabel!
    var pageIndex = 0
    var labelText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.label.text = labelText
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
