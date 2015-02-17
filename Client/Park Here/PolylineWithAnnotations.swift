//
//  PolylineWithAnnotations.swift
//  Park Here
//
//  Created by Aditya Bansod on 11/7/14.
//  Copyright (c) 2014 Aditya Bansod. All rights reserved.
//

import UIKit
import MapKit

enum RegulationType :Printable {
    case ParkingPermit, TimeLimited, ParkingMeters, None, Unknown
    var description: String {
        switch self {
        case .ParkingPermit: return "Parking Permit";
        case .TimeLimited: return "Time Limited";
        case .None: return "None";
        case .ParkingMeters: return "Parking Meters";
        case .Unknown: return "Unknown";
        }
    }
}

class PolylineWithAnnotations: MKPolyline {
    var annotation:String = ""
    var id:String = ""
    var street:String = ""
    var centerpoint:CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var sweepings:NSArray = []
    var type:RegulationType = .None
    var renderer:MKPolylineRenderer = MKPolylineRenderer()
    
    var permitHourLimit:Int = 0
    var permitArea:String = ""
    var permitDays:String = ""
    var permitHours:String = ""
    
    var annotations2:String {
        get {
            return type.description + " \(sweepings.count)"
        }
    }
    
    var hasRestrictionsInNext24Hours:Bool {
        get {
            return hasSweepingsToday || determineIfParkingRestrictionsApply()
        }
    }
    
    var hasAnyRestrictions:Bool {
        get {
            return hasSweepingsToday && determineIfParkingRestrictionsApply()
        }
    }
    
    var hasSomeRestrictions:Bool {
        get {
            return hasSweepingsToday || determineIfParkingRestrictionsApply()
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
            case "Sun", "Su":
                return 1
            case "Mon", "M":
                return 2
            case "Tues":
                return 3
            case "Wed":
                return 4
            case "Thu":
                return 5
            case "Fri", "F":
                return 6
            case "Sat", "Sa":
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
    
    func rulesForDay(day:String) -> String {
        let ordinal = convertDayToOrdinal(day)
        
        for sweep in sweepings {
            let weekday = sweep["weekday"] as String
            let thisWeekdayOrdinal = convertDayToOrdinal(weekday)
            if ordinal == thisWeekdayOrdinal {
                return sweep["description"] as String
            }
            
        }
        
        
        return type.description
    }
    
    func determineIfParkingRestrictionsApply() -> Bool {
        // TODO should use proper Swift nullability ther
        if permitArea == "" {
            // there are no restrictions
            return false
        }
        
        let permitFrom = convertDayToOrdinal(permitDays.componentsSeparatedByString("-")[0] as String)
        let permitTo = convertDayToOrdinal(permitDays.componentsSeparatedByString("-")[1] as String)
        
        let permitHoursFrom = permitHours.componentsSeparatedByString("-")[0].toInt()
        let permitHoursTo = permitHours.componentsSeparatedByString("-")[1].toInt()
        
        let today = getToday()
        
        let cal = NSCalendar.currentCalendar()
        let todayComponents = cal.components(
            NSCalendarUnit.CalendarUnitDay |
                NSCalendarUnit.CalendarUnitMonth |
                NSCalendarUnit.CalendarUnitYear |
                NSCalendarUnit.CalendarUnitWeekday, fromDate: NSDate())
        println("\(todayComponents.weekday) + \(permitFrom)")
        
        // construct a NSDate from the from time and to time

        
        
        if todayComponents.weekday >= permitFrom && todayComponents.weekday <= permitTo {
            
            // TODO we know we're in the days, but are we within the times?
            
            // TODO do I have a permit of this type?
            
            if permitArea.uppercaseString.rangeOfString("S") != nil {
                // if you have the permit for this area, parking restrictions do not apply
                return false
            }
            
            
            return true
            
        }
        
//        let dayOfWeekDelta =
        
//        fromComponents.hour = permitHoursFrom!
        
        
        
        
        return true
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
                    self.annotation += " You can park here for \(stringifyHours(fromDate.timeIntervalSinceNow))."
                    
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
