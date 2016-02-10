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


public class CASBookmarks: NSObject {
    
    static private let defaultsKey = "CASBookmarks"
    
    public static let nameKey = "name"
    public static let centreRaKey = "centreRa"
    public static let centreDecKey = "centreDec"
    public static let solutionDictionaryKey = "solutionDictionary"
    
    public static let sharedInstance = CASBookmarks()
    
    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("storeDidChange:"), name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification, object: NSUbiquitousKeyValueStore.defaultStore())
        NSUbiquitousKeyValueStore.defaultStore().synchronize()
        if let bookmarks = NSUbiquitousKeyValueStore.defaultStore().dictionaryRepresentation[CASBookmarks.defaultsKey] as? Array<NSDictionary> {
            print("CASBookmarks.init, \(bookmarks.count) bookmark(s) in iCloud")
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    public var bookmarks: [NSDictionary] {
        get {
            return NSUserDefaults.standardUserDefaults().objectForKey(CASBookmarks.defaultsKey) as? [NSDictionary] ?? []
        }
        set {
            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: CASBookmarks.defaultsKey)
            NSUbiquitousKeyValueStore.defaultStore().setArray(newValue, forKey: CASBookmarks.defaultsKey)
        }
    }
    
    private func appendBookmark(bookmark: NSDictionary) {
        var bookmarks = self.bookmarks;
        bookmarks.append(bookmark)
        self.bookmarks = bookmarks
    }
    
    public func addBookmark(name: String, solution: CASPlateSolveSolution) {
        if (!name.isEmpty){
            if let solutionDictionary = solution.solutionDictionary() {
                appendBookmark(NSDictionary(objects:[name,solutionDictionary],forKeys:[CASBookmarks.nameKey,CASBookmarks.solutionDictionaryKey]));
            }
        }
    }
    
    public func addBookmark(name: String, ra: Double, dec: Double) {
        if (!name.isEmpty){
            appendBookmark(NSDictionary(objects:[name,ra,dec],forKeys:[CASBookmarks.nameKey,CASBookmarks.centreRaKey,CASBookmarks.centreDecKey]));
        }
    }
    
    private func storeDidChange(note: NSNotification) { // interestingly, can't be private otherwise the notification fails with selector not found
        print("storeDidChange \(note.userInfo)")
        if let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? Array<String>,
            reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
            _ = changedKeys.indexOf(CASBookmarks.defaultsKey){
                switch(reason){
                case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange, NSUbiquitousKeyValueStoreAccountChange:
                    if let bookmarks = NSUbiquitousKeyValueStore.defaultStore().arrayForKey(CASBookmarks.defaultsKey) {
                        NSUserDefaults.standardUserDefaults().setObject(bookmarks, forKey: CASBookmarks.defaultsKey)
                    }
                    else {
                        NSUserDefaults.standardUserDefaults().removeObjectForKey(CASBookmarks.defaultsKey)
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