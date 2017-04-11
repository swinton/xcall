//
//  AppDelegate.m
//  xcall
//
//  Created by Martin Finke on 03.04.17.
//  Copyright © 2017 Martin Finke. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property(nonatomic) int exitCode;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Register to URL events
	[NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLAppleEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
	
	// Get URL from args
	NSString *urlString = [NSUserDefaults.standardUserDefaults stringForKey: @"url"];
	if (!urlString) {
		self.exitCode = 1;
		[NSApp terminate: self];
	}
	
	NSURL *url = [NSURL URLWithString: urlString];
	if (!url) {
		self.exitCode = 1;
		[NSApp terminate: self];
	}
	
	// Call URL
	[self executeXCallbackURL: url];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	// Unregister from URL events
	[NSAppleEventManager.sharedAppleEventManager removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];
	
	// Call exit() manually, to have custom exit code
	exit(self.exitCode);
}

- (void)handleURLAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	// Get URL from event
	NSURL *url = [NSURL URLWithString: [[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
	if (!url)
		return;
	
	// Get action name
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
	NSString *actionName = components.path.lastPathComponent;
	
	
	// Convert URL response parameters to JSON, set exit code
	NSString *target;
	NSString *output;
	if ([actionName isEqual: @"handle-success"]) {
		self.exitCode = 0;
		target = @"/dev/stdout";
		output = [self.class jsonStringFromQueryItems: components.queryItems];
	}
	else if ([actionName isEqual: @"handle-error"]) {
		self.exitCode = 1;
		target = @"/dev/stderr";
		output = [self.class jsonStringFromQueryItems: components.queryItems];
	}
	else {
		self.exitCode = 1;
		target = @"/dev/stderr";
		output = @"{\"internal_error\": \"Invalid callback URL format.\"}";
	}
	
	// Add newline, to have shell prompt on a new line
	output = [output stringByAppendingString: @"\n"];
	
	// Write to stdout/stderr
	BOOL success = [output writeToFile:target atomically:NO encoding:NSUTF8StringEncoding error:NULL];
	NSAssert(success, @"Error writing to %@.", target);
	
	// Quit
	[NSApp terminate: self];
}

- (void)executeXCallbackURL:(NSURL *)url
{
	// Get URL components
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
	components.queryItems = components.queryItems ?: @[];
	
	// Add source callback URL parameters
	components.queryItems = [components.queryItems arrayByAddingObjectsFromArray: self.class.sourceCallbacks];
	
	// Always use silent mode
	components.queryItems = [components.queryItems arrayByAddingObject: [NSURLQueryItem queryItemWithName:@"silent-mode" value:@"YES"]];
	
	// Open URL without activating target app
	[NSWorkspace.sharedWorkspace openURL:components.URL options:NSWorkspaceLaunchWithoutActivation configuration:@{} error:NULL];
}

+ (NSArray<NSURLQueryItem *> *)sourceCallbacks
{
	return @[[NSURLQueryItem queryItemWithName:@"x-success" value:@"xcall066958CA://x-callback-url/handle-success"],
			 [NSURLQueryItem queryItemWithName:@"x-error" value:@"xcall066958CA://x-callback-url/handle-error"]];
}

+ (NSString *)jsonStringFromQueryItems:(NSArray<NSURLQueryItem *> *)queryItems
{
	NSMutableDictionary *items = [NSMutableDictionary new];

	// Convert each query item to a key/value pair
	for (NSURLQueryItem *queryItem in queryItems)
		items[queryItem.name] = queryItem.value ?: NSNull.null;
	
	// Convert to JSON string
	NSData *data = [NSJSONSerialization dataWithJSONObject:items options:NSJSONWritingPrettyPrinted error:NULL];
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
