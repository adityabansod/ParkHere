//
//  PolylineWithAnnotations.swift
//  Park Here
//
//  Created by Aditya Bansod on 11/7/14.
//  Copyright (c) 2014 Aditya Bansod. All rights reserved.
//

import UIKit
import MapKit

enum RegulationType {
    case ParkingPermit, TimeLimited, ParkingMeters, None, Unknown
}

class PolylineWithAnnotations: MKPolyline {
    var annotation:String = ""
    var id:String = ""
    var street:String = ""
    var centerpoint:CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var sweepings:NSArray = []
    var type:RegulationType = .None
    var renderer:MKPolylineRenderer = MKPolylineRenderer()
    
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
    
    func getToday() -> Int {
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.WeekdayCalendarUnit, fromDate: NSDate())
        return components.weekday
    }
    
    var hasSweepingsToday:Bool {
        get {
            var sweepingToday:Bool = false
            for sweeping in sweepings {
                if determineIfSweepingApplies(sweeping as NSDictionary) {
                    sweepingToday = true
                }
            }
            return sweepingToday
        }
    }
        
    func determineIfSweepingApplies(sweeping: NSDictionary) -> Bool {
        let today = getToday()
        if let weekday = sweeping.valueForKey("weekday") as? String {
            switch(weekday) {
            case "Sun":
                if today == 1 { return true }
                break
            case "Mon":
                if today == 2 { return true }
                break
            case "Tues":
                if today == 3 { return true }
                break
            case "Wed":
                if today == 4 { return true }
                break
            case "Thu":
                if today == 5 { return true }
                break
            case "Fri":
                if today == 6 { return true }
                break
            case "Sat":
                if today == 7 { return true }
                break
            case "Holiday":
                return false
            default:
                println("wtf")
                return false
            }
        }
        return false
    }
    
    
    
}
