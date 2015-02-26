//
//  SettingsOverlayView.swift
//  Park Here
//
//  Created by Aditya Bansod on 2/19/15.
//  Copyright (c) 2015 Aditya Bansod. All rights reserved.
//

import UIKit

class SettingsOverlayView: UIView {

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    
    required init(coder aDecoder: NSCoder) {
        println("settingsoverlayview loaded")
        super.init(coder: aDecoder)
    }
    
    override func awakeAfterUsingCoder(aDecoder: NSCoder) -> AnyObject? {
        if self.subviews.count == 0 {
            return loadNib()
        }
        return self
    }
    
    private func loadNib() -> SettingsOverlayView {
        return NSBundle.mainBundle().loadNibNamed("SettingsOverlay", owner: nil, options: nil)[0] as SettingsOverlayView
    }
}
