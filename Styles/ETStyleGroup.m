/*
	Copyright (C) 2009 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <EtoileFoundation/NSObject+Trait.h>
#import <EtoileFoundation/Macros.h>
#import <CoreObject/COPrimitiveCollection.h>
#import "ETStyleGroup.h"
#import "ETCompatibility.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation ETStyleGroup

+ (void) initialize
{
	if (self != [ETStyleGroup class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
	[self applyTraitFromClass: [ETMutableCollectionTrait class]];
}

+ (NSString *) baseClassName
{
	return @"StyleGroup";
}

+ (NSSet *) keyPathsForValuesAffectingLastStyle
{
    return S(@"styles");
}

+ (NSSet *) keyPathsForValuesAffectingFirstStyle
{
    return S(@"styles");
}

/** Initializes and returns an empty style group. */
- (instancetype) initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
	return [self initWithCollection: nil objectGraphContext: aContext];
}

/** Initializes and returns a style group that only contains a single style. */
- (instancetype) initWithStyle: (ETStyle *)aStyle objectGraphContext: (COObjectGraphContext *)aContext
{
	return [self initWithCollection: @[aStyle] objectGraphContext: aContext];
}

/** <init />Initializes and returns a style group that contains all the styles 
in the given style collection. */
- (instancetype) initWithCollection: (id <ETCollection>)styles objectGraphContext: (COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	if (self == nil)
		return nil;

	[self setIsShared: NO];
	if (styles != nil)
	{
		_styles = [[COMutableArray alloc] initWithArray: [styles contentArray]];
	}
	else
	{
		_styles = [[COMutableArray alloc] init];
	}
	return self;
}

- (NSImage *) icon
{
	return [NSImage imageNamed: @"layers-stack"];
}

/* Style Collection */

/** Add the style. */
- (void) addStyle: (ETStyle *)aStyle
{
	[self willChangeValueForProperty: @"styles"];
	[_styles addObject: aStyle];
	[self didChangeValueForProperty: @"styles"];
}

/** Inserts a style at the given index. */
- (void) insertStyle: (ETStyle *)aStyle atIndex: (int)anIndex
{
	[self willChangeValueForProperty: @"styles"];
	[_styles insertObject: aStyle atIndex: anIndex];
	[self didChangeValueForProperty: @"styles"];
}

/** Removes the given style. */
- (void) removeStyle: (ETStyle *)aStyle
{
	[self willChangeValueForProperty: @"styles"];
	[_styles removeObject: aStyle];
	[self didChangeValueForProperty: @"styles"];
}

/** Removes all the styles. */
- (void) removeAllStyles
{
	[self willChangeValueForProperty: @"styles"];
	[_styles removeAllObjects];
	[self didChangeValueForProperty: @"styles"];
}

/** Returns whether the receiver contains a style equal to the given style. */
- (BOOL) containsStyle: (ETStyle *)aStyle
{
	return [_styles containsObject: aStyle];
}

/** Returns the first rendered style. */
- (id) firstStyle
{
	return [_styles firstObject];
}

/** Returns the first style of the kind of the given class.

When no style matches, returns nil.  */
- (id) firstStyleOfClass: (Class)aStyleClass
{
	for (ETStyle *style in _styles)
	{
		if ([style isKindOfClass: aStyleClass])
		{
			return style;
		}
	}

	return nil;
}

/** Returns the last rendered style. */
- (id) lastStyle
{
	return [_styles lastObject];
}

/* Style Rendering */

/** Renders the styles sequentially from the first to the last in the current 
graphics context. 

The first style is drawn, then the second style is drawn atop, and so on until 
the last one is reached.

item indicates in which item the receiver is rendered. Usually this item is the 
one on which the receiver is set as a style group. However it can be unrelated 
to the style group or nil.

dirtyRect can be used to optimize the drawing. You only need to redraw what is 
inside that redisplayed area and won't be clipped by the graphics context. */
- (void) render: (NSMutableDictionary *)inputValues 
     layoutItem: (ETLayoutItem *)item 
	  dirtyRect: (NSRect)dirtyRect
{
	for (ETStyle *style in _styles)
	{
		[style render: inputValues layoutItem: item dirtyRect: dirtyRect];
	}
}
	  
/** Notifies every style with -didChangeItemBounds: to let it know that the 
item, to which the receiver is bound to, has been resized. */
- (void) didChangeItemBounds: (NSRect)bounds
{
	for (ETStyle *style in _styles)
	{
		[style didChangeItemBounds: bounds];
	}
}

/* Collection Protocol */

/** Returns YES. */
- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return _styles;
}

- (NSArray *) contentArray
{
	return [NSMutableArray arrayWithArray: _styles];
}

- (void) addObject: (id)anObject
{
	[self addStyle: anObject];
}

- (void) insertObject: (id)anObject atIndex: (NSUInteger)anIndex hint: (id)hint
{
	[self insertStyle: anObject atIndex: anIndex];
}

- (void) removeObject: (id)anObject atIndex: (NSUInteger)index hint: (id)hint
{
	[self removeStyle: anObject];
}

@end

