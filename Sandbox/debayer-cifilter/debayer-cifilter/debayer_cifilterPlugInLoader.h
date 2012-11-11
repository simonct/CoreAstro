//
//  debayer_cifilterPlugInLoader.h
//  debayer-cifilter
//
//  Created by Simon Taylor on 11/11/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <QuartzCore/CoreImage.h>

@interface debayer_cifilterPlugInLoader : NSObject <CIPlugInRegistration>

- (BOOL)load:(void *)host;

@end
