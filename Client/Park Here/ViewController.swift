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
        lookupSweepingForLocation(location)
        
        locationManager?.stopUpdatingHeading()
        locationManager?.stopUpdatingLocation()
        locationManager?.stopMonitoringSignificantLocationChanges()
    }
    
    func lookupSweepingForLocation(location:CLLocation) {
        let coordinate = location.coordinate
        
        let url = NSURL(string: "http://192.168.1.113:5000/nearby/\(coordinate.latitude)/\(coordinate.longitude)")
        
        var jsonError: NSError?
        
        let tap = UITapGestureRecognizer(target: self, action: Selector("handleOverlayTap:"))
        tap.delegate = self
        mapView.addGestureRecognizer(tap)

//        let point:CGPoint = 
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            if let results = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &jsonError) as? NSArray {
                for result in results {
                    let geometryType = result.valueForKeyPath("datapoint.geometry.type") as String
                    let coordinates = result.valueForKeyPath("datapoint.geometry.coordinates") as NSArray
                    if geometryType == "LineString" {
                        var linepath:[CLLocationCoordinate2D] = []
                        for cord in coordinates {
                            let c = CLLocationCoordinate2DMake(cord[1] as CLLocationDegrees, cord[0] as CLLocationDegrees)
                            linepath.append(c)
                        }
//                        let polyline2 = (
                        let polyline = PolylineWithAnnotations(coordinates: &linepath, count: linepath.count)
                        polyline.annotation = result.valueForKeyPath("description") as String
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
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func handleOverlayTap(tap: UITapGestureRecognizer) {
        
        let point = tap.locationInView(self.mapView)
        let tapCoordinate = mapView.convertPoint(point, toCoordinateFromView: self.mapView)
        let region = MKCoordinateRegionMake(tapCoordinate, MKCoordinateSpanMake(0.000005, 0.000005))
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
            createAlert("Upcoming Parking Restrctions", message: messages)
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