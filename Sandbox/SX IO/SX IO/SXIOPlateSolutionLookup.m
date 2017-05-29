//
//  SXIOPlateSolutionLookup.m
//  SX IO
//
//  Created by Simon Taylor on 29/05/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import "SXIOPlateSolutionLookup.h"
#import <CloudKit/CloudKit.h>

@implementation SXIOPlateSolutionLookup

+ (instancetype)sharedLookup
{
    static SXIOPlateSolutionLookup* _sharedLookup;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedLookup = [[SXIOPlateSolutionLookup alloc] init];
    });
    return _sharedLookup;
}

- (void)lookupSolutionCloudRecordsWithUUID:(NSString*)uuid completion:(void(^)(NSError* error,NSArray<CKRecord *> *))completion
{
    CKQuery* query = [[CKQuery alloc] initWithRecordType:@"PlateSolution" predicate:[NSPredicate predicateWithFormat:@"UUID == %@",uuid]];
    [[CKContainer defaultContainer].publicCloudDatabase performQuery:query inZoneWithID:nil completionHandler:^(NSArray<CKRecord *> * _Nullable results, NSError * _Nullable error) {
        completion(error,results);
    }];
}

- (void)lookupSolutionForExposure:(CASCCDExposure*)exposure completion:(void(^)(CASCCDExposure*,CASPlateSolveSolution*))completion
{
    NSData* solutionData;
    
    // look for a solution file alongside the exposure
    NSURL* exposureUrl = exposure.io.url;
    if (exposureUrl){
        NSURL* solutionUrl = [[exposureUrl URLByDeletingPathExtension] URLByAppendingPathExtension:@"caPlateSolution"];
        solutionData = [NSData dataWithContentsOfURL:solutionUrl];
    }
    
    if (solutionData){
        CASPlateSolveSolution* solution = [NSKeyedUnarchiver unarchiveObjectWithData:solutionData];
        if (solution){
            completion(exposure,solution);
            return;
        }
    }
    
    // then, try CloudKit
    if (!solutionData){
        
        [self lookupSolutionCloudRecordsWithUUID:exposure.uuid completion:^(NSError *error, NSArray<CKRecord *> *results) {
            
            if (!error && results.count > 0){
                
                NSData* solutionData = [results.firstObject objectForKey:@"Solution"];
                if ([solutionData length]){
                    
                    @try {
                        CASPlateSolveSolution* solution = [NSKeyedUnarchiver unarchiveObjectWithData:solutionData];
                        if (![solution isKindOfClass:[CASPlateSolveSolution class]]){
                            NSLog(@"Root object in solution archive is a %@ and not a CASPlateSolveSolution",NSStringFromClass([solution class]));
                            solution = nil;
                        }
                        if (!solution){
                            // todo; start plate solve for this exposure, show solution hud but with a spinner
                        }
                        else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(exposure,solution);
                            });
                        }
                    }
                    @catch (NSException *exception) {
                        NSLog(@"Exception opening solution data: %@",exception);
                    }
                }
            }
        }];
    }
}

- (void)storeSolutionData:(NSData*)solutionData forUUID:(NSString*)uuid
{
    CKRecord* record = [[CKRecord alloc] initWithRecordType:@"PlateSolution"];
    [record setObject:uuid forKey:@"UUID"];
    [record setObject:solutionData forKey:@"Solution"];
    
    // we need to remove any existing solutions first
    [self lookupSolutionCloudRecordsWithUUID:uuid completion:^(NSError *error, NSArray<CKRecord *> *results) {
        
        void (^addRecord)(CKRecord*) = ^(CKRecord* record){
            [[CKContainer defaultContainer].publicCloudDatabase saveRecord:record completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
                if (error){
                    NSLog(@"Failed to save plate solution to CloudKit: %@",error);
                }
            }];
        };
        
        if (results.count == 0) {
            addRecord(record);
        }
        else {
            
            CKModifyRecordsOperation* op = [[CKModifyRecordsOperation alloc] init];
            op.container = [CKContainer defaultContainer];
            op.database = [CKContainer defaultContainer].publicCloudDatabase;
            
            NSMutableArray* recordIds = [NSMutableArray arrayWithCapacity:results.count];
            [results enumerateObjectsUsingBlock:^(CKRecord * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [recordIds addObject:obj.recordID];
            }];
            op.recordIDsToDelete = recordIds;
            op.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError){
                addRecord(record); // called on bg thread
            };
            [op.database addOperation:op];
        }
    }];
}

@end
