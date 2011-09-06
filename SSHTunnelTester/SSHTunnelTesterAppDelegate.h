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
	NSMatrix *protocol;
	NSButton *allocatePseudoTTY;
	NSButton *gatewayPorts;
	NSButton *allowsPasswordAuthentication;
	NSButton *allowsPublicKeyAuthentication;
	NSButton *forceIPv4;
	NSButton *forceIPv6;
	NSButton *forceProtocolv1;
	NSButton *forceProtocolv2;
	NSButton *forwardX11;
	NSButton *forwardTrustedX11;
	
	SSHTunnel *sshTunnel;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *hostname;
@property (assign) IBOutlet NSTextField *port;
@property (assign) IBOutlet NSTextField *username;
@property (assign) IBOutlet NSSecureTextField *password;
@property (assign) IBOutlet NSMatrix *protocol;
@property (assign) IBOutlet NSButton *allocatePseudoTTY;
@property (assign) IBOutlet NSButton *gatewayPorts;
@property (assign) IBOutlet NSButton *allowsPasswordAuthentication;
@property (assign) IBOutlet NSButton *allowsPublicKeyAuthentication;
@property (assign) IBOutlet NSButton *forceIPv4;
@property (assign) IBOutlet NSButton *forceIPv6;
@property (assign) IBOutlet NSButton *forceProtocolv1;
@property (assign) IBOutlet NSButton *forceProtocolv2;
@property (assign) IBOutlet NSButton *forwardX11;
@property (assign) IBOutlet NSButton *forwardTrustedX11;

- (IBAction)launch:(id)sender;
- (IBAction)terminate:(id)sender;
@end
