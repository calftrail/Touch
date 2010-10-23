//
//  AppDelegate.h
//  TouchRecorder
//
//  Created by Nathan Vander Wilt on 11/24/09.
//  Copyright 2009 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TouchView;

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    TouchView* touchView;
	NSMutableArray* eventLog;
	BOOL detectedClick;
	BOOL detectedMagnify;
	BOOL detectedRotate;
	BOOL detectedSwipe;
	BOOL detectedGesture;
	BOOL detectedFingers;
	CFMachPortRef hidTap;
	CFMachPortRef sessionTap;
	CFMachPortRef annotatedTap;
}

@property (assign) IBOutlet TouchView* touchView;

@property (assign) BOOL detectedClick;
@property (assign) BOOL detectedMagnify;
@property (assign) BOOL detectedRotate;
@property (assign) BOOL detectedSwipe;
@property (assign) BOOL detectedGesture;
@property (assign) BOOL detectedFingers;

@end
