/*
 *  MultitouchSupport.h
 *  TouchSynthesis
 *
 *  Created by Nathan Vander Wilt on 1/13/10.
 *  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
 *
 */

typedef struct {
	float x;
	float y;
} MTPoint;

typedef struct {
	MTPoint position;
	MTPoint velocity;
} MTVector;

enum {
	MTTouchStateNotTracking = 0,
	MTTouchStateStartInRange = 1,
	MTTouchStateHoverInRange = 2,
	MTTouchStateMakeTouch = 3,
	MTTouchStateTouching = 4,
	MTTouchStateBreakTouch = 5,
	MTTouchStateLingerInRange = 6,
	MTTouchStateOutOfRange = 7
};
typedef uint32_t MTTouchState;

typedef struct {
	int32_t frame;
	double timestamp;
	int32_t pathIndex;	// "P" (~transducerIndex)
	MTTouchState state;
	int32_t fingerID;	// "F" (~identity)
	int32_t handID;		// "H" (always 1)
	MTVector normalizedVector;
	float zTotal;		// "ZTot" (~quality, multiple of 1/8 between 0 and 1)
	int32_t field9;		// always 0
	float angle;
	float majorAxis;
	float minorAxis;
	MTVector absoluteVector;	// "mm"
	int32_t field14;	// always 0
	int32_t field15;	// always 0
	float zDensity;		// "ZDen" (~density)
} MTTouch;

typedef void* MTDeviceRef;

double MTAbsoluteTimeGetCurrent();
bool MTDeviceIsAvailable();		// true if can create default device

CFArrayRef MTDeviceCreateList();		// creates for driver types 0, 1, 4, 2, 3
MTDeviceRef MTDeviceCreateDefault();
MTDeviceRef MTDeviceCreateFromDeviceID(int64_t);
MTDeviceRef MTDeviceCreateFromService(io_service_t);
MTDeviceRef MTDeviceCreateFromGUID(uuid_t);		// GUID's compared by pointer, not value!
void MTDeviceRelease(MTDeviceRef);

CFRunLoopSourceRef MTDeviceCreateMultitouchRunLoopSource(MTDeviceRef);
OSStatus MTDeviceScheduleOnRunLoop(MTDeviceRef, CFRunLoopRef, CFStringRef);

OSStatus MTDeviceStart(MTDeviceRef, int);
OSStatus MTDeviceStop(MTDeviceRef);
bool MTDeviceIsRunning(MTDeviceRef);


bool MTDeviceIsValid(MTDeviceRef);
bool MTDeviceIsBuiltIn(MTDeviceRef) __attribute__ ((weak_import));	// no 10.5
bool MTDeviceIsOpaqueSurface(MTDeviceRef);
io_service_t MTDeviceGetService(MTDeviceRef);
OSStatus MTDeviceGetSensorSurfaceDimensions(MTDeviceRef, int*, int*);
OSStatus MTDeviceGetFamilyID(MTDeviceRef, int*);
OSStatus MTDeviceGetDeviceID(MTDeviceRef, uint64_t*) __attribute__ ((weak_import));	// no 10.5
OSStatus MTDeviceGetDriverType(MTDeviceRef, int*);
OSStatus MTDeviceGetActualType(MTDeviceRef, int*);
OSStatus MTDeviceGetGUID(MTDeviceRef, uuid_t*);

typedef void (*MTFrameCallbackFunction)(MTDeviceRef device,
										MTTouch touches[], size_t numTouches,
										double timestamp, size_t frame);
void MTRegisterContactFrameCallback(MTDeviceRef, MTFrameCallbackFunction);

typedef void (*MTPathCallbackFunction)(MTDeviceRef device, long pathID, long state, MTTouch* touch);
MTPathCallbackFunction MTPathPrintCallback;
void MTRegisterPathCallback(MTDeviceRef, MTPathCallbackFunction);

/*
 // callbacks never called (need different flags?)
typedef void (*MTImageCallbackFunction)(MTDeviceRef, void*, void*);
MTImageCallbackFunction MTImagePrintCallback;
void MTRegisterMultitouchImageCallback(MTDeviceRef, MTImageCallbackFunction);
 */

/*
 // these log error
void MTVibratorRunForDuration(MTDeviceRef,long);
void MTVibratorStop(MTDeviceRef);
*/
