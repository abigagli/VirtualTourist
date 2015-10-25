//
//  AppDelegate.swift
//  VirtualTourist
//
//  Created by Andrea Bigagli on 18/10/15.
//  Copyright © 2015 Andrea Bigagli. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        CoreDataStackManager.sharedInstance.saveContext()
    }

}


extension UIViewController {
    func alertUserWithTitle(title: String, message: String, retryHandler: (()->Void)?) {
        
        let alert = UIAlertController(title: title,
            message: message,
            preferredStyle: .Alert)
        
        let alertOkAction = UIAlertAction(title: "OK",
            style: .Default,
            handler: nil)
        
        if let userRetry = retryHandler {
            
            let alertRetryAction = UIAlertAction(title: "Retry",
                style: UIAlertActionStyle.Destructive,
                handler: {
                    _ in
                    userRetry()
            })
            alert.addAction(alertRetryAction)
        }
        
        alert.addAction(alertOkAction)
        
        //Ensure presentation is always done by a visible viewcontroller, since with
        //particularly slow network connections, the user might have pushed/popped 
        //before the alert is presented
        UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
}


