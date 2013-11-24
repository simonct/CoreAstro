//
//  CASFITSUtilities.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/19/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "fitsio.h"

// version of fits_open_image which allows bypassing of filename template processing
extern int cas_fits_open_image(fitsfile **fptr,const char* path,int mode,int* status);
