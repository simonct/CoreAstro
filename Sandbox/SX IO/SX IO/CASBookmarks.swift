//
//  CASBookmarks.swift
//  SX IO
//
//  Created by Simon Taylor on 11/09/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

import Foundation


class CASBookmarks: NSObject {
    
    static private let defaultsKey = "SXIOBookmarks"

    static let nameKey = "name"
    static let centreRaKey = "centreRa"
    static let centreDecKey = "centreDec"
    static let solutionDictionaryKey = "solutionDictionary"
    
    static var sharedInstance = CASBookmarks()

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

    var bookmarks: [NSDictionary] {
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
    
    func addBookmark(name: String, solution: CASPlateSolveSolution) {
        if (!name.isEmpty){
            if let solutionDictionary = solution.solutionDictionary() {
                appendBookmark(NSDictionary(objects:[name,solutionDictionary],forKeys:[CASBookmarks.nameKey,CASBookmarks.solutionDictionaryKey]));
            }
        }
    }

    func addBookmark(name: String, ra: Double, dec: Double) {
        if (!name.isEmpty){
            appendBookmark(NSDictionary(objects:[name,ra,dec],forKeys:[CASBookmarks.nameKey,CASBookmarks.centreRaKey,CASBookmarks.centreDecKey]));
        }
    }
    
    private func storeDidChange(note: NSNotification) {
        print("storeDidChange \(note.userInfo)")
        if let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? Array<String>, _ = changedKeys.indexOf(CASBookmarks.defaultsKey) {
            if let bookmarks = NSUbiquitousKeyValueStore.defaultStore().arrayForKey(CASBookmarks.defaultsKey){
                NSUserDefaults.standardUserDefaults().setObject(bookmarks, forKey: CASBookmarks.defaultsKey)
                print("Updated local bookmarks from iCloud")
            }
        }
    }
}