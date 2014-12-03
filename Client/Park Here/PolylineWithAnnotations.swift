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
}
