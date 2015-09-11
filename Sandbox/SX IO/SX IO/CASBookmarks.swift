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
    static let solutionDataKey = "solutionData"
    
    static var sharedInstance = CASBookmarks()

    var bookmarks: [NSDictionary] {
        get {
            return NSUserDefaults.standardUserDefaults().arrayForKey(CASBookmarks.defaultsKey) as? [NSDictionary] ?? []
        }
        set {
            NSUserDefaults.standardUserDefaults().setObject(bookmarks, forKey: CASBookmarks.defaultsKey)
        }
    }
    
    func addBookmark(name: String, solution: CASPlateSolveSolution) {
        if (!name.isEmpty){
            if let solutionData = solution.solutionData() {
                bookmarks.append(NSDictionary(objects:[name,solutionData],forKeys:[CASBookmarks.nameKey,CASBookmarks.solutionDataKey]))
            }
        }
    }

    func addBookmark(name: String, ra: Double, dec: Double) {
        if (!name.isEmpty){
            bookmarks.append(NSDictionary(objects:[name,ra,dec],forKeys:[CASBookmarks.nameKey,CASBookmarks.centreRaKey,CASBookmarks.centreDecKey]))
        }
    }
}