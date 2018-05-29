//
//  CASAlertFactory.h
//  CoreAstro
//
//  Created by Simon Taylor on 27/05/2018.
//  Copyright © 2018 Mako Technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CASAlertFactory : NSObject

+ (NSAlert *_Nullable)alertWithMessageText:(nullable NSString *)message defaultButton:(nullable NSString *)defaultButton alternateButton:(nullable NSString *)alternateButton otherButton:(nullable NSString *)otherButton informativeTextWithFormat:(NSString *_Nullable)format, ... NS_FORMAT_FUNCTION(5,6);

+ (NSInteger)runModalAlertTitle:(NSString*_Nullable)title message:(NSString*_Nullable)message;

@end
