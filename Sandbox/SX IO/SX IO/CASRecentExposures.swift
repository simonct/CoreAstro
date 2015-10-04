//
//  CASRecentExposures.swift
//  SX IO
//
//  Created by Simon Taylor on 7/7/15.
//  Copyright © 2015 Simon Taylor. All rights reserved.
//

import Cocoa
import CoreAstro

private func convert<T, U>(source: [T?], converter: (T) -> U?) -> [U] {
    var u = [U]();
    for t in source {
        if t != nil {
            if let x = converter(t!) {
                u.append(x)
            }
        }
    }
    return u
}

private func convert<T, U>(source: [T], converter: (T) -> U?) -> [U] { // presumably a better way to handle this
    var u = [U]();
    for t in source {
        if let x = converter(t) {
            u.append(x)
        }
    }
    return u
}

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
            
            // Swift 2
//            return recents!.flatMap { s in
//                return NSURL(string: s as String)
//            }
            
            return convert(recents!, converter: {
                return NSURL(string: $0 as String)
            })
        }
        set {
            
            // Swift 2
//            defaultsDomain["RecentURLs"] = newValue.map { url in
//                return url.absoluteString
//            }
            
            defaultsDomain["RecentURLs"] = convert(newValue, converter: {
                return $0.absoluteString
            })
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