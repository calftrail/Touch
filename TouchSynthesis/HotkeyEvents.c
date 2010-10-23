/*
 *  HotkeyEvents.c
 *  TouchSynthesis
 *
 *  Created by Nathan Vander Wilt on 3/6/10.
 *  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
 *
 */

#include "HotkeyEvents.h"

#include <Carbon/Carbon.h>


// see http://www.macosxhints.com/article.php?story=20050801052917667

const CFStringRef kTLEventActionSpaces = CFSTR("75");		// shift: 76
const CFStringRef kTLEventActionDashboard = CFSTR("62");	// shift: 63

const CFStringRef kTLEventActionExposeAll = CFSTR("32");			// shift: 34
const CFStringRef kTLEventActionExposeApplication = CFSTR("33");	// shift: 35
const CFStringRef kTLEventActionExposeDesktop = CFSTR("36");		// shift: 37


static void tl_CGEventSequenceAppendModifiers(CFMutableArrayRef sequence, long modifiers, bool keyStatus) {
	if (modifiers & kCGEventFlagMaskShift) {
		CGEventRef e = CGEventCreateKeyboardEvent(NULL, kVK_Shift, keyStatus);
		CFArrayAppendValue(sequence, e);
		CFRelease(e);
	}
	if (modifiers & kCGEventFlagMaskControl) {
		CGEventRef e = CGEventCreateKeyboardEvent(NULL, kVK_Control, keyStatus);
		CFArrayAppendValue(sequence, e);
		CFRelease(e);
	}
	if (modifiers & kCGEventFlagMaskAlternate) {
		CGEventRef e = CGEventCreateKeyboardEvent(NULL, kVK_Option, keyStatus);
		CFArrayAppendValue(sequence, e);
		CFRelease(e);
	}
	if (modifiers & kCGEventFlagMaskCommand) {
		CGEventRef e = CGEventCreateKeyboardEvent(NULL, kVK_Command, keyStatus);
		CFArrayAppendValue(sequence, e);
		CFRelease(e);
	}
}

static void tl_CGEventSequenceAppendKeypress(CFMutableArrayRef sequence, CGKeyCode keycode) {
	CGEventRef e1 = CGEventCreateKeyboardEvent(NULL, keycode, true);
	CFArrayAppendValue(sequence, e1);
	CFRelease(e1);
	CGEventRef e2 = CGEventCreateKeyboardEvent(NULL, keycode, false);
	CFArrayAppendValue(sequence, e2);
	CFRelease(e2);
}

static bool tl_CGEventSequenceGetParametersForAction(CFStringRef action,
													 CGKeyCode* primaryKeyCodePtr,
													 long* modifiersPtr)
{
	assert(primaryKeyCodePtr != NULL);
	assert(modifiersPtr != NULL);
	CFDictionaryRef allHotKeys = CFPreferencesCopyAppValue(CFSTR("AppleSymbolicHotKeys"),
														   CFSTR("com.apple.symbolichotkeys"));
	if (!allHotKeys) return false;
	
	CFDictionaryRef hotKey = CFDictionaryGetValue(allHotKeys, action);
	if (!hotKey) {
		CFRelease(allHotKeys);
		return false;
	}
	
	CFDictionaryRef hotKeyValue = CFDictionaryGetValue(hotKey, CFSTR("value"));
	CFArrayRef parameters = CFDictionaryGetValue(hotKeyValue, CFSTR("parameters"));
	CFNumberRef primaryKeyCodeVal = CFArrayGetValueAtIndex(parameters, 1);
	CFNumberGetValue(primaryKeyCodeVal, kCFNumberSInt16Type, primaryKeyCodePtr);
	CFNumberRef modifiersVal = CFArrayGetValueAtIndex(parameters, 2);
	CFNumberGetValue(modifiersVal, kCFNumberLongType, modifiersPtr);
	CFRelease(allHotKeys);
	return true;
}

CFArrayRef tl_CGEventSequenceCreateForAction(CFStringRef action) {
	CGKeyCode primaryKeyCode;
	long modifiers;
	bool success = tl_CGEventSequenceGetParametersForAction(action, &primaryKeyCode, &modifiers);
	if (!success) return NULL;
	
	CFMutableArrayRef sequence = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	tl_CGEventSequenceAppendModifiers(sequence, modifiers, true);
	tl_CGEventSequenceAppendKeypress(sequence, primaryKeyCode);
	tl_CGEventSequenceAppendModifiers(sequence, modifiers, false);
	return sequence;
}
