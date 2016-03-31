//
//  CASRecentExposures.swift
//  SX IO
//
//  Created by Simon Taylor on 7/7/15.
//  Copyright © 2015 Simon Taylor. All rights reserved.
//

import Cocoa
import CoreAstro

extension CASCameraController {
    
    private var deviceDefaults : CASDeviceDefaults {
        get {
            return CASDeviceDefaults(forClassname: self.device.deviceName);
        }
    }
    
    private var defaultsDomain: [NSObject:AnyObject] {
        get {
            return deviceDefaults.domain
        }
        set {
            deviceDefaults.domain = newValue
        }
    }
        
    var recentURLs: [NSURL] {
        get {
            var recents = defaultsDomain["RecentURLs"] as? [NSString]
            if recents == nil {
                recents = [NSString]()
            }
            return recents!.flatMap { s in
                return NSURL(string: s as String)
            }
        }
        set {
            defaultsDomain["RecentURLs"] = newValue.map { url in
                return url.absoluteString
            }
        }
    }
    
    func addRecentURL(url: NSURL?) {
        if url != nil {
            var recent = recentURLs
            if recent.count >= 100 {
                recent = Array(recent[0..<100])
            }
            recent.insert(url!, atIndex: 0)
            recentURLs = recent
        }
    }
}