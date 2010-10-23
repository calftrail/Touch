//
//  TouchView.m
//  TouchRecorder
//
//  Created by Nathan Vander Wilt on 11/24/09.
//  Copyright 2009 Calf Trail Software, LLC. All rights reserved.
//

#import "TouchView.h"


static NSString* KVOContext = @"TouchView KVO context";


@implementation TouchView

@synthesize activeTouches;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		self.acceptsTouchEvents = YES;
		self.wantsRestingTouches = YES;
		[self addObserver:self forKeyPath:@"activeTouches"
				  options:NSKeyValueObservingOptionNew context:&KVOContext];
    }
    return self;
}

- (void)dealloc {
	[self removeObserver:self forKeyPath:@"activeTouches"];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object
						change:(NSDictionary*)change context:(void*)context
{
	(void)object;
	(void)change;
    if (context == &KVOContext) {
		if ([keyPath isEqualToString:@"activeTouches"]) {
			[self setNeedsDisplay:YES];
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)drawRect:(NSRect)dirtyRect {
	[[NSColor darkGrayColor] setFill];
	NSRectFill(dirtyRect);
	
	[[NSColor lightGrayColor] set];
	NSRect b = [self bounds];
	CGFloat tw = 10.0f;
	CGFloat th = tw;
	for (NSTouch* touch in self.activeTouches) {
		NSPoint loc = [touch normalizedPosition];
		CGFloat touchX = NSMinX(b) + loc.x * NSWidth(b);
		CGFloat touchY = NSMinY(b) + loc.y * NSHeight(b);
		NSRect touchRect = NSMakeRect(touchX - tw / 2, touchY - th / 2, tw, th);
		NSBezierPath* path = [NSBezierPath bezierPathWithOvalInRect:touchRect];
		[path setLineWidth:2.0f];
		[touch isResting] ? [path stroke] : [path fill];
	}
}

- (void)logEvent:(NSEvent*)event method:(SEL)method {
	[[NSApp delegate] logEvent:event method:method];
}

- (void)mouseUp:(NSEvent*)event { [self logEvent:event method:_cmd]; }

- (void)magnifyWithEvent:(NSEvent*)event { [self logEvent:event method:_cmd]; }
- (void)rotateWithEvent:(NSEvent*)event { [self logEvent:event method:_cmd]; }
- (void)swipeWithEvent:(NSEvent*)event { [self logEvent:event method:_cmd]; }
- (void)beginGestureWithEvent:(NSEvent*)event { [self logEvent:event method:_cmd]; }
- (void)endGestureWithEvent:(NSEvent*)event { [self logEvent:event method:_cmd]; }

- (void)touchesBeganWithEvent:(NSEvent*)event {
	self.activeTouches = [event touchesMatchingPhase:NSTouchPhaseTouching inView:nil];
	[self logEvent:event method:_cmd];
}

- (void)touchesMovedWithEvent:(NSEvent*)event {
	self.activeTouches = [event touchesMatchingPhase:NSTouchPhaseTouching inView:nil];
	[self logEvent:event method:_cmd];
}

- (void)touchesEndedWithEvent:(NSEvent*)event {
	self.activeTouches = [event touchesMatchingPhase:NSTouchPhaseTouching inView:nil];
	[self logEvent:event method:_cmd];
}

- (void)touchesCancelledWithEvent:(NSEvent*)event {
	self.activeTouches = nil;
	[self logEvent:event method:_cmd];
}

@end
