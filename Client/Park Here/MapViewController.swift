//
//  ViewController.swift
//  Park Here
//
//  Created by Aditya Bansod on 11/6/14.
//  Copyright (c) 2014 Aditya Bansod. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate {

    var networkRequestPending:Bool = false
    var locationManager:CLLocationManager?
    
    @IBOutlet var mapView:MKMapView!
    @IBOutlet weak var sundayLabel: UILabel!
    @IBOutlet weak var mondayLabel: UILabel!
    @IBOutlet weak var tuesdayLabel: UILabel!
    @IBOutlet weak var wednesdayLabel: UILabel!
    @IBOutlet weak var thursdayLabel: UILabel!
    @IBOutlet weak var fridayLabel: UILabel!
    @IBOutlet weak var saturdayLabel: UILabel!
    @IBOutlet weak var streetNameLabel: UILabel!
    @IBOutlet weak var opacityUnderlay: UIView!
    var selectedPolyline:PolylineWithAnnotations?
    var selectedPolylineOldColor:UIColor?
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationService()
        
        
        let tap = UITapGestureRecognizer(target: self, action: Selector("handleOverlayTap:"))
        tap.delegate = self
        mapView.addGestureRecognizer(tap)
    }
    
    func setupLocationService() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
        mapView.showsUserLocation = true
        mapView.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let location = locations.last as CLLocation
        let coordiateRegion = MKCoordinateRegionMake(location.coordinate, MKCoordinateSpanMake(0.0005, 0.0005))
        
        mapView.setRegion(coordiateRegion, animated: false)
        lookupSweepingForLocation(location.coordinate)
        
        locationManager?.stopUpdatingHeading()
        locationManager?.stopUpdatingLocation()
        locationManager?.stopMonitoringSignificantLocationChanges()
    }
    
    func lookupSweepingForLocation(coordinate:CLLocationCoordinate2D, maxDistance:Int) {
        
        if !shouldLookupSweeping() {
            return
        }
        
//        let url = NSURL(string: "http://192.168.1.186:5000/nearby/\(coordinate.latitude)/\(coordinate.longitude)?maxDistance=\(maxDistance)")
        let url = NSURL(string: "https://parkhereapp.herokuapp.com/nearby/\(coordinate.latitude)/\(coordinate.longitude)?maxDistance=\(maxDistance)")
        
        println("starting network request")
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            self.processRegulationsData(data)
            println("done with network request, done with processregulationsdata")
        }
        task.resume()
        networkRequestPending = true
        dispatch_async(dispatch_get_main_queue()) {
            self.loadingIndicator.startAnimating()
        }

    }
    
    func lookupSweepingForLocation(coordinate:CLLocationCoordinate2D) {
        lookupSweepingForLocation(coordinate, maxDistance: 150)
    }
    
    func processRegulationsData(data: NSData) {
        self.clearNetworkPendingFlag()

        var jsonError: NSError?
        if let results = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &jsonError) as? NSArray {
            for result in results {
                let geometryType = result.valueForKeyPath("geometry.type") as String
                let coordinates = result.valueForKeyPath("geometry.coordinates") as NSArray
                let id = result.valueForKeyPath("_id") as String
                
                if geometryType == "LineString" {
                    var linepath:[CLLocationCoordinate2D] = []
                    for cord in coordinates {
                        let c = CLLocationCoordinate2DMake(cord[1] as CLLocationDegrees, cord[0] as CLLocationDegrees)
                        linepath.append(c)
                    }
                    let polyline = PolylineWithAnnotations(coordinates: &linepath, count: linepath.count)
                    let centerJson = result.valueForKeyPath("centerpoint") as NSArray
                    
                    polyline.centerpoint = CLLocationCoordinate2DMake(centerJson[0] as CLLocationDegrees, centerJson[1] as CLLocationDegrees)
                    
                    if let streetName = result.valueForKeyPath("street") as? String {
                        polyline.street = streetName
                    } else {
                        polyline.street = "Unknown"
                    }
                    
                    if let sweepings = result.valueForKeyPath("sweepings") as? NSArray {
                        if sweepings.count > 0 {
                            polyline.sweepings = sweepings
                        }
                    }
                    
                    
                    if let regs = result.valueForKeyPath("properties.Regulation") as? String {
                        switch regs {
                        case "Unregulated":
                            polyline.annotation += "There are no permits or meters on this block."
                            polyline.type = .None
                        case "RPP":
                            if let permitArea = result.valueForKeyPath("properties.PermitArea") as? String {
                                if let permitHours = result.valueForKeyPath("properties.Hours") as? String {
                                    if let permitDays = result.valueForKeyPath("properties.Days") as? String {
                                        if let permitHourLimit = result.valueForKeyPath("properties.HrLimit") as? Int {
                                            polyline.annotation += "There is a \(permitHourLimit) hour limit here unless you have a type \(permitArea) permit. This is enforced \(permitDays) \(permitHours)."
                                            
                                            polyline.permitHourLimit = permitHourLimit
                                            polyline.permitArea = permitArea
                                            polyline.permitDays = permitDays
                                            polyline.permitHours = permitHours
                                        }
                                    }
                                }
                            } else {
                                polyline.annotation += "This block requires a residential parking permit."
                            }
                            polyline.type = .ParkingPermit
                        case "Time limited": // TODO: ollapse this logic with RPP. it's the same except it has no permit area
                            if let permitHours = result.valueForKeyPath("properties.Hours") as? String {
                                if let permitDays = result.valueForKeyPath("properties.Days") as? String {
                                    if let permitHourLimit = result.valueForKeyPath("properties.HrLimit") as? Int {
                                        polyline.annotation += "There is a \(permitHourLimit) hour limit here. This is enforced \(permitDays) \(permitHours)."
                                        
                                        polyline.permitHourLimit = permitHourLimit
                                        polyline.permitDays = permitDays
                                        polyline.permitHours = permitHours
                                    }
                                }
                            } else {
                                polyline.annotation += "This block requires a residential parking permit."
                            }
                            polyline.type = .TimeLimited
                        case "Metered":
                            polyline.annotation += "This block has parking meters."
                            polyline.type = .ParkingMeters
                        default:
                            polyline.annotation += regs
                            polyline.type = .Unknown
                        }
                    } else {
                        polyline.type = .Unknown
                        polyline.annotation = "Unregulated"
                    }
                    
                    polyline.annotation = polyline.annotation.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    polyline.id = id
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        // this is here since adding the overlay is async, therefore there are timing issues
                        // between the main thread adding events faster than they exist in self.mapView.overlays
                        // since dispatch_async is a queue, we can check here to ensure we're not double adding things
                        if let overlayCollection = self.mapView.overlays as? [PolylineWithAnnotations] {
                            if (overlayCollection.filter { $0.id == id }).count > 0 {
                                return
                            }
                        }
                        self.mapView.addOverlay(polyline, level: MKOverlayLevel.AboveRoads)
                    }
                } else {
                    println("found geometry other than a linestring, bailing");
                }
                
            }
        }
    }
    
    func shouldLookupSweeping() -> Bool {
        if networkRequestPending {
            NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "clearNetworkPendingFlag", userInfo: nil, repeats: false)
            return false
        } else {
            return true
        }
    }
    
    func clearNetworkPendingFlag() {
        networkRequestPending = false
        dispatch_async(dispatch_get_main_queue()) {
            self.loadingIndicator.stopAnimating()
        }
    }
    
    func handleOverlayTap(tap: UITapGestureRecognizer) {
        let point = tap.locationInView(self.mapView)
        let tapCoordinate = mapView.convertPoint(point, toCoordinateFromView: self.mapView)
        let region = MKCoordinateRegionMakeWithDistance(tapCoordinate, 1.0, 1.0)
        let mapRect = Geospatial.mapRectForCoordinateRegion(region)
        
        var messages:String = ""
        var title:String = ""
        
        var candidateMatches:[AnyObject] = []
        var closestDistance:Double = 1000
        var closestMatch:PolylineWithAnnotations = PolylineWithAnnotations()
        
        if let overlayCollection = self.mapView.overlays as? [MKPolyline] {
            for overlay in overlayCollection {
                let polygon = overlay as PolylineWithAnnotations
                if(polygon.intersectsMapRect(mapRect)) {
                    let dist = Geospatial.wgs84distance(tapCoordinate, loc2: polygon.centerpoint)
                    
                    // find the closest match
                    if dist < closestDistance {
                        closestMatch = polygon
                        closestDistance = dist
                    }
                    
                    candidateMatches.append([polygon, dist])
                }
            }
            
            // pick the street name from the closest match
            title = closestMatch.street
            
            // Elimiate the ones that don't match
            // the street name and that are too far away
            for candidate in candidateMatches {
                let polyline = candidate[0] as PolylineWithAnnotations
                let dist = candidate[1] as Double
                
                if dist > 75 {continue}
                if polyline.street != title {continue}
                
                // all UI changes go in to a block
                dispatch_async(dispatch_get_main_queue()) {
                    self.updateCalendarOverlay(polyline)
                    
                    messages += polyline.annotation + " "
                    println("Creating alert for \(polyline.id) at distance \(dist)")
                    self.selectedPolyline = polyline
                    self.selectedPolylineOldColor = polyline.renderer.strokeColor
                    polyline.renderer.strokeColor = UIColor.brownColor()
                }
                
                
            }
        }
    }
    
    // MARK: calendar overlay management
    
    func resetCalendarOverlay(animated:Bool) {
        var handler:(Void) -> ()
        handler = {
            self.opacityUnderlay.alpha = 0.0
            self.opacityUnderlay.frame.origin.y = -self.opacityUnderlay.frame.height
            
            self.streetNameLabel.hidden = true
            self.streetNameLabel.alpha = 0
            self.streetNameLabel.frame.origin.y = -self.streetNameLabel.frame.height
        }
        if animated {
            UIView.animateWithDuration(0.2, animations: handler)
        } else {
            handler()
        }
        
        mondayLabel.textColor = UIColor.blackColor()
        tuesdayLabel.textColor = UIColor.blackColor()
        wednesdayLabel.textColor = UIColor.blackColor()
        thursdayLabel.textColor = UIColor.blackColor()
        fridayLabel.textColor = UIColor.blackColor()
        saturdayLabel.textColor = UIColor.blackColor()
        sundayLabel.textColor = UIColor.blackColor()
        selectedPolyline?.renderer.strokeColor = selectedPolylineOldColor
    }
    
    func updateCalendarOverlay(polyline: PolylineWithAnnotations) {
        resetCalendarOverlay(false)

        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.5, initialSpringVelocity: 1.0, options: nil, animations: {
            self.opacityUnderlay.frame.origin.y = 20
            self.streetNameLabel.frame.origin.y = 77
        }, completion: {(animated:Bool) -> () in  })

        
        
        UIView.animateWithDuration(0.2, animations: {
            self.opacityUnderlay.alpha = 0.7
            self.streetNameLabel.hidden = false
            self.streetNameLabel.alpha = 1.0
        })
        
        for sweeping in polyline.sweepings {
            if let day = sweeping.valueForKeyPath("weekday") as? String {
                switch day {
                    case "Mon":
                        mondayLabel.textColor = UIColor.redColor()
                    case "Tues":
                        tuesdayLabel.textColor = UIColor.redColor()
                    case "Wed":
                        wednesdayLabel.textColor = UIColor.redColor()
                    case "Thu":
                        thursdayLabel.textColor = UIColor.redColor()
                    case "Fri":
                        fridayLabel.textColor = UIColor.redColor()
                    case "Sat":
                        saturdayLabel.textColor = UIColor.redColor()
                    case "Sun":
                        sundayLabel.textColor = UIColor.redColor()
                    default:
                        println("unknown day \(day)")
                }
                
            }
        }
        streetNameLabel.text = polyline.annotation
        
        
        println("\(polyline.id): \(streetNameLabel.text)")
    }
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        let touch = touches.anyObject() as UITouch
        var whichLabel:UILabel
        
        switch touch.view {
            case sundayLabel: whichLabel = sundayLabel
            case mondayLabel: whichLabel = mondayLabel
            case tuesdayLabel: whichLabel = tuesdayLabel
            case wednesdayLabel: whichLabel = wednesdayLabel
            case thursdayLabel: whichLabel = thursdayLabel
            case fridayLabel: whichLabel = fridayLabel
            case saturdayLabel: whichLabel = saturdayLabel
            default: return
        }
        
        createAlert("something", message: selectedPolyline!.rulesForDay(whichLabel.text!))
        
//        println(whichLabel)
    }
    
    // MARK: UI Helpers
    
    func createAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let destroyAction = UIAlertAction(title: "Dismiss", style: .Default) { (action) in
            return
        }
        alert.addAction(destroyAction)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    @IBAction func resetLocation(sender: UIButton) {
        mapView.userLocation.coordinate
        
        mapView.setRegion(MKCoordinateRegionMake(mapView.userLocation.coordinate, MKCoordinateSpanMake(0.0005, 0.0005)), animated: true)
        
    }
    
    // MARK: MapView Handling
    func mapView(mapView: MKMapView!, regionWillChangeAnimated animated: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            self.resetCalendarOverlay(true)
        }
    }
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            self.resetCalendarOverlay(true)
        }
        let maxDistance = Geospatial.findMaxDimensionsOfMap(mapView)
        if(maxDistance < 1000) {
            // TODO MOVE THIS TO A DIFFERNET LABEL
            streetNameLabel.hidden = true
            lookupSweepingForLocation(mapView.centerCoordinate, maxDistance: maxDistance)
        } else {
            streetNameLabel.hidden = false
            streetNameLabel.text = "Zoom in to loading parking information."
        }
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is PolylineWithAnnotations {
            let poly = overlay as PolylineWithAnnotations
            
            var polylineRenderer = MKPolylineRenderer(overlay: poly)
            poly.renderer = polylineRenderer
            if poly.hasSweepingsToday {
                polylineRenderer.strokeColor = UIColor.yellowColor().colorWithAlphaComponent(0.65)
            } else if poly.hasSweepingsToday && poly.hasAnyRestrictions {
                polylineRenderer.strokeColor = UIColor.redColor().colorWithAlphaComponent(0.5)
            } else if poly.hasSomeRestrictions {
                polylineRenderer.strokeColor = UIColor.greenColor().colorWithAlphaComponent(0.5)
            } else {
                polylineRenderer.strokeColor = UIColor.blueColor().colorWithAlphaComponent(0.8)
            }
            
            polylineRenderer.lineWidth = 4
            polylineRenderer.lineCap = kCGLineCapSquare
            polylineRenderer.lineDashPhase = 15
            return polylineRenderer
        } else {
            return nil
        }
    }
}