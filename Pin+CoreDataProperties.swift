//
//  Pin+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Andrea Bigagli on 22/10/15.
//  Copyright © 2015 Andrea Bigagli. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Pin {

    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var photoPages: Int64
    //@NSManaged var photos: NSOrderedSet?
    @NSManaged var photos: [Photo]

}
