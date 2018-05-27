//
//  CASBookmarks.swift
//  SX IO
//
//  Created by Simon Taylor on 11/09/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//
// Put into the framework, there's no explicit reference here to the host app
//

import Foundation


open class CASBookmarks: NSObject {
    
    static fileprivate let defaultsKey = "CASBookmarks"
    
    open static let nameKey = "name"
    open static let centreRaKey = "centreRa"
    open static let centreDecKey = "centreDec"
    open static let solutionDictionaryKey = "solutionDictionary"
    
    open static let sharedInstance = CASBookmarks()
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(CASBookmarks.storeDidChange(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        NSUbiquitousKeyValueStore.default.synchronize()
        if let bookmarks = NSUbiquitousKeyValueStore.default.dictionaryRepresentation[CASBookmarks.defaultsKey] as? Array<NSDictionary> {
            print("CASBookmarks.init, \(bookmarks.count) bookmark(s) in iCloud")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    open var bookmarks: [NSDictionary] {
        get {
            return UserDefaults.standard.object(forKey: CASBookmarks.defaultsKey) as? [NSDictionary] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: CASBookmarks.defaultsKey)
            NSUbiquitousKeyValueStore.default.set(newValue, forKey: CASBookmarks.defaultsKey)
        }
    }
    
    fileprivate func appendBookmark(_ bookmark: NSDictionary) {
        willChangeValue(forKey: "bookmarks")
        var bookmarks = self.bookmarks;
        bookmarks.append(bookmark)
        self.bookmarks = bookmarks
        didChangeValue(forKey: "bookmarks")
    }
    
    open func addBookmark(_ name: String, solution: CASPlateSolveSolution) {
        if (!name.isEmpty){
            if let solutionDictionary = solution.solutionDictionary() {
                appendBookmark(NSDictionary(objects:[name,solutionDictionary],forKeys:[CASBookmarks.nameKey as NSCopying,CASBookmarks.solutionDictionaryKey as NSCopying]));
            }
        }
    }
    
    open func addBookmark(_ name: String, ra: Double, dec: Double) {
        if (!name.isEmpty){
            appendBookmark(NSDictionary(objects:[name,ra,dec],forKeys:[CASBookmarks.nameKey as NSCopying,CASBookmarks.centreRaKey as NSCopying,CASBookmarks.centreDecKey as NSCopying]));
        }
    }
    
    @objc open func storeDidChange(_ note: Notification) { // interestingly, can't be private otherwise the notification fails with selector not found
        print("storeDidChange \(String(describing: (note as NSNotification).userInfo))")
        if let changedKeys = (note as NSNotification).userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? Array<String>,
            let reason = (note as NSNotification).userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
            let _ = changedKeys.index(of: CASBookmarks.defaultsKey){
                switch(reason){
                case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange, NSUbiquitousKeyValueStoreAccountChange:
                    if let bookmarks = NSUbiquitousKeyValueStore.default.array(forKey: CASBookmarks.defaultsKey) {
                        UserDefaults.standard.set(bookmarks, forKey: CASBookmarks.defaultsKey)
                    }
                    else {
                        UserDefaults.standard.removeObject(forKey: CASBookmarks.defaultsKey)
                    }
                    print("Updated local bookmarks from iCloud")
                case NSUbiquitousKeyValueStoreQuotaViolationChange:
                    print("iCloud KVS quote exceeded")
                default:
                    print("Unrecognised iCloud KVS change reason \(reason)")
                }
        }
    }
}
