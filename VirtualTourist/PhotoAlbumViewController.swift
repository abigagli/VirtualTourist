//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Andrea Bigagli on 21/10/15.
//  Copyright © 2015 Andrea Bigagli. All rights reserved.
//

import UIKit
import CoreData
import MapKit

class PhotoAlbumViewController: UIViewController {
    
    static private let miniMapSpanMeters: Double = 15 * 1000 //span for the minimap: 15KM around selected pin

    //MARK: Outlets
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var noPhotosLabel: UILabel!
    @IBOutlet private weak var bottomButtonItem: UIBarButtonItem!

    //MARK: State
    var pin: Pin!   //The pin we're displaying UI for
    
    //Arrays of indexpaths used to make NSFetchedResultsController work with collectionviews
    private var selectedIndexes    = [NSIndexPath]()
    private var insertedIndexPaths = [NSIndexPath]()
    private var deletedIndexPaths  = [NSIndexPath]()
    private var updatedIndexPaths  = [NSIndexPath]()
    
    //MARK: Action
    @IBAction func bottomButtonTapped(sender: UIBarButtonItem) {
        
        if selectedIndexes.count == 0 { //"Get New Photos" behaviour
            
            self.getNewPhotoSet()
            
        }
        else { //"Delete Selected Photos" behaviour
            
            for index in self.selectedIndexes {
                
                //...delete them from the context...
                self.sharedContext.deleteObject(fetchedResultsController.objectAtIndexPath(index) as! Photo)
            }
            
            self.selectedIndexes = []
            
            //...and save.
            CoreDataStackManager.sharedInstance.saveContext()
            
            self.updateUI()
        }
    }
    
    
    //MARK: Lifetime
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapView.delegate = self
        self.mapView.userInteractionEnabled = false
        
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        
        self.fetchedResultsController.delegate = self
        
        do {
            try self.fetchedResultsController.performFetch()
            
            //Update mapView based on the user's pin.
            self.mapView.addAnnotation(pin)
            
            let region = MKCoordinateRegionMakeWithDistance(pin.coordinate, PhotoAlbumViewController.miniMapSpanMeters, PhotoAlbumViewController.miniMapSpanMeters)
            
            self.mapView.setRegion(region, animated: false)
            
        }
        catch {
            self.alertUserWithTitle("Error"
                                    , message: "Couldn't obtain list of photos for this pin. Please try to remove it and add it again"
                                    , retryHandler: nil)
        }
        
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        //If we get here after restarting the application, we might have some photos still to download, so let's try to complete the job
        if pin.pendingDownloads == 0 {
            for photo in self.fetchedResultsController.fetchedObjects as! [Photo] {
                if photo.status == .waitingForImage {
                    self.retryImageDownloadForPhoto(photo)
                }
            }
        }
        
        self.updateUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.updateCellFrame(collectionView.frame.size)
        self.collectionView.collectionViewLayout.invalidateLayout()
    }
    
    //MARK: UI Layout
    private func updateUI() {
        let thereIsSomethingToShow = self.pin.completedDownloads > 0
                                   || self.pin.pendingDownloads > 0
                                   || self.fetchedResultsController.fetchedObjects?.count > 0
        
        self.noPhotosLabel.hidden = thereIsSomethingToShow
        
        if self.selectedIndexes.count > 0 {
            self.bottomButtonItem.title = "Delete selected images"
            self.bottomButtonItem.enabled = true
        } else {
            self.bottomButtonItem.title = "New Collection"
            self.bottomButtonItem.enabled = self.pin.pendingDownloads == 0
        }
    }
    
    private func updateCellFrame(forViewSize: CGSize) {
        let width = (forViewSize.width - 8) / 3.0
        let layout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        
        layout.itemSize = CGSize(width: width, height: width)
    }
    
    private func configureCell(cell: PhotoCollectionViewCell, atIndexPath indexPath: NSIndexPath) {
        
        if let _ = selectedIndexes.indexOf(indexPath) { //If the cell is selected show it dimmed
            
            UIView.animateWithDuration(0.1) {
                cell.photoImageView.alpha = 0.3
            }
        } else { //Otherwise show it normally
            
            UIView.animateWithDuration(0.1) {
                    cell.photoImageView.alpha = 1.0
            }
        }
    }
    
    //MARK: Business Logic
    
    private func retryImageDownloadForPhoto(photo: Photo) {
        
        //Let the implicit state of photo become .waitingForImage...
        photo.fileName = nil
        
        self.pin.pendingDownloads++
        self.bottomButtonItem.enabled = false
        
        CoreDataStackManager.sharedInstance.saveContext()
        
        FlickrClient.sharedInstance.getImageForPhoto(photo.url) /* And then, on another thread...*/ {
            fileName, error in
            
            dispatch_async(dispatch_get_main_queue()) { //managedObjectContext must be used on the owner (main in this case) thread only
                
                if let fileName = fileName {
                    photo.fileName = fileName
                    self.pin.pendingDownloads--
                    self.pin.completedDownloads++
                    
                    CoreDataStackManager.sharedInstance.saveContext()
                    
                }
                else {
                    photo.didFailImageDownload()
                    self.pin.pendingDownloads--
                    
                    print ("FAILED retrying image download for \(photo.url)")
                }
                
                self.updateUI()

            }
        }
    }

    
    private func getNewPhotoSet() {
        
        /****** PHASE 1 ******/
        //1.1 Forcely set these to give the user immediate feedback,
        //everything will eventually be set properly through updateUI
        self.bottomButtonItem.enabled = false
        self.noPhotosLabel.hidden = true

        //1.2 Clean up fetchedResultsController's contents...
        for photo in self.fetchedResultsController.fetchedObjects as! [Photo] {
            
            self.sharedContext.deleteObject(photo)
        }
        
        //1.3 ...And take a snapshot of where we are
        CoreDataStackManager.sharedInstance.saveContext()
        
        
        /****** PHASE 2 ******/
        //Clean up completed, let's start again just as the pin had
        //just been dropped onto the map
        
        FlickrClient.sharedInstance.getPhotosForPin(pin) /* And then, on another thread...*/ {
            success, error in
            
            dispatch_async(dispatch_get_main_queue()) { //Touch the UI on the main thread only
                if !success {
                    self.alertUserWithTitle("Error"
                                            , message: "Failed downloading photos for current pin: \(error!.localizedDescription)"
                                            , retryHandler: {self.getNewPhotoSet()})
                }
                
                self.updateUI()
                
            }
        }
    }

    
    //MARK: Core Data
    private lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance.managedObjectContext
        }()
    
    private lazy var fetchedResultsController: NSFetchedResultsController = {
        
        //create fetch request with sort descriptor
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "mapPin == %@", self.pin)
        fetchRequest.sortDescriptors = []

        //create controller from fetch request
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        //fetchedResultsController.delegate = self
        return fetchedResultsController
        }()

}

//MARK: -------------- Protocol conformance -----------------

//MARK:  UICollectionViewDataSource

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let sectionInfo = self.fetchedResultsController.sections![section]
            
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCellID", forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        cell.thePhoto = (fetchedResultsController.objectAtIndexPath(indexPath) as! Photo)
        
        self.configureCell(cell, atIndexPath: indexPath)
        
        return cell
    }
}
//MARK: - UICollectionViewDelegate

extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        
        //Disallow selection if the cell is still waiting for its image to appear.
        if cell.thePhoto!.status == .waitingForImage {
            return false
        }
        
        return true
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        
        if cell.thePhoto!.status == .failedDownload {
            cell.errorLabel.hidden = true
            cell.activityIndicator.startAnimating()
            cell.photoImageView.alpha = 0.0
            cell.photoImageView.image = nil
            
            retryImageDownloadForPhoto(cell.thePhoto)
            return
        }
    
        
        //If the user touches a cell, add or remove it from the selectedIndexes array...
        if let index = selectedIndexes.indexOf(indexPath) {
            selectedIndexes.removeAtIndex(index)
        } else {
            selectedIndexes.append(indexPath)
        }
        
        //...reconfigure the cell...
        configureCell(cell, atIndexPath: indexPath)
        
        //...and update the newCollectionButton.
        self.updateUI()
    }
}

//MARK: MKMapViewDelegate
extension PhotoAlbumViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "travelLocationPin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.pinTintColor = UIColor.greenColor()
            
            pinView!.animatesDrop = false
            
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
}



//MARK: NSFetchedResultsControllerDelegate
extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        
        //Prepare for didChange delegate
        self.insertedIndexPaths.removeAll()
        self.deletedIndexPaths.removeAll()
        self.updatedIndexPaths.removeAll()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        //Add changed objects' indexPaths to the proper array
        switch type {
        case .Insert:
            self.insertedIndexPaths.append(newIndexPath!)
            
        case .Delete:
            self.deletedIndexPaths.append(indexPath!)
            
        case .Update:
            self.updatedIndexPaths.append(indexPath!)
            
        default:
            break
        }
        
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        
        collectionView.performBatchUpdates({
            
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion: nil)
        
        self.updateUI()
    }
}
