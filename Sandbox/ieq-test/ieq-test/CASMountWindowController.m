//
//  iEQWindowController.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMountWindowController.h"
#import "CASMount.h"
#import "CASLX200Commands.h"

@interface CASMountWindowController ()
@property (nonatomic,strong) CASMount* mount;
@property (nonatomic,copy) NSString* searchString;
@property (nonatomic,assign) NSInteger guideDurationInMS;
@end

@implementation CASMountWindowController {
    double _ra, _dec;
}

+ (void)initialize
{
    [NSValueTransformer setValueTransformer:[CASLX200RATransformer new] forName:@"CASLX200RATransformer"];
    [NSValueTransformer setValueTransformer:[CASLX200DecTransformer new] forName:@"CASLX200DecTransformer"];
}

- (void)connectToMount:(CASMount*)mount
{
    self.mount = mount;
    
    [self.mount connectWithCompletion:^(NSError* _){
        if (self.mount.connected){
            [self.window makeKeyAndOrderFront:nil];
            self.guideDurationInMS = 1000;
        }
        else {
            NSLog(@"Failed to connect");
        }
    }];
}

// todo; put into its own class and cache results
- (void)lookupObject:(NSString*)name withCompletion:(void(^)(BOOL success,double ra,double dec))completion
{
    NSParameterAssert(name);
    NSParameterAssert(completion);
    
    NSString* script = [NSString stringWithFormat:@"format object \"%%IDLIST(1) : %%COO(d;A D)\"\nset epoch JNOW\nset limit 1\nquery id %@\nformat display\n",name];
    script = [script stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://simbad.u-strasbg.fr/simbad/sim-script?submit=submit+script&script=%@",script]];
    
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        
        if (connectionError){
            NSLog(@"%@",connectionError);
            completion(NO,0,0);
        }
        else {
            
            BOOL foundIt = NO;
            double ra, dec;
            
            NSString* responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSArray* responseLines = [responseString componentsSeparatedByString:@"\n"];
            
            for (NSString* line in [responseLines reverseObjectEnumerator]){
                
                NSScanner* scanner = [NSScanner scannerWithString:line];
                
                NSString* object;
                if ([scanner scanUpToString:@":" intoString:&object]){
                    
                    NSMutableCharacterSet* cs = [NSMutableCharacterSet decimalDigitCharacterSet];
                    [cs addCharactersInString:@"+-"];
                    
                    [scanner scanUpToCharactersFromSet:cs intoString:nil];
                    [scanner scanDouble:&ra];
                    
                    [scanner scanUpToCharactersFromSet:cs intoString:nil];
                    [scanner scanDouble:&dec];
                    
                    NSLog(@"object: %@, ra: %f, dec: %f",object,ra,dec);
                    
                    foundIt = YES;
                    
                    break;
                }
            };
            
            completion(foundIt,ra,dec);
        }
    }];
}

- (void)startMoving:(CASMountDirection)direction
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopMoving:) object:nil];
    [self performSelector:@selector(stopMoving:) withObject:nil afterDelay:0.25];
    [self.mount startMoving:direction];
}

- (IBAction)north:(id)sender
{
    [self startMoving:CASMountDirectionNorth];
}

- (IBAction)soutgh:(id)sender
{
    [self startMoving:CASMountDirectionSouth];
}

- (IBAction)west:(id)sender
{
    [self startMoving:CASMountDirectionWest];
}

- (IBAction)east:(id)sender
{
    [self startMoving:CASMountDirectionEast];
}

- (IBAction)guideNorth:(id)sender
{
    [self.mount pulseInDirection:CASMountDirectionNorth ms:self.guideDurationInMS];
}

- (IBAction)guideEast:(id)sender
{
    [self.mount pulseInDirection:CASMountDirectionEast ms:self.guideDurationInMS];
}

- (IBAction)guideSouth:(id)sender
{
    [self.mount pulseInDirection:CASMountDirectionSouth ms:self.guideDurationInMS];
}

- (IBAction)guideWest:(id)sender
{
    [self.mount pulseInDirection:CASMountDirectionWest ms:self.guideDurationInMS];
}

- (void)stopMoving:sender
{
    [self.mount stopMoving];
}

- (IBAction)dump:(id)sender
{
//    [self.mount dumpInfo];
}

- (IBAction)slew:(id)sender
{
    if (![self.searchString length]){
        return;
    }
    
    [self lookupObject:self.searchString withCompletion:^(BOOL success,double ra, double dec) {
        
        NSLog(@"Lookup ra=%f (raDegreesToHMS %@), dec=%f (highPrecisionDec %@)",ra,[CASLX200Commands raDegreesToHMS:ra],dec,[CASLX200Commands highPrecisionDec:dec]);
        
        if (!success){
            [[NSAlert alertWithMessageText:@"Not Found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Target couldn't be found"] runModal];
        }
        else{

            // RA from SIMBAD searches is decimal degrees not HMS so we have to convert
            _dec = dec;
            _ra = [CASLX200Commands fromRAString:[CASLX200Commands raDegreesToHMS:ra] asDegrees:NO];
            
            // confirm slew before starting
            NSAlert* alert = [NSAlert alertWithMessageText:self.searchString defaultButton:@"Slew" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Slew to target ? RA: %@, DEC: %@",[CASLX200Commands raDegreesToHMS:ra],[CASLX200Commands highPrecisionDec:dec]];
            
            [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(slewAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        }
    }];
}

- (void) slewAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton){
        
        [self.mount startSlewToRA:_ra dec:_dec completion:^(CASMountSlewError result) {
            
            if (result == CASMountSlewErrorNone){
                NSLog(@"Starting slew");
            }
            else {
                NSBeep();
                NSLog(@"Start failed: %ld",result);
            }
        }];
    }
}

- (IBAction)stop:(id)sender
{
    [self.mount halt];
}

@end

#if 0

format object "%IDLIST(1) : %COO(d;A D)"
set epoch J2000
set limit 1
query id arcturus
query id ic405
format display

http://simbad.u-strasbg.fr/simbad/sim-script?submit=submit+script&script=format+object+%22%25IDLIST%281%29+%3A+%25COO%28d%3BA+D%29%22%0D%0Aset+epoch+J2000%0D%0Aset+limit+1%0D%0Aquery+id+ic410%0D%0Aquery+id+ic405%0D%0Aformat+display%0D%0A

https://maps.google.co.uk/maps?q=Amersham&hl=en&ll=51.675536,-0.607252&spn=0.057217,0.111408&sll=52.8382,-2.327815&sspn=14.291495,28.520508&oq=amersham&hnear=Amersham,+Buckinghamshire,+United+Kingdom&t=m&z=14

#endif
