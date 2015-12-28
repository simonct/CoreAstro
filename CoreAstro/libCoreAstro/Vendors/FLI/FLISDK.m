//
//  FLISDK.m
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "FLISDK.h"
#import "FLICCDDevice.h"
#import "libfli.h"

@implementation FLISDK

@synthesize deviceAdded, deviceRemoved;

+ (void)load
{
    #define LIBVERSIZE 1024
    char libver[LIBVERSIZE];
    if(FLIGetLibVersion(libver, LIBVERSIZE) != 0) {
		NSLog(@"Unable to retrieve library version!\n");
	}
    else {
        NSLog(@"Library version is %s\n",libver);
    }
}

- (void)scan
{
    if (!self.deviceAdded){
        return;
    }
    
    #define MAX_PATH 1024
	char file[MAX_PATH], name[MAX_PATH];
	long domain;
    
	FLICreateList(FLIDOMAIN_USB | FLIDEVICE_CAMERA);
    
	if(FLIListFirst(&domain, file, MAX_PATH, name, MAX_PATH) == 0)
	{
		do
		{
            NSString* ident = [NSString stringWithUTF8String:name];
            NSString* path = [NSString stringWithUTF8String:file];
            FLICCDDevice* camera = [[FLICCDDevice alloc] initWithId:ident path:path domain:domain];
            self.deviceAdded(path,camera);
            NSLog(@"Added FLI camera: %@",camera.fli_model);
		}
		while((FLIListNext(&domain, file, MAX_PATH, name, MAX_PATH) == 0));
	}
    
	FLIDeleteList();
}

@end
