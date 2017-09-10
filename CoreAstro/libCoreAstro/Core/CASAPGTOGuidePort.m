//
//  CASAPGTOGuidePort.m
//  guide-socket-test
//
//  Created by Simon Taylor on 27/05/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import "CASAPGTOGuidePort.h"
#import "CASAPGTOMount.h"
#import "CASNova.h"

#import <AppKit/AppKit.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <sys/un.h>

// From CFLocalServer sample code
//
static int MoreUNIXErrno(int result)
// See comment in header.
{
    int err;
    
    err = 0;
    if (result < 0) {
        err = errno;
        assert(err != 0);
    }
    return err;
}

static int SafeBindUnixDomainSocket(int sockFD, const char *socketPath)
// This routine is called to safely bind the UNIX domain socket
// specified by sockFD to the path specificed by socketPath.  To avoid
// security problems, socketPath must point it to a sticky directory
// (such as "/var/tmp").  This allows us to create the socket with
// very specific permissions, without us having to worry about a malicious
// process switching stuff out from underneath us.
//
// For this test program, socketpath is "/var/tmp/com.apple.dts.CFLocalServer/Socket".
// The code calculates parentPath as ""/var/tmp/com.apple.dts.CFLocalServer"
// and grandParentPath as "/var/tmp".  Each ancestor has certain key attributes.
//
// o grandParentPath must a sticky directory.  Because it's sticky, we
//   can create a directory within it and know that either a) we created
//   the directory, and no one else can mess with it because it's sticky,
//   or b) the directory exists, in which case we can check it's owner
//   and permissions and, if they are set correctly, know that no one else
//   can mess with it.
//
// o When we create the parentPath directory within grandParentPath, we set its
//   permissions to make it readable by everyone (so everyone can connect to our
//   server) but writeable only by us (so that only we can create the listening
//   socket).  Because parentPath is set this way, we know that no one else
//   can modify it to produce a security problem.
//
// IMPORTANT:
// This routine is designed to protect against external attack, not against
// being called incorrectly.  It only does minimal checking of socketPath.
// For example, if one of the components of socketPath was "..", the security
// checking done by this routine might be invalid.  Do not pass an untrusted
// socketPath to this routine.
{
    int                 err;
    char *              parentPath;
    char *              grandParentPath;
    char *              lastSlash;
    struct stat         sb;
    struct sockaddr_un  bindReq;
    static const mode_t kRequiredParentMode = S_IRWXU | (S_IRGRP | S_IXGRP) | (S_IROTH | S_IXOTH); // rwxr-xr-x
    
    parentPath      = NULL;
    grandParentPath = NULL;
    
    // sockaddr_un can only hold a very short path (it's 104 bytes long),
    // so we check that limit right up front.  Note the use of >= in the
    // check below: we fail if socketPath is exactly 104 chars long because
    // that would leave no space for the trailing null character.  Looking at
    // the kernel code, I don't think this is strictly necessary (in fact,
    // it seems that the kernel code will handle much longer paths than sun_path,
    // up to an overall sockaddr size ofSOCK_MAXADDRLEN), but I'm being
    // paranoid.
    
    err = 0;
    if (strlen(socketPath) >= sizeof(bindReq.sun_path)) {
        err = EINVAL;
    }
    
    // Construct parentPath and grandParent path by knocking path components
    // off the end.
    
    if (err == 0) {
        parentPath = strdup(socketPath);
        if (parentPath == NULL) {
            err = ENOMEM;
        }
    }
    if (err == 0) {
        lastSlash = strrchr(parentPath, '/');
        if (lastSlash == NULL) {
            fprintf(stderr, "SafeBindUnixDomainSocket: Can't get parent for path (%s).\n", socketPath);
            err = EINVAL;
        } else {
            *lastSlash = 0;
        }
    }
    if (err == 0) {
        grandParentPath = strdup(parentPath);
        if (grandParentPath == NULL) {
            err = ENOMEM;
        }
    }
    if (err == 0) {
        lastSlash = strrchr(grandParentPath, '/');
        if (lastSlash == NULL) {
            fprintf(stderr, "SafeBindUnixDomainSocket: Can't get grandparent for path (%s).\n", socketPath);
            err = EINVAL;
        } else {
            *lastSlash = 0;
        }
    }
    
    // Check that the parent directory is a sticky root-owned directory.  If the
    // grandparent directory is sticky, we know that any items in that directory
    // that are owned by us can't be substituted by anyone else (that is: deleted,
    // moved or renamed, and then replaced by an attacker's item).
    
    if (err == 0) {
        err = stat(grandParentPath, &sb);
        err = MoreUNIXErrno(err);
    }
    if ( (err == 0) && ( ! (sb.st_mode & S_ISTXT) || (sb.st_uid != 0) ) ) {
        fprintf(stderr, "SafeBindUnixDomainSocket: Grandparent directory (%s) is not a sticky root-owned directory.\n", grandParentPath);
        err = EINVAL;
    }
    
    // Create the parent directory.  Ignore an EEXIST error because of the
    // next check.
    
    if (err == 0) {
        err = mkdir(parentPath, kRequiredParentMode);
        err = MoreUNIXErrno(err);
        
        if (err == EEXIST) {
            err = 0;
        }
    }
    
    // Check that the parent directory is a directory, is owned by us, and
    // has the right mode.  This ensures that no one except us can be monkeying
    // with its contents.  And we know that no one can substitute a /different/
    // directory underneath us because its parent (grandParentPath) is sticky.
    
    if (err == 0) {
        err = stat(parentPath, &sb);
        err = MoreUNIXErrno(err);
    }
    if ( (err == 0) && (sb.st_uid != geteuid()) ) {
        fprintf(stderr, "SafeBindUnixDomainSocket: Parent (%s) is not owned by us.\n", parentPath);
        err = EINVAL;
    }
    if ( (err == 0) && ! S_ISDIR(sb.st_mode) ) {
        fprintf(stderr, "SafeBindUnixDomainSocket: Parent (%s) is not a directory.\n", parentPath);
        err = EINVAL;
    }
    if ( (err == 0) && ( (sb.st_mode & ACCESSPERMS) != kRequiredParentMode ) ) {
        fprintf(stderr, "SafeBindUnixDomainSocket: Parent (%s) has wrong permissions.\n", parentPath);
        err = EINVAL;
    }
    
    // If all is well, let's bind our socket.  This involves deleting any existing
    // socket and recreating our own.  We know we can do this without worrying
    // about substitution because only we have write access to the parent directory.
    
    if (err == 0) {
        mode_t              oldUmask;
        
        // Temporarily set the umask to 0 (the default is 0022) so that the
        // socket is created rwxrwxrwx.  This allows any user to connect to
        // our socket.
        
        oldUmask = umask(0);
        
        // Delete any existing socket.  We delete the socket when we shut down,
        // but, if we quit unexpectedly, it could've been left lying around.
        
        (void) unlink(socketPath);
        
        // Bind the socket, allowing other clients to connect.
        
        bindReq.sun_len    = sizeof(bindReq);
        bindReq.sun_family = AF_UNIX;
        strcpy(bindReq.sun_path, socketPath);
        
        err = bind(sockFD, (struct sockaddr *) &bindReq, (socklen_t)SUN_LEN(&bindReq));
        err = MoreUNIXErrno(err);
        
        (void) umask(oldUmask);
    }
    
    free(parentPath);
    free(grandParentPath);
    
    return err;
}

// todo; pipe timestamp,ra,dec,alt,az,pier back to caller which can then use that info to implement dec-compensated guiding and automatically flip calibration after a flip

@interface CASAPGTOGuidePort ()
@property (strong) NSFileHandle* listenHandle;
@property (strong) NSFileHandle* readHandle;
@property (strong) NSArray* observers;
@property (strong) NSRegularExpression* regex;
@property (weak) CASAPGTOMount* mount;
@property (weak) id<CASAPGTOGuidePortDelegate> delegate;
@end

@implementation CASAPGTOGuidePort {
    int _socket;
    NSInteger _guide_sequence;
}

static const char* path = "/var/tmp/org.coreastro.sxio/apgto-guider.socket";

- (instancetype)initWithMount:(CASAPGTOMount*)mount delegate:(id<CASAPGTOGuidePortDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        self.mount = mount;
        self.delegate = delegate;
        
        self.regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d+) ([A-Z]) ([0-9]+)\\#" options:NSRegularExpressionCaseInsensitive error:nil];
        if (!self.regex){
            return nil;
        }
        
        if (![self createSocket]){
            return nil;
        }
        
        if (![self listen]){
            return nil;
        }
        
        [self accept];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"[CASAPGTOGuidePort dealloc]");
    
    [self disconnect];
}

- (void)disconnect
{
    if (_socket > 0) {
        close(_socket);
        _socket = 0;
    }
    
    [self.listenHandle closeFile];
    self.listenHandle = nil;
    
    [self.readHandle closeFile];
    self.readHandle = nil;
    
    [self.observers enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [[NSNotificationCenter defaultCenter] removeObserver:obj];
    }];
    self.observers = nil;
}

- (void)writeMessage:(NSString*)message
{
    [self.readHandle writeData:[message dataUsingEncoding:NSUTF8StringEncoding]];
}

- (BOOL)createSocket
{
    if (_socket > 0){
        return YES;
    }
    
    _socket = socket(AF_UNIX, SOCK_STREAM, 0);
    if (_socket == -1){
        _socket = 0;
        perror("[CASAPGTOGuidePort createSocket]");
        return NO;
    }
    
    const int result = SafeBindUnixDomainSocket(_socket,path);
    if (result != 0){ // or EEXIST ?
        _socket = 0;
        perror("[CASAPGTOGuidePort createSocket]");
        return NO;
    }
    
    return YES;
}

- (BOOL)listen
{
    NSMutableArray* mobs = [NSMutableArray arrayWithCapacity:2];
    
    id obs = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleConnectionAcceptedNotification
                                                               object:nil
                                                                queue:[NSOperationQueue mainQueue]
                                                           usingBlock:^(NSNotification * _Nonnull note) {
                                                               
                                                               if (self.readHandle != nil) {
                                                                   NSLog(@"CASAPGTOGuidePort: Closed existing read socket");
                                                                   [self.readHandle closeFile];
                                                                   self.readHandle = nil;
                                                               }
                                                               
                                                               _guide_sequence = 0;
                                                               self.readHandle = note.userInfo[NSFileHandleNotificationFileHandleItem];
                                                               [self.readHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode]];
                                                               
                                                               // todo; send hello message
                                                               
                                                               [self accept];
                                                           }];
    [mobs addObject:obs];
    
    obs = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadCompletionNotification
                                                            object:nil
                                                             queue:[NSOperationQueue mainQueue]
                                                        usingBlock:^(NSNotification * _Nonnull note) {
                                                            
                                                            NSData* payload = [note userInfo][NSFileHandleNotificationDataItem];
                                                            if (payload.length > 0) {
                                                                [self handleMessage:[[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding]];
                                                                [self.readHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode]];
                                                            }
                                                        }];
    [mobs addObject:obs];
    
    self.observers = [mobs copy];
    
    const int result = listen(_socket, 0);
    if (result == -1){
        perror("[CASAPGTOGuidePort listen]");
        return NO;
    }
    
    self.listenHandle = [[NSFileHandle alloc] initWithFileDescriptor:_socket closeOnDealloc:YES];
    
    NSLog(@"CASAPGTOGuidePort: listening on %d",_socket);
    
    return YES;
}

- (void)accept
{
    [self.listenHandle acceptConnectionInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode]];
    
    NSLog(@"CASAPGTOGuidePort: accepting");
}

- (void)handleMessage:(NSString*)message
{
    // report current site location
    if ([message isEqualToString:@"get-location"]){
        NSNumber* latitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"];
        NSNumber* longitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
        if (latitude && longitude){
            [self writeMessage:[NSString stringWithFormat:@"%@ %@",latitude,longitude]];
        }
        else {
            [self writeMessage:@""];
        }
        return;
    }

    // report current position
    if ([message isEqualToString:@"get-coordinates"]){
        const double lst = [CASNova siderealTimeForLongitude:self.mount.longitude.doubleValue];
        [self writeMessage:[NSString stringWithFormat:@"%f %f %f",self.mount.ra.doubleValue/15.0,self.mount.dec.doubleValue,lst]];
        return;
    }
    
    // report current side of pier
    if ([message isEqualToString:@"get-pierside"]){
        
        enum PierSide
        {
            PIER_SIDE_UNKNOWN = -1,
            PIER_SIDE_EAST = 0,
            PIER_SIDE_WEST = 1,
        };

        switch (self.mount.pierSide) {
            case CASMountPierSideEast:
                [self writeMessage:[NSString stringWithFormat:@"%d",PIER_SIDE_EAST]];
                break;
            case CASMountPierSideWest:
                [self writeMessage:[NSString stringWithFormat:@"%d",PIER_SIDE_WEST]];
                break;
            default:
                [self writeMessage:[NSString stringWithFormat:@"%d",PIER_SIDE_UNKNOWN]];
                break;
        }

        return;
    }

    // stop any current slew
    if ([message isEqualToString:@"stop-slew"]){
        return;
    }

    // start a slew to the given co-ordinates
    if ([message hasPrefix:@"start-slew"]){
        // read ra, dec
        return;
    }

    // pulse guide command
    NSArray<NSTextCheckingResult *> *matches = [self.regex matchesInString:message options:0 range:NSMakeRange(0, message.length)];
    if (matches.count == 0){
        NSLog(@"CASAPGTOGuidePort: Unrecognised message '%@'",message);
    }
    else {
        
        [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if (obj.numberOfRanges != 4) {
                NSLog(@"CASAPGTOGuidePort: Badly formatted message '%@'",message);
            }
            else{
                
                NSLog(@"CASAPGTOGuidePort: Pulse command '%@'",message);

                BOOL success = false;
                NSString* index = [message substringWithRange:[obj rangeAtIndex:1]];
                if (index.integerValue < _guide_sequence){
                    
                    NSLog(@"CASAPGTOGuidePort: Out of sequence guide command %@, expecting %ld",index,(long)_guide_sequence);
                    [self writeMessage:@"error: out of sequence"];
                }
                else {
                    
                    _guide_sequence = index.integerValue;
                    
                    NSString* direction = [message substringWithRange:[obj rangeAtIndex:2]];
                    const NSInteger milliseconds = [[message substringWithRange:[obj rangeAtIndex:3]] integerValue];
                    if ([direction caseInsensitiveCompare:@"N"] == NSOrderedSame) {
                        success = [self.delegate pulseInDirection:CASMountDirectionNorth ms:milliseconds];
                    }
                    else if ([direction caseInsensitiveCompare:@"S"] == NSOrderedSame) {
                        success = [self.delegate pulseInDirection:CASMountDirectionSouth ms:milliseconds];
                    }
                    else if ([direction caseInsensitiveCompare:@"E"] == NSOrderedSame) {
                        success = [self.delegate pulseInDirection:CASMountDirectionEast ms:milliseconds];
                    }
                    else if ([direction caseInsensitiveCompare:@"W"] == NSOrderedSame) {
                        success = [self.delegate pulseInDirection:CASMountDirectionWest ms:milliseconds];
                    }
                    else {
                        NSLog(@"CASAPGTOGuidePort: Unrecognised guide direction: %@",direction);
                    }
                    if (success){
                        [self writeMessage:[NSString stringWithFormat:@"ok: %@",index]];
                    }
                    else {
                        [self writeMessage:@"error: pulse failed"];
                    }
                }
            }
        }];
    }
}

@end
