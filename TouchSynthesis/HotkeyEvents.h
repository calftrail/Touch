/*
 *  HotkeyEvents.h
 *  TouchSynthesis
 *
 *  Created by Nathan Vander Wilt on 3/6/10.
 *  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
 *
 */


#include <CoreFoundation/CoreFoundation.h>

const CFStringRef kTLEventActionSpaces;
const CFStringRef kTLEventActionDashboard;

const CFStringRef kTLEventActionExposeAll;
const CFStringRef kTLEventActionExposeApplication;
const CFStringRef kTLEventActionExposeDesktop;

CFArrayRef tl_CGEventSequenceCreateForAction(CFStringRef action);
