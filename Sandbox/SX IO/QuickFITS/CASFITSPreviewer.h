//
//  CASFITSPreviewer.h
//  QuickFITS
//
//  Created by Simon Taylor on 8/24/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASFITSPreviewer : NSObject

- (CGImageRef)newImageFromURL:(NSURL*)url error:(NSError**)error;

@end
