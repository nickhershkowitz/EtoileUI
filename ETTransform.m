/*
	ETTransform.m
	
	Description forthcoming.
 
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  November 2007
 
	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.
	* Neither the name of the Etoile project nor the names of its contributors
	  may be used to endorse or promote products derived from this software
	  without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
	THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <EtoileUI/ETLayoutItemBuilder.h>
#import <EtoileUI/NSString+Etoile.h>


@implementation ETTransform

- (id) render: (id)object
{
	NSString *typeName = [object className];
	NSString *renderMethodName = [[@"render" append: typeName] append: @":"];
	SEL renderSelector = NSSelectorFromString(renderMethodName);
	BOOL performed = NO;
	id item = nil;

	item = [self tryToPerformSelector: renderSelector withObject: object result: &performed];

	if (performed == NO && ([typeName hasPrefix: @"ET"] || [typeName hasPrefix: @"NS"]))
	{
		typeName = [typeName substringFromIndex: 2];
		renderMethodName = [[@"render" append: typeName] append: @":"];
		renderSelector = NSSelectorFromString(renderMethodName);

		item = [self tryToPerformSelector: renderSelector withObject: object result: NULL];
	}

	return item;
}

- (id) tryToPerformSelector: (SEL)selector withObject: (id)object result: (BOOL *)performed
{
	if ([self respondsToSelector: selector])
	{
		*performed = YES;
		return [self performSelector: selector withObject: object];
	}
	else
	{
		*performed = NO;
		return nil;
	}
}

@end
