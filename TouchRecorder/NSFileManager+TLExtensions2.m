//
//  NSFileManager+TLExtensions2.m
//  TouchRecorder
//
//  Created by Nathan Vander Wilt on 1/23/10.
//  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
//

#import "NSFileManager+TLExtensions2.h"


@implementation NSFileManager (TLExtensions2)

- (BOOL)tl_compressContentsOfURL:(NSURL*)pathURL
					   asArchive:(NSURL*)archiveURL
						   error:(NSError**)err
{
	NSParameterAssert(pathURL != nil);
	NSParameterAssert(archiveURL != nil);
	
	NSString* source = [pathURL path];
	NSString* destination = [archiveURL path];
	BOOL sourceExists = [[NSFileManager defaultManager] fileExistsAtPath:source];
	if (!sourceExists) {
		if (err) {
			NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:source forKey:NSFilePathErrorKey];
			*err = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:errorInfo];
		}
		return NO;
	}
	BOOL destinationExists = [[NSFileManager defaultManager] fileExistsAtPath:destination];
	if (0 && destinationExists) {
		if (err) {
			NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:source forKey:NSFilePathErrorKey];
			*err = [NSError errorWithDomain:NSPOSIXErrorDomain code:EEXIST userInfo:errorInfo];
		}
		return NO;
	}
	
	// http://twitter.com/ccgus/statuses/963137508
	NSMutableArray* dittoArgs = [NSMutableArray arrayWithObjects:@"-c", @"-k",
								 @"--sequesterRsrc", source, destination, nil];
	NSTask* zipTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/ditto" arguments:dittoArgs];
	//NSTask* zipTask = [NSTask launchedTaskWithLaunchPath:@"/bin/echo" arguments:dittoArgs];
	[zipTask waitUntilExit];
	int zipError = [zipTask terminationStatus];
	if (zipError) {
		(void)[[NSFileManager defaultManager] removeItemAtPath:destination error:NULL];
		if (err) {
			*err = [NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:nil];
		}
		return NO;
	}
	return YES;
}

@end
