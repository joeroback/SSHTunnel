//
// Copyright (c) 2011, Joseph A. Roback
// All rights reserved.
//
//  SSHTunnelTesterAppDelegate.h
//  SSHTunnelTester
//
//  Created by Joseph Roback on 9/5/11.
//

#import <Cocoa/Cocoa.h>

@class SSHTunnel;

@interface SSHTunnelTesterAppDelegate : NSObject <NSApplicationDelegate>
{
	NSWindow *window;
	NSTextField *hostname;
	NSTextField *port;
	NSTextField *username;
	NSSecureTextField *password;
	NSButton *forwardX11;
	NSButton *forwardTrustedX11;
	
	SSHTunnel *sshTunnel;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *hostname;
@property (assign) IBOutlet NSTextField *port;
@property (assign) IBOutlet NSTextField *username;
@property (assign) IBOutlet NSSecureTextField *password;
@property (assign) IBOutlet NSButton *forwardX11;
@property (assign) IBOutlet NSButton *forwardTrustedX11;

- (IBAction)launch:(id)sender;
- (IBAction)terminate:(id)sender;
@end
