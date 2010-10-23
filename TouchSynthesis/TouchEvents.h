/*
 *  TouchEvents.h
 *  TouchSynthesis
 *
 *  Created by Nathan Vander Wilt on 1/13/10.
 *  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
 *
 */

#include <ApplicationServices/ApplicationServices.h>


/* these for info */

const CFStringRef kTLInfoKeyDeviceID;	// required for touches
const CFStringRef kTLInfoKeyTimestamp;
const CFStringRef kTLInfoKeyGestureSubtype;
const CFStringRef kTLInfoKeyMagnification;
const CFStringRef kTLInfoKeyRotation;	// degrees
const CFStringRef kTLInfoKeySwipeDirection;
const CFStringRef kTLInfoKeyNextSubtype;

enum {
	kTLInfoSubtypeRotate = 0x05,
	kTLInfoSubtypeSub6,	// may be panning/scrolling
	kTLInfoSubtypeMagnify = 0x08,
	kTLInfoSubtypeGesture = 0x0B,
	kTLInfoSubtypeSwipe = 0x10,
	kTLInfoSubtypeBeginGesture = 0x3D,
	kTLInfoSubtypeEndGesture
};
typedef uint32_t TLInfoSubtype;

enum {
    kTLInfoSwipeUp = 1,
    kTLInfoSwipeDown = 2,
    kTLInfoSwipeLeft = 4,
    kTLInfoSwipeRight = 8
};
typedef uint32_t TLInfoSwipeDirection;


/* these for touches */

const CFStringRef kTLEventKeyType;
const CFStringRef kTLEventKeyTimestamp;
const CFStringRef kTLEventKeyOptions;

const CFStringRef kTLEventKeyPositionX;
const CFStringRef kTLEventKeyPositionY;
const CFStringRef kTLEventKeyPositionZ;

const CFStringRef kTLEventKeyTransducerIndex;
const CFStringRef kTLEventKeyTransducerType;
const CFStringRef kTLEventKeyIdentity;
const CFStringRef kTLEventKeyEventMask;

const CFStringRef kTLEventKeyButtonMask;
const CFStringRef kTLEventKeyTipPressure;
const CFStringRef kTLEventKeyBarrelPressure;
const CFStringRef kTLEventKeyTwist;

const CFStringRef kTLEventKeyQuality;
const CFStringRef kTLEventKeyDensity;
const CFStringRef kTLEventKeyIrregularity;
const CFStringRef kTLEventKeyMajorRadius;
const CFStringRef kTLEventKeyMinorRadius;


CGEventRef tl_CGEventCreateFromGesture(CFDictionaryRef info, CFArrayRef touches);
