//
//  AppDelegate.m
//  TouchRecorder
//
//  Created by Nathan Vander Wilt on 11/24/09.
//  Copyright 2009 Calf Trail Software, LLC. All rights reserved.
//

#import "AppDelegate.h"

#import "TouchView.h"
#import "NSFileManager+TLExtensions2.h"

#include <objc/runtime.h>

static CGEventRef TapCB(CGEventRef event, CFStringRef tapName);
static CGEventRef HidCB(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon);
static CGEventRef SessionCB(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon);
static CGEventRef AnnotatedCB(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon);


@implementation AppDelegate

@synthesize touchView;
@synthesize detectedClick;
@synthesize detectedMagnify;
@synthesize detectedRotate;
@synthesize detectedSwipe;
@synthesize detectedGesture;
@synthesize detectedFingers;

- (void)awakeFromNib {
	eventLog = [NSMutableArray new];
	
	CGEventMask events = (NSEventMaskMagnify | NSEventMaskSwipe | NSEventMaskRotate |
						  NSEventMaskGesture | NSEventMaskBeginGesture | NSEventMaskEndGesture);
	//events |= CGEventMaskBit(kCGEventLeftMouseUp);
	
	hidTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap,
							  kCGEventTapOptionListenOnly, events, HidCB, self);
	(void)SessionCB;
	(void)AnnotatedCB;
	/*
	sessionTap = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap,
								  kCGEventTapOptionListenOnly, events, SessionCB, self);
	annotatedTap = CGEventTapCreate(kCGAnnotatedSessionEventTap, kCGTailAppendEventTap,
									kCGEventTapOptionListenOnly, events, AnnotatedCB, self);
	 */
	
	CFRunLoopRef rl = CFRunLoopGetCurrent();
	if (hidTap) {
		CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, hidTap, 0);
		CFRunLoopAddSource(rl, src, kCFRunLoopCommonModes);
		CFRelease(src);
	}	
	if (sessionTap) {
		CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, sessionTap, 0);
		CFRunLoopAddSource(rl, src, kCFRunLoopCommonModes);
		CFRelease(src);
	}
	if (annotatedTap) {
		CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, annotatedTap, 0);
		CFRunLoopAddSource(rl, src, kCFRunLoopCommonModes);
		CFRelease(src);
	}
}

- (void)dealloc {
	[eventLog release];
	[super dealloc];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
	(void)sender;
	return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
	(void)sender;
	
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, NO);
	NSString* desktopPath = [[paths objectAtIndex:0] stringByExpandingTildeInPath];
	NSURL* targetArchive = [[NSURL fileURLWithPath:desktopPath isDirectory:YES]
							URLByAppendingPathComponent:@"Touch and gesture events log.zip"];
	NSURL* tempFile = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
					   URLByAppendingPathComponent:@"TouchesDebugLog.xml"];
	[eventLog writeToURL:tempFile atomically:YES];
	[[NSFileManager defaultManager] tl_compressContentsOfURL:tempFile asArchive:targetArchive error:NULL];
	[[NSFileManager defaultManager] removeItemAtURL:tempFile error:NULL];
	
	return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification*)notification {
	(void)notification;
	if (hidTap) CFRelease(hidTap), hidTap = nil;
	if (sessionTap) CFRelease(sessionTap), sessionTap = nil;
	if (annotatedTap) CFRelease(annotatedTap), annotatedTap = nil;
}

- (void)logEvent:(NSEvent*)event method:(SEL)method {
	//printf("%s - %s ", [NSStringFromSelector(method) UTF8String], [[event description] UTF8String]);
	//NSSet* touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];
	//printf("%s\n", [[touches description] UTF8String]);
	NSDictionary* eventRecord = [NSDictionary dictionaryWithObjectsAndKeys:
								 [NSKeyedArchiver archivedDataWithRootObject:event], @"event",
								 NSStringFromSelector(method), @"method", nil];
	[eventLog addObject:eventRecord];
	
	if (sel_isEqual(method, @selector(mouseUp:))) {
		self.detectedClick = YES;
	}
	else if (sel_isEqual(method, @selector(magnifyWithEvent:))) {
		self.detectedMagnify = YES;
	}
	else if (sel_isEqual(method, @selector(rotateWithEvent:))) {
		self.detectedRotate = YES;
	}
	else if (sel_isEqual(method, @selector(swipeWithEvent:))) {
		self.detectedSwipe = YES;
	}
	else if (sel_isEqual(method, @selector(endGestureWithEvent:))) {
		self.detectedGesture = YES;
	}
	else if (sel_isEqual(method, @selector(touchesMovedWithEvent:))) {
		if ([[event touchesMatchingPhase:NSTouchPhaseAny inView:nil] count] >= 3) {
			self.detectedFingers = YES;
		}
	}
}

- (void)logCGEvent:(CGEventRef)event tap:(NSString*)tapName {
	//printf("%s - %s ", [tapName UTF8String], [[[NSEvent eventWithCGEvent:event] description] UTF8String]);
//	NSLog(@"orig: %@", [[NSEvent eventWithCGEvent:event] touchesMatchingPhase:NSTouchPhaseAny inView:nil]);
	CFDataRef eventData = CGEventCreateData(kCFAllocatorDefault, event);
   
//	CGEventRef event2 = CGEventCreateFromData(NULL, eventData);
//	NSLog(@"data: %@", [[NSEvent eventWithCGEvent:event2] touchesMatchingPhase:NSTouchPhaseAny inView:nil]);
//	CFRelease(event2);
   
	NSDictionary* eventRecord = [NSDictionary dictionaryWithObjectsAndKeys:
								 (id)eventData, @"event", tapName, @"tap", nil];
	CFRelease(eventData);
	[eventLog addObject:eventRecord];
}

@end


CGEventRef TapCB(CGEventRef event, CFStringRef tapName) {
	[[NSApp delegate] logCGEvent:event tap:(NSString*)tapName];
	return event;
}

CGEventRef HidCB(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon) {
	(void)proxy;
	(void)type;
	(void)refcon;
	return TapCB(event, CFSTR("HID"));	
}

CGEventRef SessionCB(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon) {
	(void)proxy;
	(void)type;
	(void)refcon;
	return TapCB(event, CFSTR("Session"));
}

CGEventRef AnnotatedCB(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon) {
	(void)proxy;
	(void)type;
	(void)refcon;
	return TapCB(event, CFSTR("Annotated"));
}
