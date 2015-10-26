//
//  TravelLocationsMapViewController.swift
//  VirtualTourist
//
//  Created by Andrea Bigagli on 18/10/15.
//  Copyright © 2015 Andrea Bigagli. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController {

    //MARK: Outlets
    @IBOutlet private weak var mapView: MKMapView!
    
    @IBOutlet private weak var bottomConstraint: NSLayoutConstraint!
    //MARK: Actions
    @IBAction private func longPressDetected(sender: UIGestureRecognizer) {
        
        //Don't want to allow adding pins while in "Edit", i.e. tapping-to-delete, mode
        guard !self.deletingAnnotations else {return}
        
        let point = sender.locationInView(self.mapView)
        let coordinates = self.mapView.convertPoint(point, toCoordinateFromView: self.mapView)
        
        switch sender.state
        {
        case .Began:
            //We can eagerly add the pin being added to Core Data as there is no way to stop adding it once
            //long tap has begun
            self.pinBeingAdded = Pin(latitude: coordinates.latitude, longitude: coordinates.longitude, context: self.sharedContext)
            self.mapView.addAnnotation(self.pinBeingAdded!)

        case .Changed:
            self.pinBeingAdded!.willChangeValueForKey("coordinate")
            self.pinBeingAdded!.coordinate = coordinates
            self.pinBeingAdded!.didChangeValueForKey("coordinate")
            
        case .Ended:
            fetchPhotosForPin (self.pinBeingAdded!)
            CoreDataStackManager.sharedInstance.saveContext()
            
        default:
            break;
        }
    }

    @IBAction private func toggleEdit(sender: UIBarButtonItem) {
        if sender.title! == "Edit" {
            sender.title = "Done"
            self.deletingAnnotations = true
            self.bottomConstraint.constant = 44.0
            UIView.animateWithDuration(0.5, animations: {
                self.view.layoutIfNeeded()
            })
        }
        else {
            sender.title = "Edit"
            self.deletingAnnotations = false
            self.bottomConstraint.constant = 0
            UIView.animateWithDuration(0.7, animations: {
                self.view.layoutIfNeeded()
            })
        }
        
    }
    
    //MARK: State
    private var deletingAnnotations = false

    //TODO: NEED DRAGGING?
    //private var dragStartPin: Pin?
    
    private var pinBeingAdded: Pin?
    
    
    //MARK: Controller lifetime
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapView.delegate = self
        self.fetchedResultsController.delegate = self
        
        do {
            try self.fetchedResultsController.performFetch()
            
            self.mapView.addAnnotations(self.fetchedResultsController.fetchedObjects as! [MKAnnotation])
            updateUI()
        }
        catch {
            print ("Failed to performFetch! No annotations can be retrieved")
        }

        self.restoreMapRegion(false)
    }
    
    
    //MARK: Core Data
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance.managedObjectContext
        }()
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        //create fetch request with sort descriptor
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true), NSSortDescriptor(key: "longitude", ascending: true)]
        
        //create controller from fetch request
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        return fetchedResultsController
        }()
    
    
    //MARK: Business Logic
    private func updateUI() {
        self.navigationItem.rightBarButtonItem!.enabled = self.fetchedResultsController.fetchedObjects?.count > 0
    }
    
    private func fetchPhotosForPin(pin: Pin) {
        
        FlickrClient.sharedInstance.getPhotosForPin(pin) /* And then, on another thread...*/ {
            success, error in
            
            if !success {
                
                //Something wrong with photo download, alert the user and offer
                //opportunity to retry
                dispatch_async(dispatch_get_main_queue()) { //Touch the UI on the main thread only
                    self.alertUserWithTitle("Error"
                        , message: "Failed downloading photos for current pin: \(error!.localizedDescription)"
                        , retryHandler: {self.fetchPhotosForPin(pin)})
                }
            }
        }
    }
 

    //MARK: - Navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowPhotoAlbumViewControllerSegue" {
            let photosVC = segue.destinationViewController as! PhotoAlbumViewController
            photosVC.pin = sender?.annotation as! Pin
        }
    }
}

//MARK: -------------- Protocol conformance -----------------


//MARK: NSFetchedResultsControllerDelegate
extension TravelLocationsMapViewController: NSFetchedResultsControllerDelegate {
    func controller(controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {

        
        switch type {
        case .Insert:
            self.mapView.addAnnotation(anObject as! MKAnnotation)
            self.updateUI()
            
        case .Delete:
            self.mapView.removeAnnotation(anObject as! MKAnnotation)
            
            if self.fetchedResultsController.fetchedObjects?.count == 0 {
                //No reason to stay in "Edit" mode once all annotations have been removed...
                //"Simulate" rightBarButtonItem press and updateUI accordingly
                self.toggleEdit(self.navigationItem.rightBarButtonItem!)
                self.updateUI()
            }
            
        default:
            break
        }
        
    }
}

//MARK: MKMapViewDelegate
extension TravelLocationsMapViewController: MKMapViewDelegate
{
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "travelLocationPin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.pinTintColor = UIColor.greenColor()
            
            //TODO: NEED DRAGGING?
            //pinView!.draggable = true
            
            pinView!.animatesDrop = true
            
        }
        else {
            pinView!.annotation = annotation
        }
        
        //TODO: NEED DRAGGING? Make sure it is selected, so that dragging starts immediately, see mapView(_:didSelectAnnotationView) below...
        //pinView!.setSelected(true, animated: false)
        return pinView
    }
    
    //TODO: NEED DRAGGING?
    /*
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        
        if (newState == .Starting) {
            //print ("drag starting")
            self.dragStartPin = view.annotation as? Pin
        }
        
        if (newState == .Ending) {
            //print ("drag ending")
            self.sharedContext.deleteObject(self.dragStartPin!)

            self.dragStartPin = nil
            
            _ = Pin(latitude: view.annotation!.coordinate.latitude, longitude: view.annotation!.coordinate.longitude, context: self.sharedContext)
            
            CoreDataStackManager.sharedInstance.saveContext()
        }
    }
    */
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        self.saveMapRegion()
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        //Remove selection, this is just a one-tap thing...
        mapView.deselectAnnotation(view.annotation, animated: false)
        
        if self.deletingAnnotations {
            
            if let currentPin = view.annotation as? Pin {
                
                if currentPin.pendingDownloads > 0 {
                    self.alertUserWithTitle("Notice", message: "Current pin has pending downloads. Wait until completed before deleting", retryHandler: nil)
                }
                else {
                    self.sharedContext.deleteObject(currentPin)
                    CoreDataStackManager.sharedInstance.saveContext()
                }
            }
        }
        else {
            //Hijack the sender argument to pass the pin that triggered the segue
            performSegueWithIdentifier("ShowPhotoAlbumViewControllerSegue", sender: view)
        }
    }
    
    //TODO: NEED DRAGGING?
    /*
    func mapView(mapView: MKMapView, didDeselectAnnotationView view: MKAnnotationView) {
        //Ensure annotation views always remain selected so that drag starts immediately without requiring
        //to first select them
        view.setSelected(true, animated: false)
    }
    */
}

//MARK: Map region preservation
extension TravelLocationsMapViewController
{
    var filePath : String {
        let url = CoreDataStackManager.sharedInstance.applicationDocumentsDirectory
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    func saveMapRegion() {
        
        //Persist center and span of the map into a dictionary
        //for later rerieval
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }
    
    func restoreMapRegion(animated: Bool) {
        
        //Restore the map back to the persisted region
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            self.mapView.setRegion(savedRegion, animated: animated)
        }
    }

}
