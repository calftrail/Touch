//
//  NSFileManager+TLExtensions2.h
//  TouchRecorder
//
//  Created by Nathan Vander Wilt on 1/23/10.
//  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// TODO: NSWorkspace instead? see non-working compress file operation

@interface NSFileManager (TLExtensions2)

- (BOOL)tl_compressContentsOfURL:(NSURL*)pathURL
					   asArchive:(NSURL*)archiveURL
						   error:(NSError**)err;

@end
