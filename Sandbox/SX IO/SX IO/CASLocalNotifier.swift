//
//  CASLocalNotifier.swift
//  SX IO
//
//  Created by Simon Taylor on 6/27/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

import Cocoa
import CoreAstro

extension CASCameraController {
    var notificationSubtitle: String {
        var subtitle: String = camera.deviceName
        switch settings.exposureUnits {
        case .Seconds:
            subtitle += ", \(settings.exposureDuration)s"
        case .Milliseconds:
            subtitle += ", \(settings.exposureDuration)ms"
        }
        subtitle += ", \(settings.binning)x\(settings.binning)"
        if let currentFilterName = filterWheel?.currentFilterName {
            subtitle += ", \(currentFilterName)"
        }
        return subtitle
    }
}

class CASLocalNotifier: NSObject {

    static var sharedInstance = CASLocalNotifier()
    
    var postLocalNotifications: Bool = true
    
    override init() {
        
        super.init()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(exposureStarted(_:)), name:kCASCameraControllerExposureStartedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(exposureCompleted(_:)), name:kCASCameraControllerExposureCompletedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(filterSelected(_:)), name:kCASFilterWheelControllerSelectedFilterNotification, object: nil)
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
        var message = title
        if (subtitle != nil) {
            message = message + ": \(subtitle)"
        }
//        print(message)
    }
    
    func exposureStarted(note: NSNotification) {
        var subtitle: String?
        if let camera = note.object as? CASCameraController {
            if camera.settings.continuous || camera.settings.exposureType != kCASCCDExposureLightType {
                return
            }
            subtitle = camera.notificationSubtitle
        }
        postLocalNotification("Exposure started", subtitle: subtitle)
    }

    func exposureCompleted(note: NSNotification) {
        var subtitle: String?
        if let _ = note.userInfo?["error"] as? NSError {
            postLocalNotification("Exposure failed")
        }
        else {
            if let camera = note.object as? CASCameraController {
                if camera.settings.continuous || camera.settings.exposureType != kCASCCDExposureLightType {
                    return
                }
                subtitle = camera.notificationSubtitle
            }
            postLocalNotification("Exposure completed", subtitle: subtitle)
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
