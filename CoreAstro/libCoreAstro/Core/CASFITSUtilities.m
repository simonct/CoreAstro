//
//  CASFITSUtilities.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/19/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASFITSUtilities.h"

#if CAS_ENABLE_FITS

int cas_fits_open_image(fitsfile **fptr,const char* path,int mode,int* status)
{
    *status = fits_open_diskfile(fptr,path,mode,status);
    if (!*status){
        
        // from fits_open_image
        int hdutype;
        if (ffghdt(*fptr, &hdutype, status) <= 0) {
            if (hdutype != IMAGE_HDU)
                *status = NOT_IMAGE;
        }
    }
    return *status;
}

#endif