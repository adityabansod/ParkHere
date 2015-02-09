//
//  Geospatial.swift
//  Park Here
//
//  Created by Aditya Bansod on 2/8/15.
//  Copyright (c) 2015 Aditya Bansod. All rights reserved.
//

import Foundation
import MapKit
import CoreLocation

class Geospatial {
    class func findMaxDimensionsOfMap(mapView: MKMapView!) -> Int {
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

    class func wgs84distance(loc1:CLLocationCoordinate2D, loc2:CLLocationCoordinate2D) -> Double {
        
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
}