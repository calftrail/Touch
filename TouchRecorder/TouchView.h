//
//  TouchView.h
//  TouchRecorder
//
//  Created by Nathan Vander Wilt on 11/24/09.
//  Copyright 2009 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TouchView : NSView {
@private
	NSSet* activeTouches;
}

@property (retain) NSSet* activeTouches;

@end
