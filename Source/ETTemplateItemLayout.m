/*
	Copyright (C) 2008 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  July 2008
	License:  Modified BSD (see COPYING)
 */

#import <EtoileFoundation/ETCollection.h>
#import <EtoileFoundation/Macros.h>
#import "ETTemplateItemLayout.h"
#import "ETFlowLayout.h"
#import "ETColumnLayout.h"
#import "ETLayoutItem.h"
#import "ETLayoutItem+Factory.h"
#import "ETLayoutItemGroup.h"
#import "NSView+Etoile.h"
#import "ETCompatibility.h"


@implementation ETTemplateItemLayout

- (id) initWithLayoutView: (NSView *)aView
{
	return [self init];
}

/** <init /> */ 
- (id) init
{
	self = [super initWithLayoutView: nil];
	if (nil == self)
		return nil;
	
	[self setPositionalLayout: [ETFlowLayout layout]];
	_templateKeys = [[NSArray alloc] init];
	_localBindings = [[NSMutableDictionary alloc] init];

	return self;
}

- (void) dealloc
{
	DESTROY(_positionalLayout);
	DESTROY(_templateItem);
	DESTROY(_templateKeys);
	DESTROY(_replacementItems); 
	DESTROY(_localBindings);
	[super dealloc];
}

- (id) copyWithZone: (NSZone *)aZone layoutContext: (id <ETLayoutingContext>)ctxt
{
	ETTemplateItemLayout *layoutCopy = [super copyWithZone: aZone layoutContext: ctxt];

	layoutCopy->_positionalLayout = [(ETLayout *)_positionalLayout copyWithZone: aZone layoutContext: layoutCopy];
	layoutCopy->_templateItem = [_templateItem deepCopyWithZone: aZone];
	layoutCopy->_templateKeys = [_templateKeys copyWithZone: aZone];
	layoutCopy->_localBindings = [_localBindings mutableCopyWithZone: aZone];	
	// NOTE: If we really use replacementItems, we need...
	//layoutCopy->_replacementItems = [[NSArray allocWithZone: aZone] initWithArray: _replacementItems copyItems: YES];
	// TODO: Set up the bindings per item in -setUpCopyWithZone:

	return layoutCopy;
}

- (ETLayoutItem *) templateItem
{
	return _templateItem;
}

- (void) setTemplateItem: (ETLayoutItem *)item
{
	ASSIGN(_templateItem, item);
}

- (NSArray *) templateKeys
{
	return _templateKeys;
}

- (void) setTemplateKeys: (NSArray *)keys
{
	ASSIGN(_templateKeys, keys);
}

- (void) bindTemplateItemKeyPath: (NSString *)templateKeyPath 
               toItemWithKeyPath: (NSString *)itemProperty
{
	[_localBindings setObject: itemProperty forKey: templateKeyPath];
}

/** Discards all bindings currently set up between the template item and the 
original items which are replaced by the layout. */
- (void) unbindTemplateItem
{
	[_localBindings removeAllObjects];
}

- (void) setUpTemplateElementsForItem: (ETLayoutItem *)item
{
	FOREACH(_templateKeys, key, NSString *)
	{
		id value = [item valueForKey: key];

		if (nil == value)
			value = [NSNull null];

		[item setDefaultValue: value forProperty: key];

		id templateValue = [_templateItem valueForKey: key];
		BOOL shouldCopyValue = ([templateValue conformsToProtocol: @protocol(NSCopying)] 
			|| [templateValue conformsToProtocol: @protocol(NSMutableCopying)]);
		id newValue = (shouldCopyValue ? [templateValue copy] : templateValue);
		[item setValue: newValue forKey: key];

		[self setUpKVOForItem: item];
	}
}

- (id <ETPositionalLayout>) positionalLayout
{
	return _positionalLayout;
}

- (void) setPositionalLayout: (id <ETPositionalLayout>)layout
{
	[layout setLayoutContext: self];
	ASSIGN(_positionalLayout, layout);
}

/* Subclass Hooks */

// TODO: Implement NSEditor and NSEditorRegistration protocol, but in ETLayout 
// subclasses or rather in ETLayoutItem itself?
// Since layouts tend to encapsulate large UI chuncks, it could make sense at 
// this level. Well... on ETLayoutItem, it ensures it works easily if we bind 
// a view to its owner item.
- (void) setUpKVOForItem: (ETLayoutItem *)item
{
	FOREACHI([_localBindings allKeys], templateKeyPath)
	{
		id model = ([item representedObject] == nil ? (id)item : [item representedObject]);
		id itemElement = [item valueForKeyPath: templateKeyPath];
		NSString *modelKeyPath = [_localBindings objectForKey: templateKeyPath];

		[itemElement bind: @"value" 
		         toObject: model
			  withKeyPath: modelKeyPath
		          options: nil];//NSKeyValueObservingOptionNew];
	}
}

/** Not needed if -bind:xxx is used since view objects released their bindings 
when they get deallocated. */
- (void) tearDownKVO
{
	/*FOREACHI([_localBindings allKeys], templateKeyPath)
	{
		templateElement = [item valueForKey: templateKeyPath];
		[templateElement bind: @"value"];
	}*/
}

- (void) tearDown
{
	FOREACH(_replacementItems, replacementItem, ETLayoutItem *)
	{
		[[replacementItem displayView] removeFromSuperview];
	}
	
	DESTROY(_replacementItems);
}

/** Reflects the selection state of the replaced items on the replacement 
    items. */
- (void) selectionDidChangeInLayoutContext
{
	FOREACH(_replacementItems, replacementItem, ETLayoutItem *)
	{
		ETLayoutItem *replacedItem = [replacementItem representedObject];
		[replacementItem setSelected: [replacedItem isSelected]];
	}
}

/** Returns the replaced item for the replacement item found at the given location. */
- (ETLayoutItem *) itemAtLocation: (NSPoint)loc
{
	return [[(id)[self positionalLayout] itemAtLocation: loc] representedObject];
}

/* Layouting */

- (void) renderWithLayoutItems: (NSArray *)items isNewContent: (BOOL)isNewContent
{
	if (isNewContent)
	{
		[self tearDown];

		ASSIGN(_replacementItems, items);

		FOREACH(items, replacedItem, ETLayoutItem *)
		{
			[self setUpTemplateElementsForItem: replacedItem];

		}
	}
	
	NSAssert1([self positionalLayout] != nil, @"Positional layout %@ must "
		@"not be nil in a template item layout", [self positionalLayout]);

	/* Visibility of replaced and replacement items is handled in 
	   -setVisibleItems: */
	[[self positionalLayout] renderWithLayoutItems: _replacementItems isNewContent: isNewContent];
}

/* Layouting Context Protocol 

   We redirect several calls on the layout context to the target item where the 
   layout items are really rendered. 
   You may better understand what is really going on by reading the code of 
   -renderWithLayoutItems:isNewContent:.
   The target item is the layout context for all presentational related calls 
   and all other calls that relates to the tree structure to be displayed are 
   passed to the receiver layout context (the layout item on which is the 
   composite layout is applied). */

- (NSArray *) items
{
	return _replacementItems;
}

// FIXME: ...
- (NSArray *) arrangedItems
{
	return _replacementItems;
}

// TODO: Visible items are a bit problematic because they depend on the target 
// item precisely its size and at the same time they are provided by the routed 
// context ([self layoutContext], they bolong to the item to which the receiver 
// layout is applied. That's why we reimplement these methods here.

- (NSArray *) visibleItems
{
	return [[self layoutContext] visibleItemsForItems: _replacementItems];
}

- (void) setVisibleItems: (NSArray *)visibleReplacementItems
{
	[[self layoutContext] setVisibleItems: [NSArray array]];
	
	[[self layoutContext] setVisibleItems: visibleReplacementItems 
	                          forItems: _replacementItems];
							  
	FOREACH(_replacementItems, replacementItem, ETLayoutItem *)
	{
		[[replacementItem representedObject] setVisible: [replacementItem isVisible]];
	}
}

- (NSSize) size
{
	return [[self layoutContext] size];
}

- (void) setSize: (NSSize)size
{
	[[self layoutContext] setSize: size];
}

- (ETView *) supervisorView
{
	return [[self layoutContext] supervisorView];
}

- (void) setLayoutView: (NSView *)aLayoutView
{

}

- (NSView *) view
{
 // FIXME: Remove this cast and solve this properly
	return [(ETLayoutItem *)[self layoutContext] view];
}

- (ETLayoutItem *) itemAtIndexPath: (NSIndexPath *)path
{
	return [[self layoutContext] itemAtIndexPath: path];
}

- (ETLayoutItem *) itemAtPath: (NSString *)path
{
	return [[self layoutContext] itemAtPath: path];
}

- (float) itemScaleFactor
{
	return [[self layoutContext] itemScaleFactor];
}

- (NSSize) visibleContentSize
{
	return [[self layoutContext] visibleContentSize];
}

- (void) setContentSize: (NSSize)size;
{
	[[self layoutContext] setContentSize: size];
}

- (BOOL) isScrollViewShown
{
	return [[self layoutContext] isScrollViewShown];
}

- (void) setNeedsDisplay: (BOOL)now
{
	return [[self layoutContext] setNeedsDisplay: now];
}

- (BOOL) isFlipped
{
	return [[self layoutContext] isFlipped];
}

- (NSArray *) visibleItemsForItems: (NSArray *)items
{
	return [[self layoutContext] visibleItemsForItems: items];
}

- (void) setVisibleItems: (NSArray *)visibleItems forItems: (NSArray *)items
{
	[[self layoutContext] setVisibleItems: visibleItems forItems: items];
}

- (void) sortWithSortDescriptors: (NSArray *)descriptors recursively: (BOOL)recursively
{
	return [[self layoutContext] sortWithSortDescriptors: descriptors recursively: recursively];
}

@end

#define CONTROL_VIEW_TAG 0

/* property			value
kETFormLayoutHint	kETLabelAlignment (default) or nil
					kETLeftAlignement
					kETRightAlignment
					kETCenterAligment
					kETPreviousItemAlignement

kETFormLayoutInset	NSZeroRect (default) or nil
					a rect value */

@implementation ETFormLayout

- (id) init
{
	SUPERINIT
	
	[self setPositionalLayout: [ETColumnLayout layout]];
	
	return self;
}

- (float) controlMargin
{
	return 10;
}

- (float) formElementMargin
{
	return 5;
}

- (float) maxLabelWidth
{
	return 300;
}

- (void) insertLabelField: (NSView *)labelField 
                  control: (NSView *)control 
			       inItem: (ETLayoutItem *)item
{
	float labelWidth = [labelField width];
	
	if (labelWidth > [self maxLabelWidth])
		labelWidth = [self maxLabelWidth];
		
	if (labelWidth > highestLabelWidth)
		highestLabelWidth = labelWidth;
		
	//float labelY = ([item height] - ([self controlMargin] + [labelField height]));
		
	[labelField setX: (highestLabelWidth - labelWidth)];
	[labelField setY: 0];//labelY];
	[control setX: (highestLabelWidth + [self controlMargin])];
	[control setY: 0];

	float itemHeight = (control != nil ? [control height] : [labelField height]);
	float basicItemWidth = highestLabelWidth;
	
	if (control != nil)
		basicItemWidth += [control width];
	
	[item setHeight: itemHeight];
	[item setWidth: basicItemWidth + [self controlMargin]];
	/* Make the item frame the default frame, so no scaling is computed by 
	   -resizeItem:byScaleFactor:, otherwise the default frame doesn't match 
	   the new height and width, but the value previously set when inserting 
	   the item template view */
	[item setDefaultFrame: [item frame]];
	[[item view] addSubview: labelField];
	[[item view] addSubview: control];
}

- (NSView *) labelFieldTemplate
{
	NSTextField *labelField = AUTORELEASE([[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 77, 22)]);
	
	//[labelField setTag: LABEL_FIELD_TAG];
	
	[labelField setDrawsBackground: NO];
	[labelField setBordered: NO];
	[labelField setEditable: YES];
	[labelField setSelectable: YES];
	//[labelField setStringValue: _(@"Untitled")];
	[labelField setAlignment: NSCenterTextAlignment];
	[labelField setAutoresizingMask: NSViewNotSizable];
	
	return labelField;
}

- (NSView *) createControlWithView: (NSView *)view
{
	NSView *control = [view copy];
	
	//[control setTag: CONTROL_VIEW_TAG];
	[control setAutoresizingMask: NSViewNotSizable | NSViewWidthSizable | NSViewHeightSizable];

	return AUTORELEASE(control);
}

/** Returns a very dumb template item that only consists of a view.
    The real set up of the template item is handled in 
	-buildReplacementItemForItem: where the label field and control views are 
	inserted, customized and layouted as subviews of the template item view. */
- (ETLayoutItem *) templateItem
{
	NSView *templateView = AUTORELEASE([[NSView alloc] initWithFrame: NSMakeRect(0, 0, 200, 80)]);
	
	// FIXME: Figure out what we should do with that...
	//[self setAutoresizingMask: NSViewWidthSizable];
	//[self setAutoresizesSubviews: YES];

	return [ETLayoutItem itemWithView: templateView];
}

- (void) setUpTemplateElementsForItem: (ETLayoutItem *)item
{
	ETLayoutItem *newItem = item;
	[super setUpTemplateElementsForItem: item];
	NSView *replacedItemView = AUTORELEASE([[item view] copy]); // Replaced by -createControlWithView:
	NSControl *labelField = AUTORELEASE([[self labelFieldTemplate] copy]);
	
	// FIXME: Shouldn't be needed, the autoresizing set on the template view 
	// should be enough.
	[newItem setAutoresizingMask: NSViewWidthSizable];
	// FIXME: Shouldn't be needed, no autoresizing should exist on widget 
	// items such as slider or button returned by ETLayoutItem+Factory...
	// text field is a different case, but for the sake of consistency we may 
	// prefer to suppress the autoresizing mask on it too.
	[replacedItemView setAutoresizingMask: NSViewNotSizable];
	[replacedItemView setHeight: 22];
	//[replacedItemView setTag: CONTROL_VIEW_TAG];
	if ([item name] != nil)
		[labelField setStringValue: [item name]];
	[labelField sizeToFit];
	[self insertLabelField: labelField
	               control: replacedItemView
			    	inItem: newItem];
}

@end
