//
//  PolylineWithAnnotations.swift
//  Park Here
//
//  Created by Aditya Bansod on 11/7/14.
//  Copyright (c) 2014 Aditya Bansod. All rights reserved.
//

import UIKit
import MapKit

class PolylineWithAnnotations: MKPolyline {
    var annotation:String = ""
    var id:String = ""
    var street:String = ""
    var centerpoint:CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var sweepings:NSArray = []
    var hasAnyRestrictions:Bool {
        get {
            // clearly this is not the best solution since it depends on the 
            // string value of annotation but this works for now
            return sweepings.count > 0 && annotation != ""
        }
    }
    
    var hasSomeRestrictions:Bool {
        get {
            return sweepings.count > 0 || annotation != ""
        }
    }
    
}
