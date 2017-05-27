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
        case .seconds:
            subtitle += ", \(settings.exposureDuration)s"
        case .milliseconds:
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

        NotificationCenter.default.addObserver(self, selector: #selector(exposureStarted(_:)), name:NSNotification.Name.casCameraControllerExposureStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(exposureCompleted(_:)), name:NSNotification.Name.casCameraControllerExposureCompleted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(filterSelected(_:)), name:NSNotification.Name.casFilterWheelControllerSelectedFilter, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func postLocalNotification(_ title: String, subtitle: String? = nil) {
        if (!postLocalNotifications){
            return
        }
        let note = NSUserNotification();
        note.title = title;
        note.subtitle = subtitle;
        note.soundName = NSUserNotificationDefaultSoundName;
        NSUserNotificationCenter.default.deliver(note);
        var message = title
        if (subtitle != nil) {
            message = message + ": \(String(describing: subtitle))"
        }
//        print(message)
    }
    
    func exposureStarted(_ note: Notification) {
        var subtitle: String?
        if let camera = note.object as? CASCameraController {
            if camera.settings.continuous || camera.settings.exposureType != kCASCCDExposureLightType {
                return
            }
            subtitle = camera.notificationSubtitle
        }
        postLocalNotification("Exposure started", subtitle: subtitle)
    }

    func exposureCompleted(_ note: Notification) {
        var subtitle: String?
        if let _ = (note as NSNotification).userInfo?["error"] as? NSError {
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
    
    func filterSelected(_ note: Notification) {
        if let filter = (note as NSNotification).userInfo?["filter"] as? String {
            postLocalNotification("Filter \(filter) selected")
        }
        else {
            postLocalNotification("Filter selected")
        }
    }
}
