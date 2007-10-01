/*
	ETObjectRegistry.h
	
	Cascading Object Registry which allows to compute objects state and 
	behavior in a late bound way
 
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  September 2007
 
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
 
#import <EtoileUI/ETObjectRegistry.h>
#ifndef GNUSTEP
#import <EtoileUI/GNUstep.h>
#endif

#define PROTO _parent
/* Specify the capacity to be allocated to collect inherited properties in an array */
#define PROPERTY_AVERAGE_NB 200

@interface ETObjectRegistry (Private)
- (id) cloneWithZone: (NSZone *)zone;
- (void) setPrototype: (id)parent;
- (id) prototype;
- (id) initWithPrototype: (id)parent;
- (BOOL) isGroup;
@end


@implementation ETObjectRegistry

static ETObjectRegistry *rootObjectRegistry = nil;

/** Returns the root registry of the object registry tree. 
	The root registry is always a registry group. 
	Presently each application has its own object registry tree. In future,  
	when CoreObject is available on the host system, the root registry
	instance will be automatically shared accross applications. */ 
+ (id) rootRegistry
{
	if (rootObjectRegistry == nil)
		rootObjectRegistry = [[ETObjectRegistry alloc] init];

	return rootObjectRegistry;
}

- (id) init
{
	return [self initWithRegistry: nil];
}

- (id) initWithRegistry: (ETObjectRegistry *)registry
{
	return [self initWithPrototype: (id)registry];
}

- (id) initWithPrototype: (id)parent
{
	self = [super init];
	
	if (self != nil)
	{
		[self setPrototype: parent];
		[self setPropertyClass: [self class]];
		_properties = [[NSMutableDictionary alloc] init];
	}
		
	return self;
}

- (ETObjectRegistry *) parentRegistry
{
	return (ETObjectRegistry *)[self prototype];
}

- (void) setParentRegistry: (ETObjectRegistry *)registry
{
	[self setPrototype: (id)registry];
}

- (id) prototype
{
	return PROTO;
}

- (void) setPrototype: (id)parent
{
	NSAssert2([parent isKindOfClass: [self class]], 
		@"Prototype %@ of %@ must be of type ETObjectRegistry", parent, self);
	
	ASSIGN(PROTO, parent);
}

- (void) dealloc
{
	DESTROY(_properties);
	DESTROY(_propertyClass);
	DESTROY(_parent);
	
	[super dealloc];
}

/** Returns YES whether the receiver is an object registry referencing other
	object registries. If -propertyClass value isn't a class of 
	ETObjectRegistry kind, returns NO.
	Take note this method is only here to help code readibility, the result is 
	identical if you call -isGroup method. */
- (BOOL) isRegistryGroup
{
	return [self isGroup];
}

- (BOOL) isGroup
{
	return [[self propertyClass] isSubclassOfClass: [self class]];
}

/** Returns a clone object of the receiver. The receiver plays the role of
	prototype for the new instance. 
	Instance clones are mutable by default unlike instance copies. */
- (id) clone
{
	return [self cloneWithZone: NSDefaultMallocZone()];
}

- (id) cloneWithZone: (NSZone *)zone
{
	ETObjectRegistry *reg = [[ETObjectRegistry alloc] initWithRegistry: self];
	
	return AUTORELEASE(reg);
}

/** Returns the object registry known by key. If the receiver isn't a registry 
	group, then returns nil.
	Parameter class is used to verify the matching object registry manages 
	properties of type class as expected. If the property class doesn't match,
	returns nil. 
	When a registry matching key cannot be found directly in the receiver, a 
	recursive lookup is done in parent object registry chain. If this lookup
	climbs up to the root registry and doesn't succeed, nil is returned. */
- (id) registryForKey: (NSString *)key propertyClass: (Class)class
{
	if ([[self propertyClass] isEqual: class])
		return self;
	
	return [self valueForProperty: key];
}

/* Runtime Type Checking */

/** Returns the class to which every value/property stored in the receiver must. */
- (Class) propertyClass
{
	return _propertyClass;
}

- (void) setPropertyClass: (Class)class
{
	ASSIGN(_propertyClass, class);
}

/* Property Value Coding */

/** Returns the propertie specific to the receiver, excluding all properties 
	which are inherited through the object registry chain. */
- (NSArray *) properties
{
	return [_properties allKeys];
}

/** Returns the propertie specific to the receiver, excluding all properties 
	which are inherited through the object registry chain.
	 */
- (id) valueForProperty: (NSString *)key
{
	id value = [_properties objectForKey: key];
	
	if (value == nil && PROTO != nil)
	{
		value = [PROTO valueForProperty: key];
	}
	
	return value;
}

- (void) setValue: (id)value forProperty: (NSString *)key
{
	if (value != nil)
	{
		/* Verify the property type is accepted by this registry */
		if ([value isKindOfClass: [self propertyClass]])
		{
			[_properties setObject: value forKey: key];
		}
		else
		{
			[NSException raise: NSInvalidArgumentException format: @"Value "
				@"must be of type %@ for registry %@", [self propertyClass], 
				self];
		}
	}
	else
	{
		[_properties removeObjectForKey: key];
	}
}

/** Returns inherited properties which are stored in ancestor object 
	registries. The resulting array doesn't include the receiver properties.
	These properties are collected by doing a recursive lookup through the 
	object registry chain and aggregating properties of each ancestor registry
	including the root registry where the lookup ends up. */
- (NSArray *) parentProperties
{
	NSMutableArray *parentProps = [NSMutableArray arrayWithCapacity: PROPERTY_AVERAGE_NB];
	ETObjectRegistry *registry = self;
	
	while ((registry = [registry parentRegistry]) != nil)
	{
		[parentProps addObjectsFromArray: [registry properties]];
	} 
	
	return parentProps;
}

/** Returns the union of both the receiver properties and the inherited 
	properties. 
	For more details, see -properties and -parentProperties. */
- (NSArray *) allProperties
{
	return [[self properties] 
		arrayByAddingObjectsFromArray: [self parentProperties]];
}

/* Collection Protocol */

- (id) content
{
	return _properties;
}

- (NSArray *) contentArray
{
	return [_properties contentArray];
}

@end
