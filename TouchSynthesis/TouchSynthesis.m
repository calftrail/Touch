#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>


#include "TouchEvents.h"
#include "HotkeyEvents.h"

#include "MultitouchSupport.h"
#include "IOHIDEventData.h"
#include "IOHIDEventTypes.h"
#include <libkern/OSAtomic.h>

#include <uuid/uuid.h>

#ifndef _UUID_STRING_T
#define _UUID_STRING_T
typedef	char	uuid_string_t[37];
#endif /* _UUID_STRING_T */


static CGFloat tlCGPointFindDistance(CGPoint a, CGPoint b);
static CGFloat tlCGPointFindAngle(CGPoint a, CGPoint b);
static CGPoint tlCGPointFindMidpoint(CGPoint a, CGPoint b);
static CGSize tlCGPointFindDifference(CGPoint a, CGPoint b);
static CGFloat tlCGAngleDifference(CGFloat a, CGFloat b);

static const double radiansToDegrees = 180.0 * M_1_PI;

static uint64_t gDeviceID;

@interface MagicConverter : NSObject {
@private
	NSMapTable* transducerTouches;
	NSMutableSet* frameTransducers;
	
	NSMutableSet* latchables;
	BOOL latched;
	CGFloat baseDistance;
	CGFloat baseAngle;
	CGPoint baseMidpoint;
	BOOL inGesture;
	TLInfoSubtype prevGestureType;
	CGFloat totalSent;
	
	BOOL sendSwipe;
	TLInfoSwipeDirection pendingSwipe;
}

+ (MagicConverter*)sharedConverter;
- (BOOL)allowGestureEvents;
- (void)updateTouch:(MTTouch*)touch;
- (void)postEvent;
@end

@implementation MagicConverter

+ (MagicConverter*)sharedConverter {
	static MagicConverter* volatile gSharedConverter = nil;
	if (!gSharedConverter) {
		NSAutoreleasePool* p = [NSAutoreleasePool new];
		MagicConverter* tmp = [MagicConverter new];
		[p drain];
		bool set = OSAtomicCompareAndSwapPtrBarrier(nil, tmp, (void**)&gSharedConverter);
		if (!set) [tmp release];
	}
	return gSharedConverter;
}

- (id)init {
	self = [super init];
	if (self) {
		transducerTouches = [[NSMapTable mapTableWithStrongToStrongObjects] retain];
		frameTransducers = [NSMutableSet new];
		latchables = [NSMutableSet new];
	}
	return self;
}

- (void)dealloc {
	[transducerTouches release];
	[frameTransducers release];
	[super dealloc];
}

- (void)updateTouch:(MTTouch*)touch {
	NSMutableDictionary* touchInfo = [NSMutableDictionary dictionary];
	[touchInfo setObject:[NSNumber numberWithInt:kIOHIDEventTypeDigitizer]
				  forKey:(id)kTLEventKeyType];
	
	int options = kIOHIDEventOptionIsAbsolute;
	// TODO: this might not be correct
	switch (touch->state) {
		case MTTouchStateOutOfRange:
		case MTTouchStateNotTracking:
			break;
			
		case MTTouchStateLingerInRange:
		case MTTouchStateBreakTouch:
		case MTTouchStateMakeTouch:
		case MTTouchStateTouching:
			options |= kIOHIDTransducerTouch;
		case MTTouchStateStartInRange:
		case MTTouchStateHoverInRange:
			options |= kIOHIDTransducerRange;
			break;
	}
	[touchInfo setObject:[NSNumber numberWithInt:options]
				  forKey:(id)kTLEventKeyOptions];
	
	[touchInfo setObject:[NSNumber numberWithFloat:(touch->normalizedVector.position.x)]
				  forKey:(id)kTLEventKeyPositionX];
	[touchInfo setObject:[NSNumber numberWithFloat:(1.0f - touch->normalizedVector.position.y)]
				  forKey:(id)kTLEventKeyPositionY];
	
	NSNumber* transducer = [NSNumber numberWithInt:(touch->pathIndex)];
	[touchInfo setObject:transducer
				  forKey:(id)kTLEventKeyTransducerIndex];
	[touchInfo setObject:[NSNumber numberWithInt:kIOHIDDigitizerTransducerTypeFinger]
				  forKey:(id)kTLEventKeyTransducerType];
	[touchInfo setObject:[NSNumber numberWithInt:(touch->fingerID)]
				  forKey:(id)kTLEventKeyIdentity];
	
	[touchInfo setObject:[NSNumber numberWithFloat:(touch->angle * (float)radiansToDegrees)]
				  forKey:(id)kTLEventKeyTwist];
	[touchInfo setObject:[NSNumber numberWithFloat:(touch->zTotal)]
				  forKey:(id)kTLEventKeyQuality];
	[touchInfo setObject:[NSNumber numberWithFloat:(touch->zDensity)]
				  forKey:(id)kTLEventKeyDensity];
	[touchInfo setObject:[NSNumber numberWithFloat:(touch->majorAxis)]
				  forKey:(id)kTLEventKeyMajorRadius];
	[touchInfo setObject:[NSNumber numberWithFloat:(touch->minorAxis)]
				  forKey:(id)kTLEventKeyMinorRadius];
	
	NSDictionary* prevTouchInfo = [transducerTouches objectForKey:transducer];
	int eventMask = 0;
	if (prevTouchInfo) {
		if (![[touchInfo objectForKey:(id)kTLEventKeyIdentity]
			  isEqualToNumber:[prevTouchInfo objectForKey:(id)kTLEventKeyIdentity]])
		{
			eventMask |= kIOHIDDigitizerEventIdentity;
		}
		
		if (![[touchInfo objectForKey:(id)kTLEventKeyPositionX]
			  isEqualToNumber:[prevTouchInfo objectForKey:(id)kTLEventKeyPositionX]] ||
			![[touchInfo objectForKey:(id)kTLEventKeyPositionY]
			  isEqualToNumber:[prevTouchInfo objectForKey:(id)kTLEventKeyPositionY]])
		{
			eventMask |= kIOHIDDigitizerEventPosition;
		}
		
		int32_t prevOptions = [[prevTouchInfo objectForKey:(id)kTLEventKeyOptions] intValue];
		if ((prevOptions & kIOHIDTransducerRange) != (options & kIOHIDTransducerRange)) {
			eventMask |= kIOHIDDigitizerEventRange;
		}
		if ((prevOptions & kIOHIDTransducerTouch) != (options & kIOHIDTransducerTouch)) {
			eventMask |= kIOHIDDigitizerEventTouch;
		}
	}
	else {
		// TODO: this might not be correct
		eventMask |= kIOHIDDigitizerEventTouch;
		eventMask |= kIOHIDDigitizerEventIdentity;
	}
	[touchInfo setObject:[NSNumber numberWithInt:eventMask]
				  forKey:(id)kTLEventKeyEventMask];
	
	[frameTransducers addObject:transducer];
	[transducerTouches setObject:touchInfo forKey:transducer];
}

+ (CGPoint)pointFromTouch:(NSDictionary*)touch {
	return CGPointMake((CGFloat)[[touch objectForKey:(id)kTLEventKeyPositionX] doubleValue],
					   1.0f - (CGFloat)[[touch objectForKey:(id)kTLEventKeyPositionY] doubleValue]);
}

+ (NSInteger)transitionOfTouch:(NSDictionary*)touch {
	NSInteger state = 0;
	int eventMask = [[touch objectForKey:(id)kTLEventKeyEventMask] intValue];
	if (eventMask & kIOHIDDigitizerEventTouch) {
		int options = [[touch objectForKey:(id)kTLEventKeyOptions] intValue];
		state = options & kIOHIDTransducerTouch ? 1 : -1;
	}
	return state;
}

+ (NSArray*)activeTouches:(NSArray*)touches {
	int activeOptions = kIOHIDEventOptionIsAbsolute | kIOHIDTransducerRange | kIOHIDTransducerTouch;
	NSPredicate* p = [NSPredicate predicateWithFormat:@"%K == %i", (id)kTLEventKeyOptions, activeOptions];
	return [touches filteredArrayUsingPredicate:p];
}

+ (TLInfoSubtype)classifyBasedOnSwipe:(CGSize)swipe
						magnification:(CGFloat)magnification
							 rotation:(CGFloat)rotation
{
	//printf("swipe(%f, %f) magnification(%f) rotation(%f)\n",
	//	   swipe.width, swipe.height, magnification, rotation);
	
	static const CGFloat thresholdRating = 0.5f;
	const CGFloat swipeScale = (CGFloat)(100 * 0.5) / 5;					// 5% threshold
	CGFloat swipeRating = swipeScale * (CGFloat)hypot(swipe.width, swipe.height);
	
	const CGFloat magScale = (CGFloat)(100 * 0.5) / 10;					// 10% threshold
	CGFloat magRating = magScale * (CGFloat)fabs(magnification - 1.0f);
	
	const CGFloat rotScale = (CGFloat)(radiansToDegrees * 0.5) / 5;	// 5 degree threshold
	CGFloat rotRating = rotScale * (CGFloat)fabs(rotation);
	
	//printf("%f %f %f\n", swipeRating, magRating, rotRating);
	
	CGFloat maxMagRot = MAX(magRating, rotRating);
	if (thresholdRating > MAX(swipeRating, maxMagRot)) return kTLInfoSubtypeGesture;
	else if (swipeRating > maxMagRot) return kTLInfoSubtypeSwipe;
	else if (magRating > rotRating) return kTLInfoSubtypeMagnify;
	else return kTLInfoSubtypeRotate;
}

+ (TLInfoSwipeDirection)swipeDirection:(CGSize)swipe {
	if (fabs(swipe.height) > fabs(swipe.width)) {
		return swipe.height > 0.0f ? kTLInfoSwipeUp : kTLInfoSwipeDown;
	}
	else {
		return swipe.width > 0.0f ? kTLInfoSwipeRight : kTLInfoSwipeLeft;
	}
}

- (NSDictionary*)gestureInfoForTouches:(NSArray*)theTouches {
	NSAssert([NSThread isMainThread], @"Must be called on main thread for correct latching");
	NSParameterAssert(theTouches != nil);
	NSMutableDictionary* gestureInfo = [NSMutableDictionary dictionary];
	[gestureInfo setObject:[NSNumber numberWithLongLong:gDeviceID] forKey:(id)kTLInfoKeyDeviceID];
	
	/* "Latchables" are active touches that started in our gesture zone.
	 We need exactly two active touches, both latchable, to be latched. */
	for (NSDictionary* touch in theTouches) {
		NSInteger transition = [[self class] transitionOfTouch:touch];
		if (transition) {
			NSNumber* latchID = [touch objectForKey:(id)kTLEventKeyTransducerIndex];
			[latchables removeObject:latchID];
			if (transition > 0 && [[self class] pointFromTouch:touch].y < 0.6f) {
				[latchables addObject:latchID];
			}
		}
	}
	
	CGPoint p0 = CGPointZero, p1 = CGPointZero;		// valid if latched
	BOOL latchIsNew = NO;
	NSArray* activeTouches = [[self class] activeTouches:theTouches];
	if ([activeTouches count] == 2 && [latchables count] == 2) {
		if (!latched) {
			//printf("latching\n");
			latched = YES;
			latchIsNew = YES;
		}
		id sd = [[[NSSortDescriptor alloc] initWithKey:(id)kTLEventKeyTransducerIndex ascending:YES] autorelease];
		NSArray* sortedTouches = [activeTouches sortedArrayUsingDescriptors:[NSArray arrayWithObject:sd]];
		p0 = [[self class] pointFromTouch:[sortedTouches objectAtIndex:0]];
		p1 = [[self class] pointFromTouch:[sortedTouches objectAtIndex:1]];
	}
	else if (latched && [activeTouches count] != 2) {
		//printf("unlatching\n");
		latched = NO;
	}
	
	if (latched) {
		CGFloat currentDistance = tlCGPointFindDistance(p0, p1);
		CGFloat currentAngle = tlCGPointFindAngle(p0, p1);
		CGPoint currentMidpoint = tlCGPointFindMidpoint(p0, p1);
		if (latchIsNew) {
			baseDistance = currentDistance;
			baseAngle = currentAngle;
			baseMidpoint = currentMidpoint;
		}
		
		CGSize dMidpoint = tlCGPointFindDifference(baseMidpoint, currentMidpoint);
		CGFloat rDistance = currentDistance / baseDistance;
		CGFloat dAngle = tlCGAngleDifference(baseAngle, currentAngle);
		TLInfoSubtype nextGestureType = [[self class] classifyBasedOnSwipe:dMidpoint
															 magnification:rDistance
																  rotation:dAngle];
		if (inGesture) {
			// deliver previous gesture
			TLInfoSubtype gestureType = prevGestureType;
			[gestureInfo setObject:[NSNumber numberWithInt:gestureType]
							forKey:(id)kTLInfoKeyGestureSubtype];
			
			if (gestureType == kTLInfoSubtypeSwipe) {
				[gestureInfo removeObjectForKey:(id)kTLInfoKeyGestureSubtype];
				pendingSwipe = [[self class] swipeDirection:dMidpoint];
			}
			else if (gestureType == kTLInfoSubtypeMagnify) {
				static const CGFloat maxMagnification = 0.025f;
				CGFloat magnification = rDistance - totalSent;
				if (fabs(magnification) > maxMagnification) {
					magnification = magnification > 0.0 ? maxMagnification : -maxMagnification;
				}
				//printf("Sending %f magnification\n", magnification);
				[gestureInfo setObject:[NSNumber numberWithDouble:magnification]
								forKey:(id)kTLInfoKeyMagnification];
				totalSent += magnification;
			}
			else if (gestureType == kTLInfoSubtypeRotate) {
				CGFloat rotation = dAngle - totalSent;
				//printf("Sending %f rotation\n", rotation * radiansToDegrees);
				[gestureInfo setObject:[NSNumber numberWithDouble:(rotation * radiansToDegrees)]
								forKey:(id)kTLInfoKeyRotation];
				totalSent += rotation;
			}
			
			if (nextGestureType != gestureType) {
				sendSwipe = YES;
				baseDistance = currentDistance;
				baseAngle = currentAngle;
				baseMidpoint = currentMidpoint;
				totalSent = nextGestureType != kTLInfoSubtypeMagnify ? 0.0f : 1.0f;
			}
		}
		else if (nextGestureType != kTLInfoSubtypeGesture) {
			[gestureInfo setObject:[NSNumber numberWithInt:kTLInfoSubtypeBeginGesture]
							forKey:(id)kTLInfoKeyGestureSubtype];
			[gestureInfo setObject:[NSNumber numberWithInt:nextGestureType]
							forKey:(id)kTLInfoKeyNextSubtype];
			inGesture = YES;
			totalSent = nextGestureType != kTLInfoSubtypeMagnify ? 0.0f : 1.0f;
		}
		prevGestureType = nextGestureType;
	}
	else if (inGesture) {
		sendSwipe = YES;
		[gestureInfo setObject:[NSNumber numberWithInt:kTLInfoSubtypeEndGesture]
						forKey:(id)kTLInfoKeyGestureSubtype];
		[gestureInfo setObject:[NSNumber numberWithInt:0]
						forKey:(id)kTLInfoKeyNextSubtype];
		inGesture = NO;
		prevGestureType = 0;
	}
	
	return gestureInfo;
}

static const CFStringRef SwipeActionIgnore = CFSTR("---");
static const CFStringRef SwipeActionMiddleClick = CFSTR("-|-");

+ (CFStringRef)actionWithName:(NSString*)name {
	if (!name) return NULL;
	NSDictionary* actionNames = [NSDictionary dictionaryWithObjectsAndKeys:
								 (id)SwipeActionIgnore, @"Ignore",
								 (id)SwipeActionMiddleClick, @"Middle Click",
								 (id)kTLEventActionExposeDesktop, @"Show Desktop",
								 (id)kTLEventActionExposeApplication, @"App Exposé",
								 (id)kTLEventActionExposeAll, @"Exposé",
								 (id)kTLEventActionDashboard, @"Dashboard",
								 (id)kTLEventActionSpaces, @"Spaces", nil];
	return (CFStringRef)[actionNames objectForKey:name];
}

- (CFStringRef)actionForSwipe:(TLInfoSwipeDirection)theSwipe {
	if (theSwipe == kTLInfoSwipeLeft || theSwipe == kTLInfoSwipeRight) {
		// mouse already sends left and right
		return SwipeActionIgnore;
	}
	
	CFStringRef key;
	switch (theSwipe) {
		case kTLInfoSwipeUp:
			key = CFSTR("SwipeActionUp");
			break;
		case kTLInfoSwipeDown:
			key = CFSTR("SwipeActionDown");
			break;
		case kTLInfoSwipeLeft:
			key = CFSTR("SwipeActionLeft");
			break;
		case kTLInfoSwipeRight:
			key = CFSTR("SwipeActionRight");
			break;
		default:
			return NULL;
	}
	CFStringRef suite = CFSTR("com.calftrail.touch-synthesis");
	CFPreferencesAppSynchronize(suite);
	CFStringRef name = CFPreferencesCopyAppValue(key, suite);
	CFStringRef action = [[self class] actionWithName:(id)name];
	if (name) CFRelease(name);
	return action;
}

- (void)postEventsForSwipe:(TLInfoSwipeDirection)theSwipe touches:(NSArray*)eventTouches {
	CFStringRef action = [self actionForSwipe:theSwipe];
	if (!action) {
		NSDictionary* swipeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   [NSNumber numberWithInt:kTLInfoSubtypeSwipe], (id)kTLInfoKeyGestureSubtype,
								   [NSNumber numberWithInt:pendingSwipe], (id)kTLInfoKeySwipeDirection, nil];
		CGEventRef e = tl_CGEventCreateFromGesture((CFDictionaryRef)swipeInfo, (CFArrayRef)eventTouches);
		CGEventPost(kCGHIDEventTap, e);
		CFRelease(e);
	}
	else if (action == SwipeActionMiddleClick) {
		CGEventRef e = CGEventCreate(NULL);
		CGPoint pos = CGEventGetLocation(e);
		CFRelease(e);
		CGEventRef e1 = CGEventCreateMouseEvent(NULL, kCGEventOtherMouseDown, pos, kCGMouseButtonCenter);
		CGEventPost(kCGHIDEventTap, e1);
		CFRelease(e1);
		CGEventRef e2 = CGEventCreateMouseEvent(NULL, kCGEventOtherMouseUp, pos, kCGMouseButtonCenter);
		CGEventPost(kCGHIDEventTap, e2);
		CFRelease(e2);
	}
	else if (action != SwipeActionIgnore) {
		CFArrayRef sequence = tl_CGEventSequenceCreateForAction(action);
		for (id event in (id)sequence) {
			CGEventPost(kCGHIDEventTap, (CGEventRef)event);
		}
		if (sequence) CFRelease(sequence);
	}
}

- (void)postEvent {
	NSMutableArray* eventTouches = [NSMutableArray array];
	for (id transducer in frameTransducers) {
		[eventTouches addObject:
		 [transducerTouches objectForKey:transducer]];
	}
	NSDictionary* gestureInfo = [self gestureInfoForTouches:eventTouches];
	if (gestureInfo) {
		CGEventRef e = tl_CGEventCreateFromGesture((CFDictionaryRef)gestureInfo,
												   (CFArrayRef)eventTouches);
		CGEventPost(kCGHIDEventTap, e);
		CFRelease(e);
	}
	if (pendingSwipe && sendSwipe) {
		[self postEventsForSwipe:pendingSwipe touches:eventTouches];
		sendSwipe = pendingSwipe = 0;
	}
	[frameTransducers removeAllObjects];
}

- (BOOL)allowGestureEvents {
	NSAssert([NSThread isMainThread], @"Must be called on main thread for correct latching");
	return !latched;
}

@end


static CFMachPortRef gHIDTap = NULL;

static void updateTouch(MTDeviceRef device, long pathID, long state, MTTouch* touch) {
	(void)device;
	(void)pathID;
	(void)state;
	//printf("%i %i\n", touch->pathIndex, touch->fingerID);
	NSAutoreleasePool* p = [NSAutoreleasePool new];
	[[MagicConverter sharedConverter] updateTouch:touch];
	[p drain];
}

static void finishFrame(MTDeviceRef device,
						MTTouch touches[], size_t numTouches,
						double timestamp, size_t frame)
{
	(void)device;
	(void)timestamp;
	(void)touches;
	(void)numTouches;
	(void)timestamp;
	(void)frame;
	NSAutoreleasePool* p = [NSAutoreleasePool new];
	[[MagicConverter sharedConverter] performSelectorOnMainThread:@selector(postEvent)
													   withObject:nil
													waitUntilDone:YES];
	[p drain];
}

static CGEventRef filterEvents(CGEventTapProxy proxy,
							   CGEventType type, CGEventRef event,
							   void* refcon)
{
	(void)proxy;
	(void)type;
	(void)refcon;
	if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
		/* This can happen if we are too slow to respond to events, or other unknown reason(s).
		 See http://lists.apple.com/archives/quartz-dev/2007/Mar/msg00085.html
		 and http://lists.apple.com/archives/quartz-dev/2009/Sep/msg00007.html */
		CGEventTapEnable(gHIDTap, true);
		return NULL;
	}
	return [[MagicConverter sharedConverter] allowGestureEvents] ? event : NULL;
}

static void printDeviceInfo(MTDeviceRef d) {
	uuid_t guid;
	OSStatus err = MTDeviceGetGUID(d, &guid);
	if (!err) {
		uuid_string_t val;
		uuid_unparse(guid, val);
		printf("%s ", val);
	}
	
	int a;
	err = MTDeviceGetDriverType(d, &a);
	if (!err) printf("driver type - 0x%x, ", a);
	err = MTDeviceGetActualType(d, &a);
	if (!err) printf("actual type - 0x%x, ", a);
	
	if (MTDeviceGetDeviceID) {
		uint64_t devID;
		err = MTDeviceGetDeviceID(d, &devID);
		if (!err) printf("devID: 0x%llx, ", devID, devID);
	}
	
	err = MTDeviceGetFamilyID(d, &a);
	if (!err) printf("famID: %i, ", a);
	
	int b;
	err = MTDeviceGetSensorSurfaceDimensions(d, &a, &b);
	if (!err) printf("%i x %i ", a, b);
	
	if (MTDeviceIsBuiltIn) printf(MTDeviceIsBuiltIn(d) ? "built-in " : "external ");
	printf(MTDeviceIsOpaqueSurface(d) ? "opaque" : "non-opaque");
	printf("\n");
}


static MTDeviceRef createMagicMouseDevice() {
	NSMutableArray* externalDevices = [NSMutableArray new];
	NSArray* devices = (id)MTDeviceCreateList();
	for (id device in devices) {
		//printDeviceInfo((MTDeviceRef)device);
		(void)printDeviceInfo;
		
		// on 10.6 we can easily find Magic Mouse as the external device
		if (MTDeviceIsBuiltIn && !MTDeviceIsBuiltIn((MTDeviceRef)device)) {
			[externalDevices addObject:device];
		}
		else if (!MTDeviceIsBuiltIn) {
			// but on 10.5, we use the sensor dimensions to distinguish
			// TODO: could we use DriverType==0x4 or FamilyID==112 instead?
			int width, height;
			OSStatus err = MTDeviceGetSensorSurfaceDimensions((MTDeviceRef)device, &width, &height);
			if (!err && width == 5152 && height == 9056) {
				[externalDevices addObject:device];
			}
		}
	}
	[devices release];
	
	MTDeviceRef mouse = NULL;
	if ([externalDevices count]) {
		mouse = [[externalDevices objectAtIndex:0] retain];
	}
	[externalDevices release];
	return mouse;
}


int main() {
	MTDeviceRef device = createMagicMouseDevice();
	if (!device) {
		fprintf(stderr, "No external multitouch device found.\n");
		return 42;
	}
	if (MTDeviceGetDeviceID) MTDeviceGetDeviceID(device, &gDeviceID);
	MTRegisterPathCallback(device, updateTouch);
	MTRegisterContactFrameCallback(device, finishFrame);
	MTDeviceStart(device, 0);
	
	CFRunLoopRef rl = CFRunLoopGetCurrent();
#if 0
	// The following doesn't work
	CFRunLoopSourceRef mtSrc = MTDeviceCreateMultitouchRunLoopSource(device);
	assert(mtSrc != NULL);
	CFRunLoopAddSource(rl, mtSrc, kCFRunLoopCommonModes);
	CFRelease(mtSrc);
#endif
	
	CGEventMask events =  NSScrollWheelMask;
	CGEventTapOptions options = kCGEventTapOptionDefault;
	//options = kCGEventTapOptionListenOnly;
	gHIDTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap,
							   options, events, filterEvents, NULL);
	if (gHIDTap) {
		CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, gHIDTap, 0);
		CFRunLoopAddSource(rl, src, kCFRunLoopCommonModes);
		CFRelease(src);
	}
	
	CFRunLoopRun();
	
	// this isn't reached, but would cleanup
	CFRelease(gHIDTap);
	MTDeviceStop(device);
	CFRelease(device);
	return EXIT_SUCCESS;
}


CGFloat tlCGPointFindDistance(CGPoint a, CGPoint b) {
	CGFloat dX = b.x - a.x;
	CGFloat dY = b.y - a.y;
	return (CGFloat)hypot(dX, dY);
}

CGFloat tlCGPointFindAngle(CGPoint a, CGPoint b) {
	CGFloat dX = b.x - a.x;
	CGFloat dY = b.y - a.y;
	return (CGFloat)atan2(dY, dX);
}

CGPoint tlCGPointFindMidpoint(CGPoint a, CGPoint b) {
	CGFloat sX = a.x + b.x;
	CGFloat sY = a.y + b.y;
	return CGPointMake(sX / 2, sY / 2);
}

CGSize tlCGPointFindDifference(CGPoint a, CGPoint b) {
	CGFloat dX = b.x - a.x;
	CGFloat dY = b.y - a.y;
	return CGSizeMake(dX, dY);
}

CGFloat tlCGAngleDifference(CGFloat a, CGFloat b) {
	// (-180, 180) - (-180, 180) = (-360, 360)
	CGFloat d = b - a;
	if (d < -M_PI) d += 2 * (CGFloat)M_PI;
	else if (d > M_PI) d -= 2 * (CGFloat)M_PI;
	return d;
}
