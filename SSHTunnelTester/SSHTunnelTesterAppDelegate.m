//
//  SSHTunnelTesterAppDelegate.m
//  SSHTunnelTester
//
//  Created by Joseph Roback on 9/5/11.
//  Copyright 2011 Nawsoft. All rights reserved.
//

#import <SSHTunnel/SSHTunnel.h>
#import "SSHTunnelTesterAppDelegate.h"

@implementation SSHTunnelTesterAppDelegate

@synthesize window;
@synthesize hostname;
@synthesize port;
@synthesize username;
@synthesize password;
@synthesize forwardX11;
@synthesize forwardTrustedX11;

-(void)dealloc
{
	[sshTunnel release];
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSLog(@"applicationDidFinishLaunching");
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSLog(@"applicationWillTerminate");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[sshTunnel terminate];
	[sshTunnel waitUntilExit];
}

- (IBAction)launch:(id)sender
{
	NSLog(@"launch");
	
	if (sshTunnel)
	{
		NSLog(@"sshTunnel already launched");
		return;
	}
	
	// create new tunnel
	sshTunnel = [[SSHTunnel alloc] initWithHostname:[hostname stringValue]
						   port:[port integerValue]
					       username:[username stringValue]
					       password:[password stringValue]];
	
	// set tunnel options
	[sshTunnel setConnectTimeout:15U];
	
	[sshTunnel addLocalForwardWithBindAddress:nil
					 bindPort:60000U
					     host:@"localhost"
					 hostPort:5901U];
	
	[sshTunnel addRemoteForwardWithBindAddress:nil
					  bindPort:60000U
					      host:@"localhost"
					  hostPort:25U];
	
	[sshTunnel addRemoteForwardWithBindAddress:@"*"
					  bindPort:60001U
					      host:@"localhost"
					  hostPort:25U];
	
	[sshTunnel addDynamicForwardWithBindAddress:@"localhost"
					   bindPort:1080U];
	
	[sshTunnel addDynamicForwardWithBindAddress:@"*"
					   bindPort:1081U];
	[sshTunnel addDynamicForwardWithBindAddress:nil
					   bindPort:1082U];
	
	// register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(sshDidTerminate:)
	 
						     name:SSHTunnelDidTerminateNotification
						   object:sshTunnel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(sshDidConnect:)
						     name:SSHTunnelDidConnectNotification
						   object:sshTunnel];
	
	//
	// launch tunnel
	//
	
	@try
	{
		[sshTunnel launch];
	}
	@catch (NSException *e)
	{
		NSLog(@"launch: %@", [e reason]);
		[sshTunnel release];
		sshTunnel = nil;
	}
}

- (IBAction)terminate:(id)sender
{
	NSLog(@"terminate");
	
	// terminate tunnel
	@try
	{
		[sshTunnel terminate];
	}
	@catch (NSException *e)
	{
		NSLog(@"terminate: %@", [e reason]);
		[sshTunnel release];
		sshTunnel = nil;
	}
}

#pragma mark SSHTunnel Notifications

- (void)sshDidConnect:(NSNotification *)aNotification
{
	NSLog(@"ssh tunnel (%@) connected", sshTunnel);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:SSHTunnelDidConnectNotification
						      object:sshTunnel];
}

- (void)sshDidTerminate:(NSNotification *)aNotification
{
	NSLog(@"ssh tunnel (%@) terminated", sshTunnel);
	NSLog(@"  REASON: %ld", [sshTunnel terminationReason]);
	NSLog(@"  REASON: %ld", [sshTunnel terminationReason]);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:SSHTunnelDidTerminateNotification
						      object:sshTunnel];
	
	[sshTunnel release];
	sshTunnel = nil;
}
@end
