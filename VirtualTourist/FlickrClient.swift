//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Andrea Bigagli on 21/10/15.
//  Copyright © 2015 Andrea Bigagli. All rights reserved.

import Foundation
import CoreData

class FlickrClient {
    
    //MARK: Singleton
    static let sharedInstance = FlickrClient()
    
    //private init enforces singleton usage
    private init() {
        session = NSURLSession.sharedSession()
    }

    //MARK: State
    var session: NSURLSession
    
    
    
    //MARK: Business Logic
    private func getWithParameters (parameters: [String : AnyObject],
        completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
            
            //Build the URL and URL request specific to the website required.
            let urlString = Constants.BaseFlickrURL + FlickrClient.escapedParameters(parameters)
            let request = NSMutableURLRequest(URL: NSURL(string: urlString)!)
            
            //Make the request.
            let task = session.dataTaskWithRequest(request) {
                data, response, downloadError in
                
                //Parse the received data.
                if let error = downloadError {
                    
                    let newError = FlickrClient.errorForData(data, response: response, error: error)
                    completionHandler(result: nil, error: newError)
                } else {
                    
                    FlickrClient.parseJSONWithCompletionHandler(data!, completionHandler: completionHandler)
                }
            }
            
            //Start the request task.
            task.resume()
    }
    
    private func getWithURLString(urlString: String,
        completionHandler: (result: NSData?, error: NSError?) -> Void) {
            
            //Create request with urlString.
            let request = NSMutableURLRequest(URL: NSURL(string: urlString)!)
            
            //Make the request.
            let task = session.dataTaskWithRequest(request) {
                data, response, downloadError in
                
                if let error = downloadError {
                    
                    let newError = FlickrClient.errorForData(data, response: response, error: error)
                    completionHandler(result: nil, error: newError)
                } else {
                    
                    completionHandler(result: data, error: nil)
                }
            }
            
            //Start the request task.
            task.resume()
    }
    
    //MARK: Helpers
    
    //Everything below is taken from the Movie Manager example
    
    //Escape parameters and make them URL-friendly
    class func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            let stringValue = "\(value)"
            let replaceSpaceValue = stringValue.stringByReplacingOccurrencesOfString(" ", withString: "+", options: .LiteralSearch, range: nil)
            urlVars += [key + "=" + "\(replaceSpaceValue)"]
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    //Check to see if there is a received error, if not, return the original local error.
    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        
        if let data = data, parsedResult = (try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)) as? [String : AnyObject] {
            
            if let status = parsedResult[JSONResponseKeys.Status]  as? String,
                  message = parsedResult[JSONResponseKeys.Message] as? String {
                    
                if status == JSONResponseValues.Failure {
                    
                    let userInfo = [NSLocalizedDescriptionKey: message]
                    
                    return NSError(domain: "Virtual Tourist Error", code: 1, userInfo: userInfo)
                }
            }
        }
        return error
    }

    //Parse the received JSON data and pass it to the completion handler.
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
        
        var parsingError: NSError?
        let parsedResult: AnyObject?
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
        } catch let error as NSError {
            parsingError = error
            parsedResult = nil
        }
        
        if let error = parsingError {
            
            completionHandler(result: nil, error: error)
        } else {
            
            completionHandler(result: parsedResult, error: nil)
        }
    }
}

//MARK: Convenience
extension FlickrClient {
    
    func getPhotosForPin(pin: Pin, completionHandler: (success: Bool, error: NSError?) -> Void) {
        
        var pageToRequest: UInt32 = 1
        
        //If we already downloaded photos for this location, we know how many pages of photos are available
        //Now, to overcome the infamous "Flickr has a limit of 4000 photos per query" issue
        //(see https://discussions.udacity.com/t/virtualtourist-why-is-flickr-returning-the-same-photos/30977/9)
        //we determine the max pagenumber we can request and generate a random page number in that range
        
        pin.pendingDownloads = pin.numPhotosToRequest
        pin.completedDownloads = 0

        if pin.photoPages > 0 {
            let maxPageToAvoidRepeatedImages = min(pin.photoPages, Int64(4000 / pin.numPhotosToRequest))
            
            pageToRequest = arc4random_uniform(UInt32(maxPageToAvoidRepeatedImages)) + 1
            
        }
        
        //Parameters for API invocation
        let parameters: [String : AnyObject] = [
            
            URLKeys.Method         : Methods.Search,
            URLKeys.APIKey         : Constants.FlickrAPIKey,
            URLKeys.DataFormat     : URLValues.JSONDataFormat,
            URLKeys.NoJSONCallback : 1,
            URLKeys.Latitude       : pin.coordinate.latitude,
            URLKeys.Longitude      : pin.coordinate.longitude,
            URLKeys.Extras         : URLValues.MediumPhotoURL,
            URLKeys.Page           : Int(pageToRequest),
            URLKeys.PerPage        : pin.numPhotosToRequest
        ]
        
        getWithParameters(parameters) /* And then, on another thread... */ {
            results, error in
            
            if let error = error {
                pin.pendingDownloads = 0
                completionHandler(success: false, error: error)
            }
            else {
                //If we get some photos...
                if let photosDictionary = results.valueForKey(JSONResponseKeys.Photos) as? [String: AnyObject],
                            photosArray = photosDictionary[JSONResponseKeys.Photo]     as? [[String : AnyObject]],
                     numberOfPhotoPages = photosDictionary[JSONResponseKeys.Pages]     as? Int {
                        
                        //If it's the first time we get photos for this pin, remember the number of pages
                        //of photos we can get, which will use when getting new photos for this same pin
                        //to try to randomize things a bit...
                        dispatch_async(dispatch_get_main_queue()) { //managedObjectContext must be used on the owner (main in this case) thread only
                            pin.photoPages = Int64(numberOfPhotoPages)
                        }
                        
                        //Just in case there were less available photos than requested,
                        //let's set this again
                        pin.pendingDownloads = photosArray.count
                        
                        
                        //After creating a photo managedobject, I want to "find" it after I retrieved its image
                        //so that I can set its filename property
                        //So I'm using a dictionary keyed by the photo URL
                        var photoForURL = [String : Photo]()
                        
                        
                        //Now loop on each available photo
                        for photoDictionary in photosArray {
                            
                            let photoURLString = photoDictionary[URLValues.MediumPhotoURL] as! String
                            
                            
                            dispatch_async(dispatch_get_main_queue()) { //managedObjectContext must be used on the owner (main in this case) thread only
                                let newPhoto = Photo(photoURL: photoURLString, mapPin: pin, context: self.sharedContext)
                                photoForURL[photoURLString] = newPhoto
                            }
                            
                            //...then attempt to get the image from the URL.
                            self.getImageForPhoto(photoURLString) /* And then, on another thread...*/ {
                                fileName, error in
                                
                                
                                dispatch_async(dispatch_get_main_queue()) { //managedObjectContext must be used on the owner (main in this case) thread only
                                    
                                    let photoToUpdate = photoForURL[photoURLString]!
                                    
                                    if let fileName = fileName {
                                        photoToUpdate.fileName = fileName
                                        pin.pendingDownloads--
                                        pin.completedDownloads++
                                    }
                                    else {
                                        photoToUpdate.didFailImageDownload()
                                        pin.pendingDownloads--
                                        
                                        print ("FAILED downloading image for \(photoURLString)")
                                    }
                                    
                                    CoreDataStackManager.sharedInstance.saveContext()
                                    
                                    if pin.pendingDownloads == 0 {
                                        print ("******* COMPLETED NETWORK ACTIVITY ********")
                                        completionHandler(success: true, error: nil)
                                    }
                                }
                            }
                        }
                        
                } else {
                    
                    pin.pendingDownloads = 0
                    completionHandler(success: false, error: NSError(domain: "getPhotosForPin", code: 0, userInfo: nil))
                }
            }
        }
    }
    
    func getImageForPhoto(photoURL: String, completionHandler: (photoLocalFileName: String?, error: NSError?) -> Void) {
        
        getWithURLString(photoURL) /* And then, on another thread...*/ {
            result, error in
            
            if let error = error {
                completionHandler(photoLocalFileName: nil, error: error)
            }
            else {
                //If we get a result...
                if let result = result {
                    
                    let fileName = NSURL.fileURLWithPath(photoURL).lastPathComponent!
                    
                    let filePath = CoreDataStackManager.sharedInstance.applicationDocumentsDirectory.URLByAppendingPathComponent(fileName).path!
                    //...save it...
                    NSFileManager.defaultManager().createFileAtPath(filePath, contents: result, attributes: nil)
                    
                    completionHandler(photoLocalFileName: fileName, error: nil)
                }
            }
        }
    }
    
    // MARK: - Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        
        return CoreDataStackManager.sharedInstance.managedObjectContext
    }
}

//MARK: API Definitions
extension FlickrClient {
    
    //MARK: Constants
    
    struct Constants {
        
        //MARK: Keys
        static let FlickrAPIKey  = "179b7fd3c8aa795d20835862e25140ca"
        
        //MARK: URLs
        static let BaseFlickrURL = "https://api.flickr.com/services/rest/"
    }
    
    //MARK: Methods
    
    struct Methods {
        
        static let Search = "flickr.photos.search"
    }

    //MARK: URL Keys
    
    struct URLKeys {
        
        static let APIKey         = "api_key"
        static let BoundingBox    = "bbox"
        static let DataFormat     = "format"
        static let Extras         = "extras"
        static let Latitude       = "lat"
        static let Longitude      = "lon"
        static let Method         = "method"
        static let NoJSONCallback = "nojsoncallback"
        static let Page           = "page"
        static let PerPage        = "per_page"
    }

    //MARK: URL Values
    
    struct URLValues {
    
        static let JSONDataFormat = "json"
        static let MediumPhotoURL = "url_m"
    }
    
    //MARK: JSON Response Keys
    
    struct JSONResponseKeys {
    
        static let Status  = "stat"
        static let Code    = "code"
        static let Message = "message"
        static let Pages   = "pages"
        static let Photos  = "photos"
        static let Photo   = "photo"
    }
    
    //MARK: JSON Response Values
    
    struct JSONResponseValues {
    
        static let Failure = "fail"
        static let Success = "ok"
    }
}
