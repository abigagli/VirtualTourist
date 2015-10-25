//
//  Pin.swift
//  VirtualTourist
//
//  Created by Andrea Bigagli on 18/10/15.
//  Copyright © 2015 Andrea Bigagli. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class Pin: NSManagedObject {

    convenience init(latitude: Double, longitude: Double, context: NSManagedObjectContext){
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)
        
        //Superclass' init(entity:insertIntoManagedObjectContext) designated initializer is inherited
        //because we don't define ourselves any designated initializer, so we can call such inherited designated initializer
        //by simple self.init delegation here
        self.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        self.latitude = latitude
        self.longitude = longitude
        self.photoPages = 0
    }
    
    var pendingDownloads = 0
    var completedDownloads = 0
    let numPhotosToRequest = 30 //Chosen to fit evenly on a collectionview grid of 3x5 / 5x3
}

extension Pin: MKAnnotation {
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D (latitude: self.latitude, longitude: self.longitude)
        }
        
        set {
            self.latitude = newValue.latitude
            self.longitude = newValue.longitude
        }
    }
}
