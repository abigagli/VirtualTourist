//
//  Photo.swift
//  VirtualTourist
//
//  Created by Andrea Bigagli on 18/10/15.
//  Copyright © 2015 Andrea Bigagli. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Photo: NSManagedObject {

    enum states
    {
        case waitingForImage
        case completedDownload
        case failedDownload
    }
    
    private static let kFailedDownloadPseudoFilename = "failed_download"
    
    convenience init(photoURL: String, mapPin: Pin, context: NSManagedObjectContext){
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)
        
        //Superclass' init(entity:insertIntoManagedObjectContext) designated initializer is inherited
        //because we don't define ourselves any designated initializer, so we can call such inherited designated initializer
        //by simple self.init delegation here
        self.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        self.url = photoURL
        self.mapPin = mapPin
    }
    
    
    var status: states {
        guard let fileName = self.fileName else {return .waitingForImage}
        
        if fileName == Photo.kFailedDownloadPseudoFilename {
            return .failedDownload
        }
        else {
            return .completedDownload
        }
    }
    
    override func prepareForDeletion() {
        
        if let fileURL = self.imageFileLocalURL {
            do {
                try NSFileManager.defaultManager().removeItemAtURL(fileURL)
            } catch _ {
                print ("Failed deleting photo file")
            }
        }
    }
    
    private var imageFileLocalURL: NSURL? {
        var result: NSURL?
        
        if self.status == .completedDownload {
            result = CoreDataStackManager.sharedInstance.applicationDocumentsDirectory.URLByAppendingPathComponent(self.fileName!)
        }
        
        return result
    }
    
    func didFailImageDownload() {
        self.fileName = Photo.kFailedDownloadPseudoFilename
    }
}


//MARK: UI-related stuff
extension Photo {
    var downloadedImage: UIImage? {
        
        var image: UIImage?
        if let fileURL = self.imageFileLocalURL {
            image = UIImage(contentsOfFile: fileURL.path!)
        }
        
        return image
    }
}
