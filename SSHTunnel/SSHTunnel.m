//
// Copyright (c) 2009-2011, Joseph A. Roback
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name of the Joseph A. Roback nor the names of its contributors
//   may be used to endorse or promote products derived from this software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
//  SSHTunnel.m
//  SSHTunnel
//
//  Created by Joseph Roback on 12/11/09.
//

#import "SSHTunnel.h"
#import "SSHTunnelDebug.h"

#import <stdlib.h>
#import <time.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <netinet/in.h>


NSUInteger STDebugLevel = 0U;

NSString * const SSHTunnelDidConnectNotification = @"SSHTunnelDidConnectNotification";
NSString * const SSHTunnelDidTerminateNotification = @"SSHTunnelDidTerminateNotification";

NSString * const SSHTunnelNotificationForwardTunnelsItem = @"SSHTunnelNotificationForwardTunnelsItem";
NSString * const SSHTunnelNotificationReverseTunnelsItem = @"SSHTunnelNotificationReverseTunnelsItem";

NSString * const kSSHTunnelForwardBindAddress = @"kSSHTunnelForwardBindAddress";
NSString * const kSSHTunnelForwardBindPort = @"kSSHTunnelForwardBindPort";
NSString * const kSSHTunnelForwardHost = @"kSSHTunnelForwardHost";
NSString * const kSSHTunnelForwardHostPort = @"kSSHTunnelForwardHostPort";

static NSString *SSHTunnelNamedPipeFormat = @"/tmp/sshtunnel-%@-%08x";

@interface SSHTunnel ()
- (void)_addForward:(NSMutableArray *)forwards
        bindAddress:(NSString *)bindAddress
           bindPort:(NSUInteger)bindPort
               host:(NSString *)host
           hostPort:(NSUInteger)hostPort;
- (void)_cleanupNamedPipe;
- (void)_setupNamedPipe;
- (void)_processSSHOutput:(NSData *)data;
- (void)_namedPipeThread:(id)anObject;
@end

@implementation SSHTunnel

@synthesize sshLaunchPath=_sshLaunchPath;
@synthesize hostname=_hostname;
@synthesize port=_port;
@synthesize username=_username;
@synthesize password=_password;
@synthesize allocatesPseudoTTY=_allocatesPseudoTTY;
@synthesize allowsPasswordAuthentication=_allowsPasswordAuthentication;
@synthesize allowsPublicKeyAuthentication=_allowsPublicKeyAuthentication;
@synthesize connectTimeout=_connectTimeout;
@synthesize forceIPv4=_forceIPv4;
@synthesize forceIPv6=_forceIPv6;
@synthesize forceProtocol1=_forceProtocol1;
@synthesize forceProtocol2=_forceProtocol2;
@synthesize gatewayPorts=_gatewayPorts;
@synthesize identityFile=_identityFile;
@synthesize X11Forwarding=_X11Forwarding;
@synthesize X11TrustedForwarding=_X11TrustedForwarding;

@synthesize localForwards=_localForwards;
@synthesize remoteForwards=_remoteForwards;
@synthesize dynamicForwards=_dynamicForwards;

@synthesize connected=_connected;
@synthesize terminationReason=_terminationReason;

+ (void)initialize
{
#ifndef NDEBUG
	char *dbgenv;
	
	if ((dbgenv = getenv("STDEBUGLEVEL")) != NULL)
	{
		STDebugLevel = (NSUInteger) strtoul(dbgenv, NULL, 16);
	}
#endif
	
	// seed random
	srandomdev();
}

+ (SSHTunnel *)sshTunnelWithHostname:(NSString *)hostname
                                port:(NSUInteger)port
                            username:(NSString *)username
                            password:(NSString *)password
{
	return [[[SSHTunnel alloc] initWithHostname:hostname
                                           port:port
                                       username:username
                                       password:password] autorelease];
}

+ (int)localPort
{
    int localPort = 9001;
    int tempSocket;
    struct sockaddr_in tempSocketAddress;
    size_t addressLength = sizeof(tempSocketAddress);
    if((tempSocket = socket(AF_INET, SOCK_STREAM, 0)) > 0) {
        memset(&tempSocketAddress, 0, sizeof(tempSocketAddress));
        tempSocketAddress.sin_family = AF_INET;
        tempSocketAddress.sin_addr.s_addr = htonl(INADDR_ANY);
        tempSocketAddress.sin_port = 0;
        if (bind(tempSocket, (struct sockaddr *)&tempSocketAddress, (socklen_t)addressLength) >= 0) {
            if (getsockname(tempSocket, (struct sockaddr *)&tempSocketAddress, (uint32_t *)&addressLength) >= 0) {
                localPort = ntohs(tempSocketAddress.sin_port);
            }
        }
        close(tempSocket);
    }
    
    return localPort;
}

- (id)init
{
	if (self = [super init])
	{
		self.sshLaunchPath = @"/usr/bin/ssh";
		self.allocatesPseudoTTY = NO;
		self.allowsPasswordAuthentication = YES;
		self.allowsPublicKeyAuthentication = YES;
		self.connectTimeout = 60U;
		self.forceIPv4 = NO;
		self.forceIPv6 = NO;
		self.forceProtocol1 = NO;
		self.forceProtocol2 = NO;
		self.gatewayPorts = NO;
		self.identityFile = nil;
		self.X11Forwarding = NO;
		self.X11TrustedForwarding = NO;
		_localForwards = [[NSMutableArray alloc] initWithCapacity:0U];
		_remoteForwards = [[NSMutableArray alloc] initWithCapacity:0U];
		_dynamicForwards = [[NSMutableArray alloc] initWithCapacity:0U];
		_namedPipeHandle = nil;
		_namedPipe = nil;
		_sshTask = nil;
		_sshErrHandle = nil;
		_launched = NO;
		_connected = NO;
		_terminationReason = SSHTunnelTerminationReasonExit;
	}
	return self;
}

- (id)initWithHostname:(NSString *)hostname
                  port:(NSUInteger)port
              username:(NSString *)username
              password:(NSString *)password;
{
	if (self = [self init])
	{
		self.hostname = hostname;
		self.port = port;
		self.username = username;
		self.password = password;
	}
	return self;
}

- (void)dealloc
{
	// get out of the notification center
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// cleanup named pipe file
	[self _cleanupNamedPipe];
	
	// close and release SSH output
	[_sshErrHandle closeFile];
	[_sshErrHandle release];
	_sshErrHandle = nil;
	
	// terminate ssh
	if ([_sshTask isRunning])
	{
		[_sshTask terminate];
		[_sshTask release];
		_sshTask = nil;
	}
	
	// free properties by nil assignment
	self.sshLaunchPath = nil;
	self.hostname = nil;
	self.username = nil;
	self.password = nil;
	self.identityFile = nil;
	
	// tunnels array
	[_localForwards release];
	_localForwards = nil;
	
	// reverse tunnels
	[_remoteForwards release];
	_remoteForwards = nil;
	
	// dynamic forwards (SOCKS proxy)
	[_dynamicForwards release];
	_dynamicForwards = nil;
	
	// lets be proper
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:
		@"SSHTunnel <%p>: -l%@ -p%lu %@",
		self,
		self.username,
		self.port,
		self.hostname];
}

- (void)addLocalForwardWithBindAddress:(NSString *)bindAddress
                              bindPort:(NSUInteger)bindPort
                                  host:(NSString *)host
                              hostPort:(NSUInteger)hostPort
{
	[self _addForward:_localForwards
	      bindAddress:bindAddress
             bindPort:bindPort
                 host:host
             hostPort:hostPort];
}

- (void)addRemoteForwardWithBindAddress:(NSString *)bindAddress
                               bindPort:(NSUInteger)bindPort
                                   host:(NSString *)host
                               hostPort:(NSUInteger)hostPort
{
	[self _addForward:_remoteForwards
	      bindAddress:bindAddress
             bindPort:bindPort
                 host:host
             hostPort:hostPort];
}

- (void)addDynamicForwardWithBindAddress:(NSString *)bindAddress bindPort:(NSUInteger)bindPort
{
	[self _addForward:_dynamicForwards
          bindAddress:bindAddress
             bindPort:bindPort
                 host:nil
             hostPort:0U];
}

- (void)launch
{
	NSString *preferredAuths = @"gssapi-with-mic,hostbased";
	NSPipe *stdInPipe, *stdErrPipe;
	
	@synchronized (self)
	{
		if (_launched)
		{
			[NSException raise:NSInvalidArgumentException format:@"SSH tunnel already launched"];
		}
		_launched = YES;
	}
	
	//
	// TODO: need more error checking for invalid parameters
	//
	
	// setup named pipe to communicate with helper
	[self _setupNamedPipe];
	
	// setup ssh arguments
	NSMutableArray *sshArgs = [NSMutableArray array];
    
    [sshArgs addObject:@"-v"];
    [sshArgs addObject:@"-N"];
	
	// sshtunnel args
	[sshArgs addObject:@"-oConnectionAttempts=1"];
	[sshArgs addObject:@"-oExitOnForwardFailure=yes"];
	[sshArgs addObject:@"-oEscapeChar=none"];
	[sshArgs addObject:@"-oKbdInteractiveAuthentication=no"];
	[sshArgs addObject:@"-oNumberOfPasswordPrompts=1"];
	[sshArgs addObject:@"-oPermitLocalCommand=no"];
	[sshArgs addObject:@"-oStrictHostKeyChecking=no"];
	
	// 
	// setup SSH args
	//
	
	// (-t,-T) pseudo tty
	[sshArgs addObject:(self.allocatesPseudoTTY) ? @"-t" : @"-T"];
	
	// (-o) allow publickey,password as an authentication scheme
	if (self.allowsPasswordAuthentication)
	{
		preferredAuths = [preferredAuths stringByAppendingString:@",password"];
	}
	if (self.allowsPublicKeyAuthentication)
	{
		preferredAuths = [preferredAuths stringByAppendingString:@",publickey"];
	}
	[sshArgs addObject:[NSString stringWithFormat:@"-oPreferredAuthentications=%@", preferredAuths]];
	
	// (-g) allow remote hosts to use forwarded ports
	if (self.gatewayPorts)
	{
		[sshArgs addObject:@"-oGatewayPorts=yes"];
	}
	
	// (-o) connection timeout
	[sshArgs addObject:[NSString stringWithFormat:@"-oConnectTimeout=%lu", self.connectTimeout]];
	
	// (-4) force ipv4
	if (self.forceIPv4)
	{
		[sshArgs addObject:@"-4"];
	}
	
	// (-6) force ipv4
	if (self.forceIPv6)
	{
		[sshArgs addObject:@"-6"];
	}
	
	// (-1) force ssh protocol version 1
	if (self.forceProtocol1)
	{
		[sshArgs addObject:@"-1"];
	}
	
	// (-2) force ssh protocol version 2
	if (self.forceProtocol2)
	{
		[sshArgs addObject:@"-2"];
	}
	
	// identity file
	if (self.identityFile)
	{
		[sshArgs addObject:[NSString stringWithFormat:@"-i'%@'", self.identityFile]];
	}
	
	if (self.X11Forwarding)
	{
		[sshArgs addObject:@"-X"];
	}
	
	if (self.X11TrustedForwarding)
	{
		[sshArgs addObject:@"-Y"];
	}
	
	//
	// Tunnel Ports (forward/reverse)
	//
	
	// local forwards
	for (NSDictionary *localForward in _localForwards)
	{
		NSString *bindAddress = [localForward valueForKey:kSSHTunnelForwardBindAddress];
		
		[sshArgs addObject:[NSString stringWithFormat:@"-L%@:%lu:%@:%lu",
				    (bindAddress) ? bindAddress : @"",
				    [[localForward valueForKey:kSSHTunnelForwardBindPort] unsignedIntegerValue],
				    [localForward valueForKey:kSSHTunnelForwardHost],
				    [[localForward valueForKey:kSSHTunnelForwardHostPort] unsignedIntegerValue]]];
	}
	
	// remote forwards
	for (NSDictionary *remoteForward in _remoteForwards)
	{
		NSString *bindAddress = [remoteForward valueForKey:kSSHTunnelForwardBindAddress];
		
		[sshArgs addObject:[NSString stringWithFormat:@"-R%@:%lu:%@:%lu",
				    (bindAddress) ? bindAddress : @"",
				    [[remoteForward valueForKey:kSSHTunnelForwardBindPort] unsignedIntegerValue],
				    [remoteForward valueForKey:kSSHTunnelForwardHost],
				    [[remoteForward valueForKey:kSSHTunnelForwardHostPort] unsignedIntegerValue]]];
	}
	
	// dynamic forwards (socks proxy)
	for (NSDictionary *dynamicForward in _dynamicForwards)
	{
		NSString *bindAddress = [dynamicForward valueForKey:kSSHTunnelForwardBindAddress];
		
		[sshArgs addObject:[NSString stringWithFormat:@"-D%@:%lu",
				    (bindAddress) ? bindAddress : @"",
				    [[dynamicForward valueForKey:kSSHTunnelForwardBindPort] unsignedIntegerValue]]];
	}
	
	// remote hostname:port and login
	[sshArgs addObject:[NSString stringWithFormat:@"-l%@", self.username]];
	[sshArgs addObject:[NSString stringWithFormat:@"-p%lu", self.port]];
	[sshArgs addObject:self.hostname];
	
#ifdef DEBUG
    NSLog(@"%@", sshArgs);
#endif
	STDebugLog(ST_D_LAUNCH, @"ssh args = %@", sshArgs);
	
	// setup ssh environment
	NSMutableDictionary *sshEnv = [NSMutableDictionary dictionary];
	
	// need for SSH_ASKPASS stuff to work
	[sshEnv addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
	[sshEnv setObject:[[NSBundle bundleForClass:[self class]] pathForResource:@"SSHTunnelHelper" ofType:nil]
               forKey:@"SSH_ASKPASS"];
	[sshEnv setObject:_namedPipe forKey:kSSHTunnelNamedPipe];

	// setup task to run ssh tunnel in
	_sshTask = [[NSTask alloc] init];
	
	// update task and get read for launch
	[_sshTask setArguments:sshArgs];
	[_sshTask setEnvironment:sshEnv];
	[_sshTask setLaunchPath:self.sshLaunchPath];
	
	// stdin
	stdInPipe = [NSPipe pipe];
	_sshInHandle = [stdInPipe fileHandleForWriting];
	
	// stderr
	stdErrPipe = [NSPipe pipe];
	_sshErrHandle = [stdErrPipe fileHandleForReading];
	[_sshErrHandle waitForDataInBackgroundAndNotify];
	
	// register terminiation. release of task is done there
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sshDidTerminate:)
                                                 name:NSTaskDidTerminateNotification
                                               object:_sshTask];
	
	// register for output
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sshStdErr:)
                                                 name:NSFileHandleDataAvailableNotification
                                               object:_sshErrHandle];
	
	//
	// set i/o handles
	//
	// setting standard in so if the process
	// abnormally terminates and closes stdin pipe,
	// the ssh subtask will also terminate
	//
	[_sshTask setStandardInput:stdInPipe];
	[_sshTask setStandardError:stdErrPipe];
	
	// setup thread to send password over pipe
	// using thread since writeData blocks and maybe
	// would take some time if the remote host is slow
	[NSThread detachNewThreadSelector:@selector(_namedPipeThread:) toTarget:self withObject:nil];
	
	// startup ssh process
	[_sshTask launch];
}

- (void)terminate
{
	STDebugLog(ST_D_TERMINATE, @"%@", _sshTask);
	
	@synchronized (self)
	{
		if (!_launched)
		{
			[NSException raise:NSInvalidArgumentException format:@"SSH tunnel not launched"];
		}
	}
	
	// actually terminate
	_terminationReason = SSHTunnelTerminationReasonExit;
	
	// signal termination
	[_sshTask terminate];
}

- (void)waitUntilExit
{
	@synchronized (self)
	{
		if (!_launched)
		{
			[NSException raise:NSInvalidArgumentException format:@"SSH tunnel not launched"];
		}
	}
	
	[_sshTask waitUntilExit];
}

- (BOOL)isRunning
{
	return [_sshTask isRunning];
}

- (int)sshProcessIdentifier
{
	return [_sshTask processIdentifier];
}

#pragma mark Property Overrides

- (SSHTunnelTerminationReason)terminationReason
{
	@synchronized (self)
	{
		if (!_launched)
		{
			[NSException raise:NSInvalidArgumentException format:@"SSH tunnel not launched"];
		}
	}
	
	if ([self isRunning])
	{
		[NSException raise:NSInvalidArgumentException format:@"SSH tunnel still running"];
	}
	
	return _terminationReason;
}

#pragma mark Notifications

- (void)sshDidTerminate:(NSNotification *)aNotification
{
	STDebugLog(ST_D_SSHDIDTERMINATE, @"did terminate = %@", aNotification);
	
	// remove all notifications (i.e. terminate, waitForDataInBackground, etc)
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// process any hanging data from SSH pipe
	[self _processSSHOutput:[_sshErrHandle availableData]];
	
	// clean up pipe if still around
	[self _cleanupNamedPipe];
	
	// reset connected status
	_connected = NO;
	
	[_sshErrHandle release];
	_sshErrHandle = nil;
	
	// cleanup ssh task structure
	[_sshTask release];
	_sshTask = nil;
	
	// post notification that tunnel terminated
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:SSHTunnelDidTerminateNotification object:self];
}

- (void)sshStdErr:(NSNotification *)aNotification
{
	[self _processSSHOutput:[_sshErrHandle availableData]];
}

#pragma mark Private API

- (void)_addForward:(NSMutableArray *)forwards
        bindAddress:(NSString *)bindAddress
           bindPort:(NSUInteger)bindPort
               host:(NSString *)host
           hostPort:(NSUInteger)hostPort
{
	if (bindPort < 1 || bindPort > UINT16_MAX)
	{
		[NSException raise:NSInvalidArgumentException format:@"SSH tunnel invalid bind port"];
	}
	
	if (forwards != _dynamicForwards)
	{
		if (!host || [host length] <= 0)
		{
			[NSException raise:NSInvalidArgumentException format:@"SSH tunnel invalid host"];
		}
		
		if (hostPort < 1 || hostPort > UINT16_MAX)
		{
			[NSException raise:NSInvalidArgumentException format:@"SSH tunnel invalid host port"];
		}
	}
	
	if (bindAddress)
	{
		[forwards addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				     bindAddress, kSSHTunnelForwardBindAddress,
				     [NSNumber numberWithInteger:bindPort], kSSHTunnelForwardBindPort,
				     host, kSSHTunnelForwardHost,
				     [NSNumber numberWithInteger:hostPort], kSSHTunnelForwardHostPort, nil]];
	}
	else
	{
		[forwards addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				     [NSNumber numberWithInteger:bindPort], kSSHTunnelForwardBindPort,
				     host, kSSHTunnelForwardHost,
				     [NSNumber numberWithInteger:hostPort], kSSHTunnelForwardHostPort, nil]];
	}
}

- (void)_cleanupNamedPipe
{
	STDebugLog(ST_D_NAMEDPIPE, @"pipe: %@", _namedPipe);
	
	if (_namedPipe && [[NSFileManager defaultManager] isDeletableFileAtPath:_namedPipe])
	{
		// attempt to close file on thread, sync over _namedPipe
		// since if used the handle for sync, a race condition may occur
		@synchronized (_namedPipe)
		{
			[_namedPipeHandle closeFile];
		}
		
		// remove file
		if ([[NSFileManager defaultManager] isDeletableFileAtPath:_namedPipe])
		{
			[[NSFileManager defaultManager] removeItemAtPath:_namedPipe error:NULL];
		}
		
		// free up memory
		[_namedPipe release];
		_namedPipe = nil;
	}
}

- (void)_setupNamedPipe
{
	struct timespec ts;
	int limit = 0, ret;
	long rval;
	
	ts.tv_sec = 0;
	ts.tv_nsec = 250000000; // 250ms
	
	do
	{
		rval = random();
		rval &= 0xffffffff; // only want the bottom 32 bits
		
		// try this filename
		_namedPipe = [NSString stringWithFormat:SSHTunnelNamedPipeFormat, NSUserName(), rval];
		STDebugLog(ST_D_NAMEDPIPE, @"_namedPipe: %@", _namedPipe);
		
		// if we found an unique name, break out of loop
		if (![[NSFileManager defaultManager] fileExistsAtPath:_namedPipe])
		{
			break;
		}
		
		// did get a unique filename, sleep for a short time
		// (give random enough time to seed a new value)
		// then, try again
		
		limit++;
		nanosleep(&ts, NULL);
	} while (limit <= 99);
	
	if (limit > 99)
	{
		[NSException raise:NSInvalidArgumentException format:@"could not create unique pipe name"];
	}
	
	// create fifo pipe
	if ((ret = mkfifo([_namedPipe cStringUsingEncoding:NSUTF8StringEncoding], S_IRUSR|S_IWUSR)) != 0)
	{
		[NSException raise:NSInvalidArgumentException format:@"could not create communication pipe (%d)", ret];
	}
	
	// keep this around until dealloc
	[_namedPipe retain];
}

- (void)_processSSHOutput:(NSData *)data
{
	STDebugLog(ST_D_PROCESSOUTPUT, @"data length = %d", [data length]);
	
	if ([data length] > 0)
	{
		NSString *log = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
#ifdef DEBUG
        NSLog(@"%@", log);
#endif
        
		if ([log rangeOfString:@"Entering interactive session."].location != NSNotFound)
		{
			// stop listening to ssh output
			[[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:NSFileHandleDataAvailableNotification
                                                          object:_sshErrHandle];
			
			// we are connected!
			_connected = YES;
			
			// post notification that we are connected
			[[NSNotificationCenter defaultCenter] postNotificationName:SSHTunnelDidConnectNotification object:self];
		}
		else if ([log rangeOfString:@"Permission denied"].location != NSNotFound)
		{
			_terminationReason = SSHTunnelTerminationReasonPermissionDenied;
		}
		else if ([log rangeOfString:@"REMOTE HOST IDENTIFICATION HAS CHANGED!"].location != NSNotFound)
		{
			_terminationReason = SSHTunnelTerminationReasonHostKeyVerificationFailed;
		}
		else if ([log rangeOfString:@"Could not resolve hostname"].location != NSNotFound)
		{
			_terminationReason = SSHTunnelTerminationReasonResolveHostnameFailed;
		}
		else if ([log rangeOfString:@"Operation timed out"].location != NSNotFound)
		{
			_terminationReason = SSHTunnelTerminationReasonConnectTimeout;
		}
		else if ([log rangeOfString:@"Connection refused"].location != NSNotFound)
		{
			_terminationReason = SSHTunnelTerminationReasonConnectionRefused;
		}
		else if ([log rangeOfString:@"Could not request local forwarding"].location != NSNotFound)
		{
			_terminationReason = SSHTunnelTerminationReasonLocalBindAddressInUse;
		}
		else if ([log rangeOfString:@"Error: remote port forwarding failed for listen port"].location != NSNotFound)
		{
			_terminationReason = SSHTunnelTerminationReasonRemoteBindAddressInUse;
		}
		else
		{
			[_sshErrHandle waitForDataInBackgroundAndNotify];
		}
		
		[log release];
		log = nil;
	}
}

#pragma mark Named Pipe Thread

- (void)_namedPipeThread:(id)anObject
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_namedPipeHandle = [NSFileHandle fileHandleForWritingAtPath:_namedPipe];
	
	[_namedPipeHandle writeData:[self.password dataUsingEncoding:NSUTF8StringEncoding]];
	[_namedPipeHandle closeFile];
	
	@synchronized (_namedPipe)
	{
		_namedPipeHandle = nil;
	}
	
	[pool drain];	
	[NSThread exit];
}

@end
