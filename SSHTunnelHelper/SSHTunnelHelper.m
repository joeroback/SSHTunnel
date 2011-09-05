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
//  SSHTunnelHelper.m
//  SSHTunnel
//
//  Created by Joseph Roback on 12/11/09.
//

#import <Foundation/Foundation.h>
#import "SSHTunnel.h"


int main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSError *error;
	
	// read password from pipe
	NSDictionary *procEnv = [[NSProcessInfo processInfo] environment];
	NSString *namedPipe = [procEnv valueForKey:kSSHTunnelNamedPipe];
	NSFileHandle *namedPipeHandle = [NSFileHandle fileHandleForReadingAtPath:namedPipe];
	NSData *pipeData = [namedPipeHandle readDataToEndOfFile];
	[namedPipeHandle closeFile];
	
	// write password to ssh
	NSFileHandle *stdOutHandle = [NSFileHandle fileHandleWithStandardOutput];
	[stdOutHandle writeData:pipeData];
	[stdOutHandle closeFile];
	
	// cleanup pipe file
	if ([[NSFileManager defaultManager] isDeletableFileAtPath:namedPipe])
	{
		if (![[NSFileManager defaultManager] removeItemAtPath:namedPipe error:&error])
		{
			NSLog(@"%@", error);
			exit(EXIT_FAILURE);
		}
	}
	
	[pool drain];
	
	return 0;
}
