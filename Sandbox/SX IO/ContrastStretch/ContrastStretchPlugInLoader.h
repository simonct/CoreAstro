//
//  ContrastStretchPlugInLoader.h
//  ContrastStretch
//
//  Created by Simon Taylor on 8/6/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <QuartzCore/CoreImage.h>

@interface ContrastStretchPlugInLoader : NSObject <CIPlugInRegistration>

- (BOOL)load:(void *)host;

@end
