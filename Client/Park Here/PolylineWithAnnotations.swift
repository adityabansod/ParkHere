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
                    return true
                }
            }
            return sweepingToday
        }
    }
    
    private func getHoursFromString(raw: String) -> Int {
        return raw.componentsSeparatedByString(":")[0].toInt()!
    }
    
    private func getMinutesFromString(raw: String) -> Int {
        return raw.componentsSeparatedByString(":")[1].toInt()!
    }
    
    private func convertDayToOrdinal(raw: String) -> Int {
        switch(raw) {
            case "Sun":
                return 1
            case "Mon":
                return 2
            case "Tues":
                return 3
            case "Wed":
                return 4
            case "Thu":
                return 5
            case "Fri":
                return 6
            case "Sat":
                return 7
            case "Holiday":
                return 0
            default:
                println("wtf")
                return 0
        }
    }
    
    private func stringifyHours(seconds: Double) -> String {
        let hours = seconds / (60*60)
        
        var stringHours:String
        var stringMinutes:String
        
        let wholeHours = Int(hours)
        if wholeHours == 0 {
            stringHours = ""
        } else if wholeHours == 1 {
            stringHours = "1 hour"
        } else {
            stringHours = "\(wholeHours) hours"
        }
        
        let wholeMinutes = Int((hours - Double(Int(hours)))*60)
        if wholeMinutes == 0 {
            return stringHours
        } else if wholeMinutes == 1 {
            return "\(stringHours) 1 minute"
        } else {
            return "\(stringHours) \(wholeMinutes) minutes"
        }
    }
    
    func determineIfSweepingApplies(sweeping: NSDictionary) -> Bool {
        let today = getToday()
        let from = sweeping["from"] as String
        let to = sweeping["to"] as String
        let weekday = sweeping["weekday"] as String
        let secondsIn24Hours = 24*60*60 as NSTimeInterval
        
        let cal = NSCalendar.currentCalendar()
        let components = cal.components(NSCalendarUnit.CalendarUnitHour |
            NSCalendarUnit.CalendarUnitMinute |
            NSCalendarUnit.CalendarUnitDay |
            NSCalendarUnit.CalendarUnitMonth |
            NSCalendarUnit.CalendarUnitYear |
            NSCalendarUnit.WeekdayCalendarUnit, fromDate: NSDate())
        
        var fromDate:NSDate
        var toDate:NSDate
        
        
        let originalDay = components.day
        
        // figure out which from is next
        for var i = 0; i < 7; ++i {
            let dateOffset = originalDay + i
            components.day = dateOffset
            let thisDay = cal.dateFromComponents(components)
            
            let newComponents = cal.components(NSCalendarUnit.CalendarUnitHour |
                NSCalendarUnit.CalendarUnitMinute |
                NSCalendarUnit.CalendarUnitDay |
                NSCalendarUnit.CalendarUnitMonth |
                NSCalendarUnit.CalendarUnitYear |
                NSCalendarUnit.WeekdayCalendarUnit |
                NSCalendarUnit.CalendarUnitWeekday, fromDate: thisDay!)
            
            if newComponents.weekday == convertDayToOrdinal(weekday) {
                newComponents.hour = getHoursFromString(from)
                newComponents.minute = getMinutesFromString(from)
                fromDate = cal.dateFromComponents(newComponents)!

                newComponents.hour = getHoursFromString(to)
                newComponents.minute = getMinutesFromString(to)
                toDate = cal.dateFromComponents(newComponents)!
                
                // figure out if this sweeping is in the next 24 hour
                if fromDate.timeIntervalSinceNow < secondsIn24Hours && fromDate.timeIntervalSinceNow > 0 {
                    println("sweeping applies", sweeping)
                    self.annotation += ". You can park here for \(stringifyHours(fromDate.timeIntervalSinceNow))"
                    
                    return true
                }
                
                // TODO are we currently in it?
                if fromDate.timeIntervalSinceNow < 0 && toDate.timeIntervalSinceNow > 0 {
                    if toDate.timeIntervalSinceNow < (toDate.timeIntervalSinceNow - fromDate.timeIntervalSinceNow) {
                        println("currnetly in it")
                    }
                }
                

            }
        }
        return false
    }
}
