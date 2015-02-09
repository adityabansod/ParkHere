//
//  PageContentViewController.swift
//  Park Here
//
//  Created by Aditya Bansod on 1/17/15.
//  Copyright (c) 2015 Aditya Bansod. All rights reserved.
//

import UIKit

class IntroContentViewController: UIViewController {

    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBAction func cancelButton(sender: UIButton) {
        // this is a little silly -- but, IntroContentVC is inside of PageVC, which is inside of IntroVC
        self.parentViewController?.parentViewController?.performSegueWithIdentifier("IntroViewToMapViewSegue", sender: self)
    }
    
    var pageIndex = 0
    var titleText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.titleLabel.text = titleText
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
