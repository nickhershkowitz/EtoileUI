/**
	Copyright (C) 2007 Quentin Mathe
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  July 2007
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileUI/ETGraphicsBackend.h>
#import <EtoileUI/ETStyle.h>

/** @abstract An ETStyle subclass used to represent arbitrary shapes. These 
shapes can be primitives such as rectangles, oval etc., or more complex shapes 
that embed or combine text, image, shadow, mask etc.

ETShape instances are model objects. As such they are never manipulated
directly by a layout, but ETLayout subclasses interact with them indirectly 
through layout items. A shape is made of a path and optional style and transform. U
nlike NSBezierPath instances, they support boolean operations (will probably 
implemented in a another framework with a category).

Shapes cannot be used as shared style objects, -[ETShape isShared] always 
returns NO unlike ETStyle. */
@interface ETShape : ETStyle
{
	@private
	NSImage *_icon;
	NSBezierPath *_path;
	NSColor *_fillColor;
	NSColor *_strokeColor;
	CGFloat _alphaValue;
	BOOL _hidden;
	NSString *_pathResizeSelectorName;
}

+ (NSRect) defaultShapeRect;
+ (void) setDefaultShapeRect: (NSRect)aRect;

+ (ETShape *) shapeWithBezierPath: (NSBezierPath *)aPath objectGraphContext: (COObjectGraphContext *)aContext;
+ (ETShape *) rectangleShapeWithRect: (NSRect)aRect objectGraphContext: (COObjectGraphContext *)aContext;
+ (ETShape *) rectangleShapeWithObjectGraphContext: (COObjectGraphContext *)aContext;
+ (ETShape *) ovalShapeWithRect: (NSRect)aRect objectGraphContext: (COObjectGraphContext *)aContext;
+ (ETShape *) ovalShapeWithObjectGraphContext: (COObjectGraphContext *)aContext;

- (instancetype) initWithBezierPath: (NSBezierPath *)aPath objectGraphContext: (COObjectGraphContext *)aContext NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readwrite) BOOL isShared;

@property (nonatomic, copy) NSBezierPath *path;
@property (nonatomic) NSRect bounds;
@property (nonatomic) SEL pathResizeSelector;

@property (nonatomic, copy) NSColor *fillColor;
@property (nonatomic, copy) NSColor *strokeColor;

@property (nonatomic) CGFloat alphaValue;

@property (nonatomic) BOOL hidden;

/** Returns whether the shape acts as a mask over previous drawing. All drawing
done by all previous renderers will be clipped by the path of the receiver. 
Following this renderer, only the area matching the non-filled part the shape 
will remain and be put through next renderers. */
/*- (BOOL) isMask;
- (void) setMask: (BOOL)flag;*/

- (void) render: (NSMutableDictionary *)inputValues 
     layoutItem: (ETLayoutItem *)item 
	  dirtyRect: (NSRect)dirtyRect;
- (void) drawInRect: (NSRect)rect;

- (void) didChangeItemBounds: (NSRect)bounds;

@end
