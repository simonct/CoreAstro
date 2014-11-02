//
//  SXCCDDeviceUtilities.h
//  SX IO
//
//  Created by Simon Taylor on 10/24/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#ifndef __SX_IO__SXCCDDeviceUtilities__
#define __SX_IO__SXCCDDeviceUtilities__

#include <stdio.h>
#include <stdlib.h>

extern uint8_t* sxReconstructM26CFields1x1(const uint8_t* field2Pixels,const uint8_t* field1Pixels,const long lineLength,const long lineCount);
extern uint8_t* sxReconstructM26CFields2x2(const uint8_t* field1Pixels,const uint8_t* field2Pixels,const long lineLength,const long lineCount);
extern uint8_t* sxReconstructM26CFields4x4(const uint8_t* field1Pixels,const uint8_t* field2Pixels,const long lineLength,const long lineCount);

#endif /* defined(__SX_IO__SXCCDDeviceUtilities__) */
