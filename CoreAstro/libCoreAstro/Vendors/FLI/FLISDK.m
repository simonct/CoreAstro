//
//  FLISDK.m
//  CoreAstro
//
//  Copyright (c) 2016, Simon Taylor
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
#import "FLIFWDevice.h"
#import "libfli.h"

@implementation FLISDK

@synthesize deviceAdded, deviceRemoved;

+ (void)load
{
    #define LIBVERSIZE 64
    char libver[LIBVERSIZE];
    if(FLIGetLibVersion(libver, LIBVERSIZE) != 0) {
		NSLog(@"Unable to retrieve library version!\n");
	}
    else {
        NSLog(@"Library version is %s\n",libver);
    }
}

+ (dispatch_queue_t)q
{
    static dispatch_queue_t _q;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _q = dispatch_queue_create("fli-queue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_DEFAULT,0));
    });
    return _q;
}

- (void)scanDomain:(long)searchDomain
{
    dispatch_sync([FLISDK q], ^{

        #define MAX_PATH 64
        char file[MAX_PATH], name[MAX_PATH];

        FLICreateList(searchDomain); // can only scan for one domain at a time
        
        flidomain_t domain = 0;
        if(FLIListFirst(&domain, file, MAX_PATH, name, MAX_PATH) == 0) {
            
            do {
                
                NSString* ident = [NSString stringWithUTF8String:name];
                NSString* path = [NSString stringWithUTF8String:file];
                if (domain & FLIDEVICE_CAMERA){
                    FLICCDDevice* camera = [[FLICCDDevice alloc] initWithId:ident path:path domain:domain];
                    self.deviceAdded(path,camera);
                    NSLog(@"Added FLI camera: %@",ident);
                }
                else if (domain & FLIDEVICE_FILTERWHEEL){
                    FLIFWDevice* fw = [[FLIFWDevice alloc] initWithId:ident path:path];
                    self.deviceAdded(path,fw);
                    NSLog(@"Added FLI filter wheel: %@",ident);
                }
                else if (domain & FLIDEVICE_FOCUSER){
                    NSLog(@"Found FLI focuser: %@",ident);
                }
            } while((FLIListNext(&domain, file, MAX_PATH, name, MAX_PATH) == 0));
        }
        
        FLIDeleteList();
    });
}

- (void)scan
{
    if (!self.deviceAdded){
        return;
    }
    
    [self scanDomain:FLIDOMAIN_USB|FLIDEVICE_CAMERA];
    [self scanDomain:FLIDOMAIN_USB|FLIDEVICE_FILTERWHEEL];
    [self scanDomain:FLIDOMAIN_USB|FLIDEVICE_FOCUSER];
}

@end
