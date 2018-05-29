//
//  CASAlertFactory.m
//  CoreAstro
//
//  Created by Simon Taylor on 27/05/2018.
//  Copyright © 2018 Mako Technology Ltd. All rights reserved.
//

#import "CASAlertFactory.h"

@implementation CASAlertFactory

+ (NSAlert *_Nullable)alertWithMessageText:(nullable NSString *)message defaultButton:(nullable NSString *)defaultButton alternateButton:(nullable NSString *)alternateButton otherButton:(nullable NSString *)otherButton informativeTextWithFormat:(NSString *_Nullable)format, ...
{
    NSAlert* alert = [[NSAlert alloc] init];
    
    alert.messageText = message;
    alert.informativeText = format;
    
    if (defaultButton){
        [alert addButtonWithTitle:defaultButton];
    }
    if (alternateButton){
        [alert addButtonWithTitle:alternateButton];
    }
    if (otherButton){
        [alert addButtonWithTitle:otherButton];
    }
    
    return alert;
}

+ (NSInteger)runModalAlertTitle:(NSString*_Nullable)title message:(NSString*_Nullable)message
{
    return [[CASAlertFactory alertWithMessageText:title
                                    defaultButton:@"OK"
                                  alternateButton:nil
                                      otherButton:nil
                        informativeTextWithFormat:@"%@", message] runModal];
}

@end
