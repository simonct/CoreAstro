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
    
    fileprivate var deviceDefaults : CASDeviceDefaults {
        get {
            return CASDeviceDefaults(forClassname: self.device.deviceName);
        }
    }
    
    fileprivate var defaultsDomain: [AnyHashable: Any] {
        get {
            return deviceDefaults.domain
        }
        set {
            deviceDefaults.domain = newValue
        }
    }
        
    @objc var recentURLs: [URL] {
        get {
            var recents = defaultsDomain["RecentURLs"] as? [NSString]
            if recents == nil {
                recents = [NSString]()
            }
            return recents!.flatMap { s in
                return URL(string: s as String)
            }
        }
        set {
            defaultsDomain["RecentURLs"] = newValue.map { url in
                return url.absoluteString
            }
        }
    }
    
    @objc func addRecentURL(_ url: URL?) {
        if url != nil {
            var recent = recentURLs
            if recent.count >= 100 {
                recent = Array(recent[0..<100])
            }
            recent.insert(url!, at: 0)
            recentURLs = recent
        }
    }
}
