//
//  CASLocalNotifier.swift
//  SX IO
//
//  Created by Simon Taylor on 6/27/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

import Cocoa
import CoreAstro

class CASLocalNotifier: NSObject {

    static var sharedInstance = CASLocalNotifier()
    
    var postLocalNotifications: Bool = false
    
    override init() {
        
        super.init()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("exposureStarted:"), name:kCASCameraControllerExposureStartedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("exposureCompleted:"), name:kCASCameraControllerExposureCompletedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("filterSelected:"), name:kCASFilterWheelControllerSelectedFilterNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func postLocalNotification(title: String, subtitle: String? = nil) {
        if (!postLocalNotifications){
            return
        }
        let note = NSUserNotification();
        note.title = title;
        note.subtitle = subtitle;
        note.soundName = NSUserNotificationDefaultSoundName;
        NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(note);
    }
    
    func exposureStarted(note: NSNotification) {
        postLocalNotification("Exposure started")
    }

    func exposureCompleted(note: NSNotification) {
        if let _ = note.userInfo?["error"] as? NSError {
            postLocalNotification("Exposure failed")
        }
        else {
            postLocalNotification("Exposure completed")
        }
    }
    
    func filterSelected(note: NSNotification) {
        if let filter = note.userInfo?["filter"] as? String {
            postLocalNotification("Filter \(filter) selected")
        }
        else {
            postLocalNotification("Filter selected")
        }
    }
}
