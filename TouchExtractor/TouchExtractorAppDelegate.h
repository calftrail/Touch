//
//  TouchExtractorAppDelegate.h
//  TouchExtractor
//
//  Created by Nathan Vander Wilt on 11/24/09.
//  Copyright 2009 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TouchExtractorAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
