//
//  PhotoCellCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Andrea Bigagli on 21/10/15.
//  Copyright © 2015 Andrea Bigagli. All rights reserved.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var placeholderView: UIView!
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var errorLabel: UILabel!
    
    var thePhoto: Photo! {
        didSet {
            if let newPhoto = thePhoto where newPhoto.status != .waitingForImage {
                self.activityIndicator.stopAnimating()
                
                if newPhoto.status == .completedDownload {
                    
                    self.placeholderView.alpha = 1.0
                    self.photoImageView.alpha = 0.0
                    self.photoImageView.image = newPhoto.downloadedImage!
                    
                    UIView.animateWithDuration(0.2) {
                        self.placeholderView.alpha = 0.0
                        self.photoImageView.alpha = 1.0
                    }
                }
                else {
                    self.errorLabel.hidden = false
                }
            }
        }
    }
    
    override func prepareForReuse() {
        self.activityIndicator.startAnimating()
        self.placeholderView.alpha = 1.0
        self.errorLabel.hidden = true
        self.photoImageView.image = nil
        self.thePhoto = nil
    }
}
