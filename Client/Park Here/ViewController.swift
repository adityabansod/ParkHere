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

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate {

    var locationManager:CLLocationManager?
    @IBOutlet var mapView:MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupLocationService()
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
        
        #if DEBUG
            let url = NSURL(string: "http://localhost:5000/nearby/\(coordinate.latitude)/\(coordinate.longitude)?maxDistance=\(maxDistance)")
        #else
            let url = NSURL(string: "https://obscure-journey-3692.herokuapp.com/nearby/\(coordinate.latitude)/\(coordinate.longitude)?maxDistance=\(maxDistance)")
        #endif
            
        var jsonError: NSError?
        
        let tap = UITapGestureRecognizer(target: self, action: Selector("handleOverlayTap:"))
        tap.delegate = self
        mapView.addGestureRecognizer(tap)
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            if let results = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &jsonError) as? NSArray {
                for result in results {
//                    print("found a result with ")
//                    println(result.valueForKeyPath("properties.Regulation") as String)
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
                            polyline.street = "Parking Rules for \(streetName)"
                        } else {
                            polyline.street = "Parking Rules"
                        }
                        
                        if let sweepings = result.valueForKeyPath("sweepings") as? NSArray {
                            if sweepings.count > 0 {
                                let sweeping = sweepings[0] as NSDictionary
                                if let desc = sweeping.valueForKey("description") as? String {
                                    polyline.annotation += desc + " "
                                }
                            }
                        }
                        
                        
                        let regs = result.valueForKeyPath("properties.Regulation") as String;
                        switch regs {
                        case "Unregulated":
                            polyline.annotation += "There are no permits or meters on this block."
                        case "RPP":
                            if let permitArea = result.valueForKeyPath("properties.PermitArea") as? String {
                                if let permitHours = result.valueForKeyPath("properties.Hours") as? String {
                                    if let permitDays = result.valueForKeyPath("properties.Days") as? String {
                                        if let permitHourLimit = result.valueForKeyPath("properties.HrLimit") as? Int {
                                            polyline.annotation += "There is a \(permitHourLimit) hour limit here unless you have a type \(permitArea) permit. This is enforced \(permitDays) \(permitHours)."
                                        }
                                    }
                                }
                            } else {
                                polyline.annotation += "This block requires a residential parking permit."
                            }
                        case "Metered":
                            polyline.annotation += "This block has parking meters."
                        default:
                            polyline.annotation += regs
                        }
                        
                        polyline.annotation = polyline.annotation.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                        polyline.id = id
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            // this is here since adding the overlay is async, therefore there are timing issues
                            // between the main thread adding events faster than they exist in self.mapView.overlays
                            // since dispatch_async is a queue, we can check here to ensure we're not double adding things
                            if let overlayCollection = self.mapView.overlays as? [PolylineWithAnnotations] {
                                for overlay in overlayCollection {
                                    if id == (overlay as PolylineWithAnnotations).id {
                                        return
                                    }
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
        task.resume()

    }
    
    func lookupSweepingForLocation(coordinate:CLLocationCoordinate2D) {
        lookupSweepingForLocation(coordinate, maxDistance: 150)
    }
    
    func handleOverlayTap(tap: UITapGestureRecognizer) {
        let point = tap.locationInView(self.mapView)
        let tapCoordinate = mapView.convertPoint(point, toCoordinateFromView: self.mapView)
        let region = MKCoordinateRegionMakeWithDistance(tapCoordinate, 1.0, 1.0)
        let mapRect = MKMapRectForCoordinateRegion(region)
        
        var messages:String = ""
        var title:String = ""
        
        for overlay in self.mapView.overlays {
            if(overlay is MKPolyline) {
                let polygon = overlay as PolylineWithAnnotations
                if(polygon.intersectsMapRect(mapRect)) {
                    let dist = wgs84distance(tapCoordinate, loc2: polygon.centerpoint)
                    if dist > 50 {
                        continue
                    }
                    // eventually replace this w/ the closests match
                    if title == "" {
                        title = polygon.street
                    }
                    messages += polygon.annotation + " "
                    println("Creating alert for \(polygon.id) at distance \(dist)")
                }
            }
        }
        if messages != "" {
            createAlert(title, message: messages)
        }
    }
    
    func MKMapRectForCoordinateRegion(region: MKCoordinateRegion) -> MKMapRect {
        let center = region.center;
        let span = region.span;
        let topLeft =
        CLLocationCoordinate2DMake(center.latitude + span.latitudeDelta / 2.0,
        center.longitude - span.longitudeDelta / 2.0);
        
        let bottomRight =
        CLLocationCoordinate2DMake(center.latitude - span.latitudeDelta / 2.0,
        center.longitude + span.longitudeDelta / 2.0);
        
        let mapPointTopLeft = MKMapPointForCoordinate(topLeft);
        let mapPointBottomRight = MKMapPointForCoordinate(bottomRight);
        let width = mapPointBottomRight.x - mapPointTopLeft.x;
        let height = mapPointBottomRight.y - mapPointTopLeft.y;
        
        let ret = MKMapRectMake(mapPointTopLeft.x, mapPointTopLeft.y, width, height);
        return ret;
    }
    
    func createAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let destroyAction = UIAlertAction(title: "Dismiss", style: .Default) { (action) in
            return
        }
        alert.addAction(destroyAction)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func findMaxDimensionsOfMap(mapView: MKMapView!) -> Int {
        let span = mapView.region.span
        let center = mapView.centerCoordinate
        
        let loc1 = CLLocation(latitude: center.latitude - span.latitudeDelta * 0.5, longitude: center.longitude)
        let loc2 = CLLocation(latitude: center.latitude + span.latitudeDelta * 0.5, longitude: center.longitude)
        
        let metersInLatitude = loc1.distanceFromLocation(loc2)
        
        let loc3 = CLLocation(latitude: center.latitude, longitude: center.longitude - span.longitudeDelta * 0.5)
        let loc4 = CLLocation(latitude: center.latitude, longitude: center.longitude + span.longitudeDelta * 0.5)
        
        let metersInLongitude = loc3.distanceFromLocation(loc4)
        
        return Int(max(metersInLatitude, metersInLongitude))
    }
    
    func wgs84distance(loc1:CLLocationCoordinate2D, loc2:CLLocationCoordinate2D) -> Double {
        
        let radlat1 = M_PI * loc1.latitude/180;
        let radlat2 = M_PI * loc2.latitude/180;
        let radlon1 = M_PI * loc1.longitude/180;
        let radlon2 = M_PI * loc2.longitude/180;
        let theta = loc1.longitude - loc2.longitude;
        let radtheta = M_PI * theta/180;
        var dist = sin(radlat1) * sin(radlat2) + cos(radlat1) * cos(radlat2) * cos(radtheta);
        dist = acos(dist);
        dist = dist * 180/M_PI;
        dist = dist * 60 * 1.1515;
        return dist * 1.609344 * 1000;
    }
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        let maxDistance = findMaxDimensionsOfMap(mapView)
        if(maxDistance < 1000) {
            lookupSweepingForLocation(mapView.centerCoordinate, maxDistance: maxDistance)
        }
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is MKPolyline {
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.redColor()
            polylineRenderer.lineWidth = 4
            return polylineRenderer
        } else {
            return nil
        }
    }
}