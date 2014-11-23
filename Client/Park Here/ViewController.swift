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
        locationManager?.startMonitoringSignificantLocationChanges()
        locationManager?.startUpdatingHeading()
        mapView.showsUserLocation = true
        mapView.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let location = locations.last as CLLocation
        let coordiateRegion = MKCoordinateRegionMake(location.coordinate, MKCoordinateSpanMake(0.005, 0.005))
        
        mapView.setRegion(coordiateRegion, animated: false)
        lookupSweepingForLocation(location.coordinate)
        
        locationManager?.stopUpdatingHeading()
        locationManager?.stopUpdatingLocation()
        locationManager?.stopMonitoringSignificantLocationChanges()
    }
    
    func lookupSweepingForLocation(coordinate:CLLocationCoordinate2D, maxDistance:Int) {
        
//        let url = NSURL(string: "https://obscure-journey-3692.herokuapp.com/nearby/\(coordinate.latitude)/\(coordinate.longitude)?maxDistance=\(maxDistance)")
        
        let url = NSURL(string: "http://localhost:5000/nearby/\(coordinate.latitude)/\(coordinate.longitude)?maxDistance=\(maxDistance)")
        
        var jsonError: NSError?
        
        let tap = UITapGestureRecognizer(target: self, action: Selector("handleOverlayTap:"))
        tap.delegate = self
        mapView.addGestureRecognizer(tap)
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            if let results = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &jsonError) as? NSArray {
                for result in results {
                    print("found a result with ")
                    println(result.valueForKeyPath("properties.Regulation") as String)
                    let geometryType = result.valueForKeyPath("geometry.type") as String
                    let coordinates = result.valueForKeyPath("geometry.coordinates") as NSArray
                    let id = result.valueForKeyPath("_id") as String
                    
                    if geometryType == "LineString" {
                        if let overlayCollection = self.mapView.overlays as? [PolylineWithAnnotations] {
                            for overlay in overlayCollection {
                                if id == (overlay as PolylineWithAnnotations).id {
                                    return
                                }
                            }
                        }
                        var linepath:[CLLocationCoordinate2D] = []
                        for cord in coordinates {
                            let c = CLLocationCoordinate2DMake(cord[1] as CLLocationDegrees, cord[0] as CLLocationDegrees)
                            linepath.append(c)
                        }
                        let polyline = PolylineWithAnnotations(coordinates: &linepath, count: linepath.count)
                        polyline.annotation = result.valueForKeyPath("properties.Regulation") as String
                        polyline.id = id
                        println(polyline.annotation)
                        dispatch_async(dispatch_get_main_queue()) {
                            self.mapView.addOverlay(polyline, level: MKOverlayLevel.AboveRoads)
                        }
                    }
                    
                }
            }
            
        }
        task.resume()

    }
    
    func lookupSweepingForLocation(coordinate:CLLocationCoordinate2D) {
        lookupSweepingForLocation(coordinate, maxDistance: 150)
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func handleOverlayTap(tap: UITapGestureRecognizer) {
        
        let point = tap.locationInView(self.mapView)
        let tapCoordinate = mapView.convertPoint(point, toCoordinateFromView: self.mapView)
        let region = MKCoordinateRegionMake(tapCoordinate, MKCoordinateSpanMake(0.0000005, 0.0000005))
        let mapRect = MKMapRectForCoordinateRegion(region)
        
        var messages:String = ""
        
        for overlay in self.mapView.overlays {
            if(overlay is MKPolyline) {
                let polygon = overlay as PolylineWithAnnotations
                if(polygon.intersectsMapRect(mapRect)) {
                    println(polygon.annotation)
                    messages += polygon.annotation + "; "
                }
            }
        }
        if messages != "" {
            createAlert("Upcoming Restrictions", message: messages)
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