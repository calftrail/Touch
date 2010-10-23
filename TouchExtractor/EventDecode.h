/*
 *  EventDecode.h
 *  TouchExtractor
 *
 *  Created by Nathan Vander Wilt on 11/25/09.
 *  Copyright 2009 Calf Trail Software, LLC. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>

typedef struct {
    float _field1;
    int _field2[13];
} float_field1;

typedef struct {
    unsigned int _field1;
    int _field2[13];
} uint_field1;


typedef union {
	struct {
		unsigned char subx;
		unsigned char suby;
		short eventNum;
		int click;
		unsigned char pressure;
		char buttonNumber;	// NXEventData has this as UInt8
		unsigned char subType;
		unsigned char reserved2;
		short reserved3a;	// NXEventData has these as one SInt32
		short reserved3b;
		union {
			NXTabletPointData point;
			NXTabletProximityData proximity;
		} tablet;
		unsigned int :1;	// NXEventData does not have these 4 SInt32s
		unsigned int :31;
		unsigned int _field12;
		unsigned int _field13;
		unsigned int _field14;
	} mouse, field2;
	struct {
		unsigned short origCharSet;
		short repeat;
		unsigned short charSet;
		unsigned short charCode;
		unsigned short keyCode;
		short origCharCode;			// NX has this as UInt16
		short reserved1a;			// NX has these as SInt32 reserved1
		char reserved1b;
		unsigned char reserved1c;
		unsigned int keyboardType;
		unsigned int reserved2;		// NX has this as SInt32
		unsigned short reserved3_4_5[20];	// NX has only 6 SInt32 fields here
	} key;
	struct {
		short reserved;
		short eventNum;
		int trackingNum;
		int userData;
		unsigned int reserved1;		// NXEventData has as SInt32
		long long reserved2_3;		// NXEventData has as 2 SInt32
		long long reserved4_5;		// NXEventData has as 2 SInt32
		int reserved6[8];			// NXEventData has only 4 SInt32 fields here
	} tracking;
	struct {
		unsigned short _field1;
		unsigned short _field2;
		unsigned int _field3;
		unsigned int _field4;
		int _field5;
		int _field6;
		int _field7;
		int _field8;
		int _field9;
		int _field10;
		int _field11;
		int _field12;
		int _field13[5];
	} _field5;
	struct {
		short deltaAxis1;
		short deltaAxis2;
		short deltaAxis3;
		short reserved1;
		int fixedDeltaAxis1;
		int fixedDeltaAxis2;
		int fixedDeltaAxis3;
		int pointDeltaAxis1;
		int pointDeltaAxis2;
		int pointDeltaAxis3;	
		int reserved8a[2];
		int reserved8b;
		unsigned int reserved8c;
		unsigned int :1;	// NXEventData does not have these 4 SInt32s
		unsigned int :1;
		unsigned int :30;
		unsigned int _field14;
		unsigned int _field15;
		int _field16[1];
	} scrollWheel, zoom;
	NXTabletPointData tablet;
	NXTabletProximityData proximity;
	struct {
		short reserved;
		short subType;
		union {
			float F[15];
			int L[15];
			short S[30];
			char C[60];
		} misc;		// NSEventData has this 4 SInt32s shorter
	} compound;
	struct {
		short reserved;
		short eventNum;
		unsigned int trackingNum;		// NXEventData has this as SInt32
		unsigned long long userData;	// NXEventData has this as SInt32
		unsigned short reserved2a;		// NXEventData has this as SInt32
		short reserved2b;
		int reserved3_4_5_6[11];		// NXEventData is 4 SInt32s shorter
	} tracking2;
	struct {
		unsigned int _field1;
		unsigned char _field2;
		unsigned char _field3;
		unsigned char _field4[2];
		union {
			float_field1 _field1;
			float_field1 _field2;
			struct {
				float _field1;
				float _field2;
				float _field3;
				int _field4[11];
			} _field3;
			uint_field1 _field4;
			float_field1 _field5;
			uint_field1 _field6;
		} _field5;
	} _field12;
} CGSEventData;		// this is ~ NXEventData + 4 SInt32s

struct _CGSEventRecord {
    unsigned short _field1;		// may correspond to CGEvent field 53
    unsigned short _field2;
    unsigned int _field3;		// may correspond to CGEvent field 50
    unsigned int type;
    struct CGPoint location;
    struct CGPoint _field6;
    unsigned long long timestamp;
    unsigned int flags;		// CGEvent field 59
    unsigned int _field9;
    unsigned int _field10;
    struct _CGEventSourceData {
        int pid;
        unsigned int uid;
        unsigned int gid;
        unsigned int _field4;
        unsigned long long _field5;
        unsigned int _field6;
        unsigned short _field7;
        unsigned char _field8;
        unsigned char _field9;
        unsigned long long _field10;
    } source;
    struct _CGEventProcess {
		int _field1;
		unsigned int _field2;
		unsigned int _field3;
		unsigned int _field4;
		unsigned int _field5;
	} process;
    CGSEventData data;
    void *_field14;
    unsigned int _field15[4];
    unsigned short _field16;
    unsigned short _field17;
    unsigned short *_field18;		// keyboard text?
};
