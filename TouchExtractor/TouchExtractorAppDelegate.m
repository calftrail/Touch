//
//  TouchExtractorAppDelegate.m
//  TouchExtractor
//
//  Created by Nathan Vander Wilt on 11/24/09.
//  Copyright 2009 Calf Trail Software, LLC. All rights reserved.
//


#import "TouchExtractorAppDelegate.h"

@implementation TouchExtractorAppDelegate

@synthesize window;


- (void)replayEvents:(NSArray*)eventLog {
	CGEventTimestamp prevTimestamp = 0;
	for (NSDictionary* eventInfo in eventLog) {
		NSData* eventData = [eventInfo objectForKey:@"event"];
		if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			CGEventRef e = CGEventCreateFromData(kCFAllocatorDefault, (CFDataRef)eventData);
			CGEventTimestamp origTimestamp = CGEventGetTimestamp(e);
			if (CGEventGetType(e) == 29) {				
				if (prevTimestamp) {
					uint64_t delay = 0;
					if (origTimestamp > prevTimestamp) {
						delay = origTimestamp - prevTimestamp;
					}
					usleep(delay / 1000);
				}
				
				CGEventRef proto = CGEventCreate(NULL);
				CGPoint mousePos = CGEventGetLocation(proto);
				CFRelease(proto);
				CGEventSetTimestamp(e, 0);
				CGEventSetLocation(e, mousePos);
				CGEventPost(kCGHIDEventTap, e);
			}
			prevTimestamp = origTimestamp;
			CFRelease(e);
		}
	}
}

- (void)rebuildEvents:(NSArray*)eventLog {
	UniChar buff[16];
	CGEventTimestamp prevTimestamp = 0;
	for (NSDictionary* eventInfo in eventLog) {
		NSData* eventData = [eventInfo objectForKey:@"event"];
		if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			CGEventRef e = CGEventCreateFromData(kCFAllocatorDefault, (CFDataRef)eventData);
			CGEventTimestamp origTimestamp = CGEventGetTimestamp(e);
			if (CGEventGetType(e) == 29) {
				CGEventRef e2 = CGEventCreate(NULL);
				CGEventSetType(e2, CGEventGetType(e));
				CGEventSetFlags(e2, CGEventGetFlags(e));
				for (uint32_t field = 0; field < UINT16_MAX; field++) {
					double val = CGEventGetDoubleValueField(e, field);
					CGEventSetDoubleValueField(e2, field, val);
				}
				
				UniCharCount len;
				CGEventKeyboardGetUnicodeString(e, 16, &len, buff);
				NSAssert(len <= 16, @"Event string too long");
				CGEventKeyboardSetUnicodeString(e2, len, buff);
				
				if (prevTimestamp) {
					uint64_t delay = 0;
					if (origTimestamp > prevTimestamp) {
						delay = origTimestamp - prevTimestamp;
					}
					usleep(delay / 1000);
				}
				
				CGEventRef proto = CGEventCreate(NULL);
				CGPoint mousePos = CGEventGetLocation(proto);
				CFRelease(proto);
				CGEventSetTimestamp(e2, 0);
				CGEventSetLocation(e2, mousePos);
				CGEventPost(kCGHIDEventTap, e2);
				CFRelease(e2);
			}
			prevTimestamp = origTimestamp;
			CFRelease(e);
		}
	}
}

- (void)dumpEvents:(NSArray*)eventLog {
	for (NSDictionary* eventInfo in eventLog) {
		NSData* eventData = [eventInfo objectForKey:@"event"];
		if ([eventInfo objectForKey:@"method"]) {
			NSEvent* event = [NSKeyedUnarchiver unarchiveObjectWithData:eventData];
			printf("%s (%s)\n", [[event description] UTF8String], [[eventInfo objectForKey:@"method"] UTF8String]);
			
			if ([event type] != NSEventTypeGesture) continue;
			NSSet* touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];
			NSAssert(![touches count], @"An event stored some touches after all!");
		}
		else if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			CGEventRef e = CGEventCreateFromData(kCFAllocatorDefault, (CFDataRef)eventData);
			
			printf("\n");
			bool hadPrevField = false;
			for (int field = 0; field < SHRT_MAX; ++field) {
				if (field == kCGEventSourceUnixProcessID ||
					field == kCGEventSourceUserID ||
					field == kCGEventSourceGroupID ||
					field == 58 ||	// field 58 is timestamp
					field == 55)	// field 55 is type
				{
					continue;
				}
				
				double val = CGEventGetDoubleValueField(e, field);
				if ((field == 50 && val == 248.0) ||
					(field == 53 && val == 3.0) ||
					(field == 59 && val == 256.0) ||
					(field == 101 && val == 4.0) ||
					(field == 102 && val == 63.0) ||
					(field == 110 && val == 11.0))
				{
					// filter unknown but consistent fields
					continue;
				}
				
				if (val) {
					if (hadPrevField) printf(", ");
					else hadPrevField = true;
					//printf("%i - %f", field, val);
               printf("0x%02X - %f", field, val);
				}
			}
			printf("\n");
			
			NSEvent* event = [NSEvent eventWithCGEvent:e];
			CFRelease(e);
			printf("CG->%s\n", [[event description] UTF8String]);
		}
	}
}

#include "IOHIDEventData.h"

static inline CGFloat tl_fixed2float(IOFixed i) { return i / 65536.0f; }

static IOFixed gPrevParentX = 0;

- (void)explainGestureData:(CFDataRef)eventData {
	NSAssert(CFSwapInt16LittleToHost(0x1234) == 0x1234, @"This code does not swap bytes, so is little-endian only");
	
	size_t len = CFDataGetLength(eventData);
	const UInt8* bytes = CFDataGetBytePtr(eventData);
	
	ptrdiff_t offset = 0;
	NSAssert(offset + sizeof(IOHIDSystemQueueElement) <= len, @"Data too short to contain HIDEvent header");
	IOHIDSystemQueueElement header = *(IOHIDSystemQueueElement*)(bytes + offset);
	offset += sizeof(IOHIDSystemQueueElement);
	
   printf("IOHIDEvents @ %llu, options: 0x%08x ", header.timeStamp, header.options);
	printf("{\n");
	uint32_t parentOptions = 0;
	uint32_t parentMask = 0;
	uint32_t parentChildMask = 0;
	uint32_t childOptions = kIOHIDEventOptionIsAbsolute;
	uint32_t childMask = 0;
	uint32_t childChildMask = 0;
	IOFixed parentX = 0;
	uint32_t touchChildCount = 0;
	IOFixed touchChildAvgX = 0;
	uint32_t rangeChildCount = 0;
	IOFixed rangeChildAvgX = 0;
	uint32_t otherChildCount = 0;
	IOFixed otherChildAvgX = 0;
   NSAssert(header.attributeLength == 0, @"New attributes field is not handled!");
	for (uint32_t childIdx = 0; childIdx < header.eventCount; ++childIdx) {
		NSAssert(offset + sizeof(IOHIDEventData) <= len, @"Data too short to contain child event data");
		IOHIDEventData eventBase = *(IOHIDEventData*)(bytes + offset);
		NSAssert(offset + eventBase.size <= len, @"Data too short for child event data size");
		
		if (childIdx) printf(",\n");
		if (eventBase.type == kIOHIDEventTypeDigitizer) {
			NSAssert(sizeof(IOHIDDigitizerEventData) <= eventBase.size, @"Event size not large enough for type");
			IOHIDDigitizerEventData digitizerEvent = *(IOHIDDigitizerEventData*)(bytes + offset);
			if (digitizerEvent.options & kIOHIDEventOptionIsCollection) {
				parentOptions = digitizerEvent.options & ~kIOHIDEventOptionIsCollection;
				parentMask = digitizerEvent.eventMask;
				parentChildMask = digitizerEvent.childEventMask;
				parentX = digitizerEvent.position.x;
			}
			else {
				if (digitizerEvent.identity) {
					childMask |= digitizerEvent.eventMask;
					childOptions |= digitizerEvent.options;
				}
				childChildMask |= digitizerEvent.eventMask;
				
				if (digitizerEvent.options & kIOHIDTransducerTouch) {
					++touchChildCount;
					touchChildAvgX += digitizerEvent.position.x;
				}
				else if (digitizerEvent.options & kIOHIDTransducerRange) {
					++rangeChildCount;
					rangeChildAvgX += digitizerEvent.position.x;
				}
				else {
					++otherChildCount;
					otherChildAvgX += digitizerEvent.position.x;
				}
			}
			printf(" digitizer event: {\n");
			printf("  options: 0x%08x\n", digitizerEvent.options);
			printf("  position: %f, %f, %f\n",
				   tl_fixed2float(digitizerEvent.position.x),
				   tl_fixed2float(digitizerEvent.position.y),
				   tl_fixed2float(digitizerEvent.position.z));
			printf("  transducerIndex: %i, transducerType: %i, identity: %i\n",
				   digitizerEvent.transducerIndex,
				   digitizerEvent.transducerType,
				   digitizerEvent.identity);
			printf("  eventMask: 0x%08x, childEventMask: 0x%08x\n", digitizerEvent.eventMask, digitizerEvent.childEventMask);
			printf("  buttonMask: 0x%08x, tipPressure: %f, barrelPressure: %f\n",
				   digitizerEvent.buttonMask,
				   tl_fixed2float(digitizerEvent.pressure),
				   tl_fixed2float(digitizerEvent.auxPressure));
			printf("  twist: %f\n", tl_fixed2float(digitizerEvent.twist));
			switch(digitizerEvent.orientationType) {
				case 0:
					printf("  tilt orientation: %f, %f\n",
						   tl_fixed2float(digitizerEvent.orientation.tilt.x),
						   tl_fixed2float(digitizerEvent.orientation.tilt.y));
					break;
				case 1:
					printf("  polar orientation: %f, %f\n",
						   tl_fixed2float(digitizerEvent.orientation.polar.altitude),
						   tl_fixed2float(digitizerEvent.orientation.polar.azimuth));
					break;
				case 2:
					printf("  quality orientation: { q: %f, d: %f, i: %f, a: %f, b: %f }\n",
						   tl_fixed2float(digitizerEvent.orientation.quality.quality),
						   tl_fixed2float(digitizerEvent.orientation.quality.density),
						   tl_fixed2float(digitizerEvent.orientation.quality.irregularity),
						   tl_fixed2float(digitizerEvent.orientation.quality.majorRadius),
						   tl_fixed2float(digitizerEvent.orientation.quality.minorRadius));
					break;
				default:
					printf("Unknown orientation type %i\n", digitizerEvent.orientationType);
			}
			printf(" }");
		}
		else if (eventBase.type == kIOHIDEventTypeOrientation ||
				 eventBase.type == kIOHIDEventTypeScroll ||
				 eventBase.type == kIOHIDEventTypeVelocity ||
				 eventBase.type == kIOHIDEventTypeTranslation ||
				 eventBase.type == kIOHIDEventTypeRotation ||
				 eventBase.type == kIOHIDEventTypeScale
				)
		{
			NSAssert(sizeof(IOHIDAxisEventData) <= eventBase.size, @"Event size not large enough for type");
			IOHIDAxisEventData orientationEvent = *(IOHIDAxisEventData*)(bytes + offset);
			const char* eventType;
			switch (eventBase.type) {
				case kIOHIDEventTypeOrientation:
					eventType = "orientation";
					break;
				case kIOHIDEventTypeScroll:
					eventType = "scroll";
					break;
				case kIOHIDEventTypeVelocity:
					eventType = "velocity";
					break;
				case kIOHIDEventTypeTranslation:
					eventType = "translation";
					break;
				case kIOHIDEventTypeRotation:
					eventType = "rotation";
					break;
				case kIOHIDEventTypeScale:
					eventType = "scale";
					break;
				default:
					eventType = "unexpected axis";
			}
			printf(" %s event: {\n", eventType);
			printf("  options: 0x%08x\n", orientationEvent.options);
			printf("  position: %f, %f, %f\n",
				   tl_fixed2float(orientationEvent.position.x),
				   tl_fixed2float(orientationEvent.position.y),
				   tl_fixed2float(orientationEvent.position.z));
			printf(" }");
		}
		else if (eventBase.type == kIOHIDEventTypeSwipe) {
			NSAssert(sizeof(IOHIDSwipeEventData) <= eventBase.size, @"Event size not large enough for type");
			IOHIDSwipeEventData swipeEvent = *(IOHIDSwipeEventData*)(bytes + offset);
			childChildMask |= kIOHIDDigitizerEventPosition;
			childOptions |= kIOHIDTransducerRange | kIOHIDTransducerTouch | kIOHIDEventOptionIsAbsolute;
			printf(" swipe event { options: 0x%08x, swipeMask: %i }", swipeEvent.options, swipeEvent.swipeMask);
		}
		else if (eventBase.type == kIOHIDEventTypeForce) {
			//NSAssert(sizeof(IOHIDSwipeEventData) <= eventBase.size, @"Event size not large enough for type");
			//IOHIDSwipeEventData swipeEvent = *(IOHIDSwipeEventData*)(bytes + offset);
			printf(" force event { unknown structure, additional size = %lu }", eventBase.size - sizeof(eventBase));
		}
		else if (eventBase.type == kIOHIDEventTypeButton) {
			NSAssert(sizeof(IOHIDButtonEventData) <= eventBase.size, @"Event size not large enough for type");
			IOHIDButtonEventData buttonEvent = *(IOHIDButtonEventData*)(bytes + offset);
			
			printf(" button event: {\n");
			printf("  options: 0x%08x\n", buttonEvent.options);
			printf("  buttonMask: 0x%08x, pressure: %f, buttonNumber: %hhu, clickState: %u\n",
				   buttonEvent.mask,
				   tl_fixed2float(buttonEvent.pressure),
				   buttonEvent.number,
				   buttonEvent.state);
			printf(" }");
		}
		else if (eventBase.type == kIOHIDEventTypeMouse) {
			NSAssert(sizeof(IOHIDMouseEventData) <= eventBase.size, @"Event size not large enough for type");
			IOHIDMouseEventData mouseEvent = *(IOHIDMouseEventData*)(bytes + offset);
			
			printf(" mouse event: {\n");
			printf("  options: 0x%08x\n", mouseEvent.options);
			printf("  position: %f, %f, %f\n",
				   tl_fixed2float(mouseEvent.position.x),
				   tl_fixed2float(mouseEvent.position.y),
				   tl_fixed2float(mouseEvent.position.z));
			printf("  mask: 0x%08x\n", mouseEvent.button.mask);
			printf(" }");
		}
		else if (eventBase.type == kIOHIDEventTypeVendorDefined) {
			NSAssert(sizeof(IOHIDVendorDefinedEventData) <= eventBase.size, @"Event size not large enough for type");
			IOHIDVendorDefinedEventData vendorBase = *(IOHIDVendorDefinedEventData*)(bytes + offset);
			printf(" vendor defined: { options: 0x%08x, usagePage: 0x%04x, usage: 0x%04x, length: %u}",
				   vendorBase.options, vendorBase.usagePage, vendorBase.usage, vendorBase.length);
		}
		else {
			printf(" <unparsed type %u>", eventBase.type);
		}
		offset += eventBase.size;
	}
	printf("\n}");
	
	return;
	
	NSAssert(parentMask == childMask, @"Incorrect assumption about parent/child eventMask relationship");
	//if (parentMask != childMask) printf("****No good assumption about parent/child eventMask relationship");
	NSAssert(parentChildMask == childChildMask, @"Incorrect assumption about parent/child childEventMask relationship");
	NSAssert(parentOptions == childOptions, @"Incorrect assumption about parent/child option relationship");
	//if (parentOptions != childOptions) printf("****Incorrect assumption about parent/child option relationship!");
	
	static int diffThreshold = 2;
	if (touchChildCount) {
		int diff = (int)parentX - touchChildAvgX / touchChildCount;
		NSAssert1(diff < diffThreshold, @"Touch X not as expected (%i off)", diff);
	}
	else if (rangeChildCount) {
		int diff = (int)parentX - rangeChildAvgX / rangeChildCount;
		NSAssert1(diff < diffThreshold, @"Range X not as expected (%i off)", diff);
	}
	else if (otherChildCount) {
		int diff = (int)parentX - otherChildAvgX / otherChildCount;
		NSAssert1(diff < diffThreshold, @"Other X not as expected (%i off)", diff);
	}
	else if (gPrevParentX) {
		NSAssert(gPrevParentX == parentX, @"Previous X not as expected");
	}
	gPrevParentX = parentX;
}

- (void)explainEventData:(CFDataRef)eventData {
	size_t len = CFDataGetLength(eventData);
	const UInt8* bytes = CFDataGetBytePtr(eventData);
	
	NSAssert(len >= 4, @"Data too short to contain version number");
	uint32_t version = CFSwapInt32BigToHost(*(uint32_t*)bytes);
	NSAssert(version == 2, @"Only know about version 2 of CGEventRef data structure");
	
	ptrdiff_t offset = 4;
	while (offset < len) {
		NSAssert(len - offset >= 4, @"Data remaining cannot be a field header");
		uint16_t dataCount = CFSwapInt16BigToHost(*(uint16_t*)(bytes + offset));
		offset += 2;
		
		uint8_t dataType = *(bytes + offset);
		offset += 1;
		
		uint8_t field = *(bytes + offset);
		offset += 1;
		
		printf("Field 0x%02X: ", field);
		switch (dataType) {
			case 0x00:	// uint64_t
				for (uint16_t i = 0; i < dataCount; ++i) {
					NSAssert(offset + sizeof(uint64_t) <= len, @"Not enough data in field");
					uint32_t lsb = CFSwapInt32BigToHost(*(uint32_t*)(bytes + offset));
					offset += sizeof(uint32_t);
					uint32_t msb = CFSwapInt32BigToHost(*(uint32_t*)(bytes + offset));
					offset += sizeof(uint32_t);
					
					uint64_t val = ((uint64_t)msb << 32) + lsb;
					if (i) printf(", ");
					printf("%llu", val);
				}
				break;
			case 0x10:	// uint8_t
				if (field == 0x6D) {
					NSAssert(offset + dataCount <= len, @"Not enough data in field");
					CFDataRef gestureData = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault,
																		(bytes+offset), dataCount,
																		kCFAllocatorNull);
					[self explainGestureData:gestureData];
					offset += dataCount;
				}
				else for (uint16_t i = 0; i < dataCount; ++i) {
					NSAssert(offset + sizeof(uint8_t) <= len, @"Not enough data in field");
					uint8_t val = *(bytes + offset);
					offset += sizeof(uint8_t);
					if (i) printf(", ");
					printf("%hhu", val);
				}
				break;
			case 0x40:	// uint32_t
				for (uint16_t i = 0; i < dataCount; ++i) {
					NSAssert(offset + sizeof(uint32_t) <= len, @"Not enough data in field");
					uint32_t val = CFSwapInt32BigToHost(*(uint32_t*)(bytes + offset));
					offset += sizeof(uint32_t);
					if (i) printf(", ");
					printf("%u", val);
				}
				break;
			case 0xC0:	// float32
				for (uint16_t i = 0; i < dataCount; ++i) {
					NSAssert(offset + sizeof(CFSwappedFloat32) <= len,@"Not enough data in field");
					Float32 val = CFConvertFloat32SwappedToHost(*(CFSwappedFloat32*)(bytes + offset));
					offset += sizeof(CFSwappedFloat32);
					if (i) printf(", ");
					printf("%f", val);
				}
				break;
			default:
				NSAssert(false, @"Unknown data type!");
		}
		printf("\n");
	}
}


- (void)dumpEvents2:(NSArray*)eventLog {
	for (NSDictionary* eventInfo in eventLog) {
		if ([eventInfo objectForKey:@"method"]) {
			//NSData* eventData = [eventInfo objectForKey:@"event"];
			//NSEvent* event = [NSKeyedUnarchiver unarchiveObjectWithData:eventData];
			//printf("*** %s (%s)\n\n\n", [[event description] UTF8String], [[eventInfo objectForKey:@"method"] UTF8String]);
			continue;
		}
		else if (![[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) continue;
		
		CFDataRef eventData = (CFDataRef)[eventInfo objectForKey:@"event"];
printf("\n----\n\n");
		[self explainEventData:eventData];
		CGEventRef e = CGEventCreateFromData(kCFAllocatorDefault, eventData);
		NSEvent* event = [NSEvent eventWithCGEvent:e];
		printf("CG->%s ", [[event description] UTF8String]);
		//printf("%lli ", CGEventGetIntegerValueField(e, 0x6D)); /* _mthid_copyDeviceInfo(xxx) failed */
		NSSet* t = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];
		printf(" touches: %s\n\n", [[t description] UTF8String]);
		
		CFRelease(e);
	}
}

- (void)inspectEvents:(NSArray*)eventLog {
	NSMutableIndexSet* fieldSet = [NSMutableIndexSet indexSet];
	UniChar buff[16];
	for (NSDictionary* eventInfo in eventLog) {
		NSData* eventData = [eventInfo objectForKey:@"event"];
		const char* bytes = [eventData bytes];
		(void)bytes;
		if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			CGEventRef e = CGEventCreateFromData(kCFAllocatorDefault, (CFDataRef)eventData);
			
			UniCharCount len = 0;
			CGEventKeyboardGetUnicodeString(e, 16, &len, buff);
			NSAssert(len <= 16, @"Too long of string");
			if (len > 16) 
				for (UniCharCount i = 0; i < len; ++i) {
					NSAssert(!buff[i], @"Found something!");
					//printf("%i ", buff[i]);
				}
			//printf("\n");
			
			for (uint32_t field = USHRT_MAX; field > 0; --field) {	// UINT32_MAX is ~futile
				double val = CGEventGetDoubleValueField(e, field);
				if (val) {
					[fieldSet addIndex:field];
				}
			}
			CFRelease(e);
		}
	}
	NSLog(@":::Final::: %@", fieldSet);
}

- (void)filterEvents:(NSArray*)eventLog {
	NSMutableArray* filteredEvents = [NSMutableArray array];
	for (NSDictionary* eventInfo in eventLog) {
		if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			NSData* eventData = [eventInfo objectForKey:@"event"];
			[filteredEvents addObject:eventData];
		}
	}
	[filteredEvents writeToFile:@"/Users/nathan/Desktop/filtered events.xml" atomically:YES];
}

- (void)filterEvents2:(NSArray*)eventLog {
	int fd = open("/Users/natevw/Desktop/filtered event data.bin", O_WRONLY | O_CREAT | O_TRUNC);
	NSAssert(fd >= 0, @"Couldn't open file");
	
	for (NSDictionary* eventInfo in eventLog) {
		if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			NSData* eventData = [eventInfo objectForKey:@"event"];
			const char* bytes = [eventData bytes];
			NSUInteger len = [eventData length];
			NSAssert(len <= 1024, @"Data is so too much.");
			for (NSUInteger i = 0; i < len; ++i) {
				write(fd, bytes+i, 1);
			}
			for (NSUInteger i = len; i < 1024; ++i) {
				write(fd, "", 1);
			}
		}
	}
	close(fd);
}

- (void)filterEvents3:(NSArray*)eventLog {
	int fd = open("/Users/nathan/Desktop/filtered gesture fields.rawData", O_WRONLY | O_CREAT | O_TRUNC);
	NSAssert(fd >= 0, @"Couldn't open file");
	
	for (NSDictionary* eventInfo in eventLog) {
		if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			NSData* eventData = [eventInfo objectForKey:@"event"];
			NSData* gestureData =[eventData subdataWithRange:NSMakeRange(104+4, 288)];
			const char* bytes = [gestureData bytes];
			NSUInteger len = [gestureData length];
			NSAssert(len <= 320, @"Data is so too much.");
			for (NSUInteger i = 0; i < len; ++i) {
				write(fd, bytes+i, 1);
			}
			for (NSUInteger i = len; i < 320; ++i) {
				write(fd, "-", 1);
			}
		}
	}
	close(fd);
}


#include "EventDecode.h"

typedef struct _CGSEventRecord CGSEventRecord;
extern CGSEventRecord* CGEventRecordPointer(CGEventRef e);


- (void)decodeEvents:(NSArray*)eventLog {
	bool havePrevData;
	CGSEventData prevData;
	for (NSDictionary* eventInfo in eventLog) {
		if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			NSData* eventData = [eventInfo objectForKey:@"event"];
			CGEventRef e = CGEventCreateFromData(kCFAllocatorDefault, (CFDataRef)eventData);
			CGEventKeyboardSetUnicodeString(e, 4, (UniChar*)"t\0e\0s\0t\0");
			CGSEventRecord rec = *CGEventRecordPointer(e);
			
			if (havePrevData) {
				NSMutableIndexSet* diffs = [NSMutableIndexSet indexSet];
				for (size_t i = 0; i < sizeof(CGSEventData); ++i) {
					char prev = ((char*)&prevData)[i];
					char curr = ((char*)&rec.data)[i];
					if (curr !=prev) [diffs addIndex:i];
				}
				if ([diffs count]) printf("Data differs %s\n", [[diffs description] UTF8String]);
			}
			else havePrevData = true;
			
			prevData = rec.data;
			CFRelease(e);
		}
	}
}

- (void)compareData:(CFDataRef)data1
			 toData:(CFDataRef)data2
{
	CFIndex len1 = CFDataGetLength(data1);
	CFIndex len2 = CFDataGetLength(data2);
	
	const UInt8* bytes1 = CFDataGetBytePtr(data1);
	const UInt8* bytes2 = CFDataGetBytePtr(data2);
	NSMutableIndexSet* diffs = [NSMutableIndexSet indexSet];
	for (CFIndex i = 108; i < MIN(len1, len2); ++i) {
		UInt8 val1 = bytes1[i];
		UInt8 val2 = bytes2[i];
		if (val1 != val2) {
			//printf("Byte\t%li differs: %02hhX -> %02hhX\n", i, val1, val2);
			(void)val1; (void)val2;
			[diffs addIndex:(i-108)];
		}
	}
	if (len1 < len2) {
		for (CFIndex i = len1; i < len2; ++i) {
			UInt8 val2 = bytes2[i];
			(void)val2;
			//printf("Byte\t%li   added:    -> %02hhX\n", i, val2);
		}
	}
	if (len2 < len1) {
		for (CFIndex i = len2; i < len1; ++i) {
			UInt8 val1 = bytes1[i];
			(void)val1;
			//printf("Byte\t%li removed: %02hhX ->   \n", i, val1);
		}
	}
	
	printf("%s\n\n", [[diffs description] UTF8String]);
}

- (void)compareEventData:(NSArray*)eventLog {
	CFDataRef prevData = NULL;
	CGEventRef prevE = NULL;
	for (NSDictionary* eventInfo in eventLog) {
		if ([[eventInfo objectForKey:@"tap"] isEqualToString:@"HID"]) {
			CFDataRef eventData = (CFDataRef)[eventInfo objectForKey:@"event"];
			if (0 && prevData) {
				printf("\n");
				[self compareData:prevData toData:eventData];
			}
			
			CGEventRef e = CGEventCreateFromData(kCFAllocatorDefault, eventData);
			
			NSMutableIndexSet* fieldSet = [NSMutableIndexSet indexSet];
			if (prevE) for (int field = 0; field < 256; ++field) {
				double val = CGEventGetDoubleValueField(e, field);
				double prevVal = CGEventGetDoubleValueField(prevE, field);
				//int64_t val = CGEventGetIntegerValueField(e, field);
				//int64_t prevVal = CGEventGetIntegerValueField(prevE, field);
				if (prevVal != val && field != 58) {
					//printf("%i: %llu -> %llu\n", field, prevVal, val);
					printf("%i: %f -> %f\n", field, prevVal, val);
					[fieldSet addIndex:field];
				}
			}
			if ([fieldSet count]) {
				printf("**** %s\n", [[fieldSet description] UTF8String]);
			}
			
			NSEvent* event = [NSEvent eventWithCGEvent:e];
			printf("CG->%s ", [[event description] UTF8String]);
			NSSet* t = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];
			printf(" %s\n\n", [[t description] UTF8String]);
			
			if (prevE) CFRelease(prevE);
			prevE = e;
			prevData = eventData;
		}
	}
	if (prevE) CFRelease(prevE);
}

- (void)diffChange {
	CGEventRef e1 = CGEventCreate(NULL);
	CGEventRef e2 = CGEventCreate(NULL);
	CGEventSetType(e2, 29);
	CGEventSetIntegerValueField(e2, 0x6F, 0x12345678);
	
	CFDataRef d1 = CGEventCreateData(kCFAllocatorDefault, e1);
	CFDataRef d2 = CGEventCreateData(kCFAllocatorDefault, e2);
	//printf("%li - %li\n", CFDataGetLength(d1), CFDataGetLength(d2));
	[self compareData:d1 toData:d2];
	
	CFRelease(d1), CFRelease(d2);
	CFRelease(e1), CFRelease(e2);
}



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	//NSURL* logFile = [NSURL URLWithString:@"file://localhost/Users/nathan/Library/Mail%20Downloads/MagicMouse.xml"];
	//NSURL* logFile = [NSURL URLWithString:@"file://localhost/Users/nathan/Library/Mail%20Downloads/MacBookPro.xml"];
	//NSURL* logFile = [NSURL fileURLWithPath:@"/Volumes/Calf Trail Development/Touch/Touch Data/MacBookPro cleaned.xml"];
	//NSURL* logFile = [NSURL fileURLWithPath:@"/Volumes/Calf Trail Development/Touch/Touch Data/Alissa events cleaned.xml"];
	NSURL* logFile = [NSURL fileURLWithPath:@"/Users/natevw/Desktop/TouchesDebugLog.xml"];
	
	NSArray* eventLog = [NSArray arrayWithContentsOfURL:logFile];
	NSAssert([eventLog count], @"No events from logFile");
	//[self dumpEvents:eventLog];
	//[self inspectEvents:eventLog];
	//[self rebuildEvents:eventLog];
	//[self replayEvents:eventLog];
	//[self filterEvents:eventLog];
	//[self decodeEvents:eventLog];
	//[self compareEventData:eventLog];
	//[self filterEvents2:eventLog];
	[self dumpEvents2:eventLog];
	//[self diffChange];
	//[self filterEvents3:eventLog];
	(void)eventLog;
	NSLog(@"Done");
	[NSApp terminate:nil];
}

@end
