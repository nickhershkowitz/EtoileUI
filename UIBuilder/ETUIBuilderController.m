/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  May 2013
	License:  Modified BSD  (see COPYING)
 */

#import <EtoileFoundation/ETCollection+HOM.h>
#import <EtoileFoundation/ETViewpoint.h>
#import <EtoileFoundation/NSObject+HOM.h>
#import <EtoileFoundation/Macros.h>
#import <CoreObject/COCommitDescriptor.h>
#import <CoreObject/COEditingContext.h>
#import <CoreObject/COObjectGraphContext.h>
#import <CoreObject/COPersistentRoot.h>
#import <IconKit/IKIcon.h>
#import "ETUIBuilderController.h"
#import "ETApplication.h"
#import "ETArrowTool.h"
#import "ETAspectRepository.h"
#import "EtoileUIProperties.h"
#import "ETItemValueTransformer.h"
#import "ETLayoutItem.h"
#import "ETLayoutItemGroup.h"
#import "ETLayoutItem+CoreObject.h"
#import "ETLayoutItem+UIBuilder.h"
#import "ETObjectValueFormatter.h"
#import "ETSelectTool.h"
#import "ETUIBuilderItemFactory.h"
#import "ETUIStateRestoration.h"

@implementation ETUIBuilderController

@synthesize itemFactory = _itemFactory, documentContentItem = _documentContentItem, browserItem = _browserItem,
	aspectInspectorItem = _aspectInspectorItem, viewPopUpItem = _viewPopUpItem,
	aspectPopUpItem = _aspectPopUpItem, aspectRepository = _aspectRepository, 
	relationshipValueTransformer = _relationshipValueTransformer,
	imageValueTransformer = _imageValueTransformer,
	typeValueTransformer = _typeValueTransformer;

- (instancetype) initWithNibName: (NSString *)aNibName
                bundle: (NSBundle *)aBundle
    objectGraphContext: (COObjectGraphContext *)aContext
{
	self = [super initWithNibName: aNibName bundle: aBundle objectGraphContext: aContext];
	if (nil == self)
		return nil;

	_relationshipValueTransformer = [self newRelationshipValueTransformer];
	_imageValueTransformer = [self newImageValueTransformer];
	_typeValueTransformer = [self newTypeValueTransformer];
	return self;
}

- (void) didChangeContent: (ETLayoutItemGroup *)oldContent
                toContent: (ETLayoutItemGroup *)newContent
{
	if (oldContent != nil)
	{
		[self stopObserveObject: [oldContent itemForIdentifier: @"browser"]
		    forNotificationName: ETItemGroupSelectionDidChangeNotification];
	}
	if (newContent != nil)
	{
		[self startObserveObject: [newContent itemForIdentifier: @"browser"]
		     forNotificationName: ETItemGroupSelectionDidChangeNotification
		                selector: @selector(browserSelectionDidChange:)];
	}
}

- (BOOL) isStandaloneInspector
{
	return (_documentContentItem == nil);
}

- (ETLayoutItemGroup *) bodyItem
{
	return (id)[[self content] itemForIdentifier: @"inspectorBody"];
}

- (ETLayoutItemGroup *) objectPickerItem
{
	return (id)[[self content] itemForIdentifier: @"objectPicker"];
}

- (ETLayoutItemGroup *) contentAreaItem
{
	return (id)[[self content] itemForIdentifier: @"contentArea"];
}

- (ETLayoutItem *) documentContentItem
{
	if ([self isStandaloneInspector])
	{
		ETAssert([[self browserItem] representedObject] != nil);
		return [[self browserItem] representedObject];
	}
	return _documentContentItem;
}

- (void) presentTransientEditingAlertIfNeededForItem: (ETLayoutItem *)anItem
{
	if ([anItem persistentUIItem] != nil)
		return;

	NSString *msg = _(@"This UI item doesn't support persisting UI editing "
		"for the current application.");
	NSString *extra = _(@"You can explicitly save UI changes in a new document, "
						"but the changes won't be visible on the next application launch.");

	NSAlert *alert = [NSAlert alertWithMessageText: msg defaultButton: nil
		alternateButton: nil otherButton: nil informativeTextWithFormat: @""];
	[alert setInformativeText: extra];

	[alert runModal];
}

- (void) preparePersistentItemForDocumentContentItem: (ETLayoutItem *)anItem
{
	if ([anItem isPersistent])
	{
		ETAssert([[self persistentObjectContext] hasChanges]);
		/* If the item was persistent, we don't want to commit changes resulting 
		   from presenting the item into the editor (e.g. persistent frame and 
		   autoresizing mask). */
		[[self persistentObjectContext] discardAllChanges];
		return;
	}

	ETLayoutItem *persistentUIItem = [anItem persistentUIItem];

	ETLog(@" === Turned %@ into a persistent UI === ", [persistentUIItem shortDescription]);

	COPersistentRoot *persistentUI = [(id)[self persistentObjectContext]
		insertNewPersistentRootWithRootObject: persistentUIItem];
	[[ETApp UIStateRestoration] setPersistentItemUUID: [persistentUI UUID]
	                                          forName: [persistentUIItem persistentUIName]];
}

- (void) setDocumentContentItem: (ETLayoutItem *)anItem
{
	[self presentTransientEditingAlertIfNeededForItem: anItem];

	if (_documentContentItem != nil)
	{
		[self stopObserveObject: _documentContentItem
		    forNotificationName: ETItemGroupSelectionDidChangeNotification];		
	}
	_documentContentItem = anItem;
	[self preparePersistentItemForDocumentContentItem: anItem];

	if (anItem != nil)
	{
		[self startObserveObject: [self documentContentItem]
		     forNotificationName: ETItemGroupSelectionDidChangeNotification
		                selector: @selector(documentContentItemSelectionDidChange:)];
	}
}

- (ETLayoutItemGroup *) aspectPaneItem
{
	return (id)[[self aspectInspectorItem] itemForIdentifier: @"basicInspectorContent"];
}

- (ETLayoutItemGroup *) aspectInspectorHeaderItem
{
	return (id)[[self aspectInspectorItem] itemForIdentifier: @"basicInspectorHeader"];
}

- (ETLayoutItem *) typeFieldItem
{
	return (id)[[self aspectInspectorHeaderItem] itemForIdentifier: @"typeField"];
}

- (NSArray *) selectedObjects
{
	return [[[[self browserItem] selectedItemsInLayout] mappedCollection] representedObject];
}

- (void) browserSelectionDidChange: (NSNotification *)aNotif
{
	ETLog(@"Did change selection in %@", [aNotif object]);

	if (_isChangingSelection)
		return;

	_isChangingSelection = YES;

	NSArray *selectionIndexPaths = [[self browserItem] selectionIndexPaths];

	if ([self isStandaloneInspector] == NO)
	{
		[(ETLayoutItemGroup *)[[self documentContentItem] ifResponds] setSelectionIndexPaths: selectionIndexPaths];
	}
	[self didChangeSelectionToIndexPaths: selectionIndexPaths];
	
	_isChangingSelection = NO;
}

- (void) documentContentItemSelectionDidChange: (NSNotification *)aNotif
{
	ETLog(@"Did change selection in %@", [aNotif object]);

	if (_isChangingSelection || [self isStandaloneInspector])
		return;

	_isChangingSelection = YES;

	NSArray *selectionIndexPaths = (NSArray *)[[[self documentContentItem] ifResponds] selectionIndexPaths];

	if (selectionIndexPaths == nil)
	{
		selectionIndexPaths = @[];
	}
	[[self browserItem] setSelectionIndexPaths: selectionIndexPaths];
	[self didChangeSelectionToIndexPaths: selectionIndexPaths];

	_isChangingSelection = NO;
}

- (void) didChangeSelectionToIndexPaths: (NSArray *)indexPaths
{
	NSParameterAssert(indexPaths != nil);
	[self changeAspectPaneFromPopUp: nil];
}

- (id) inspectedObject
{
	NSArray *selectedObjects = [self selectedObjects];
	BOOL isSingleSelection = ([selectedObjects count] == 1);
	BOOL isMultipleSelection = ([selectedObjects count] > 1);
	
	if (isSingleSelection)
	{
		return [selectedObjects firstObject];
	}
	else if (isMultipleSelection)
	{
		// TODO: Implement a proxy that provides an union view over several
		// model objects for editing
		return [selectedObjects firstObject];
	}
	else
	{
		return [[self browserItem] representedObject];
	}
}

- (void) showItem: (ETLayoutItem *)anItem
{
	if ([[self bodyItem] containsItem: anItem])
		return;

	[[self bodyItem] addItem: anItem];
}

- (void) hideItem: (ETLayoutItem *)anItem
{
	if ([[self bodyItem] containsItem: anItem] == NO)
		return;
	
	[[self bodyItem] removeItem: anItem];
}

- (void) changePresentationViewToMenuItem: (NSMenuItem *)aMenuItem
{
	ETAssert(_browserItem != nil);
	ETAssert(_aspectInspectorItem != nil);

	if ([[aMenuItem title] isEqual: _(@"Browser")])
	{
		[self showItem: _browserItem];
		[self hideItem: _aspectInspectorItem];
	}
	else if ([[aMenuItem title] isEqual: _(@"Inspector")])
	{
		[self hideItem: _browserItem];
		[self showItem: _aspectInspectorItem];
	}
	else if ([[aMenuItem title] isEqual: _(@"Browser and Inspector")])
	{
		[self showItem: _browserItem];
		[self showItem: _aspectInspectorItem];
	}
	else
	{
		ETAssertUnreachable();
	}
}

- (IBAction) changePresentationViewFromPopUp: (id)sender
{
	ETAssert(_viewPopUpItem != nil);
	[self changePresentationViewToMenuItem: (NSMenuItem *)[[_viewPopUpItem view] selectedItem]];
}

- (id) typeObjectForAspectName: (NSString *)aspectName ofObject: (id)anObject
{
	if ([aspectName isEqual: @"valueTransformers"])
	{
		return @" - ";
	}
	return [ETMutableObjectViewpoint viewpointWithName: aspectName
		                             representedObject: anObject];
}

- (NSString *) currentAspectName
{
	ETAssert(_aspectPopUpItem != nil);
	return [[[_aspectPopUpItem view] selectedItem] representedObject];
}

- (void) reloadAspectPane
{
	ETAssert([self itemFactory] != nil);
	ETLayoutItemGroup *newAspectPaneItem =
		[[self itemFactory] basicInspectorContentWithObject: [self inspectedObject]
		                                         controller: self
		                                         aspectName: [self currentAspectName]];

	[newAspectPaneItem setWidth: [[self aspectInspectorItem] width]];
	[[self aspectInspectorItem] removeItem: [self aspectPaneItem]];
	[[self aspectInspectorItem] addItem: newAspectPaneItem];
}

- (void) reloadTypeField
{
	ETAssert([self typeFieldItem] != nil);
	// FIXME: Won't work with ETTool because the aspect name is a key path
	id typeObject = [self typeObjectForAspectName: [self currentAspectName]
	                                     ofObject: [self inspectedObject]];

	[[self typeFieldItem] setRepresentedObject: typeObject];
}

- (IBAction) changeAspectPaneFromPopUp: (id)sender
{
	[self reloadAspectPane];
	[self reloadTypeField];
}

- (IBAction) changeAspectRepositoryFromPopUp: (id)sender
{
	
}

- (BOOL) isEditingUI
{
	ETTool *documentContentTool = [[[self documentContentItem] layout] attachedTool];
	return ([self isStandaloneInspector] == NO
		&& [documentContentTool isKindOfClass: [ETSelectTool class]]);
}

- (IBAction) toggleTestUI: (id)sender
{
	NSParameterAssert([sender isKindOfClass: [ETLayoutItem class]]);
	ETAssert([self isStandaloneInspector] == NO);

	BOOL beginTestUI = [self isEditingUI];

	// TODO: We should attach the editing tool and switch it on
	// -contentAreaItem rather than -documentContentItem
	if (beginTestUI)
	{
		[[[self documentContentItem] layout] setAttachedTool:
			[ETArrowTool toolWithObjectGraphContext: [[self documentContentItem] objectGraphContext]]];
	
		[sender setIcon: [[IKIcon iconWithIdentifier: @"media-playback-stop"] image]];
		[sender setTitle: _(@"Stop Test")];
		[sender sizeToFit];
	}
	else /* end test UI */
	{
		ETSelectTool *editionTool = [ETSelectTool toolWithObjectGraphContext:
			[[self documentContentItem] objectGraphContext]];
		
		// NOTE: See -[ETFreeLayout init]
		[editionTool setShouldProduceTranslateActions: YES];
		[[[self documentContentItem] layout] setAttachedTool: editionTool];

		[sender setIcon: [[IKIcon iconWithIdentifier: @"media-playback-start"] image]];
		[sender setTitle: _(@"Test")];
		[sender sizeToFit];
	}
}

- (id <ETUIBuilderEditionCoordinator>) editionCoordinator
{
	return self;
}

- (ETItemValueTransformer *) newTypeValueTransformer
{
	ETItemValueTransformer *transformer =
		(id)[ETItemValueTransformer valueTransformerForName: @"UIBuilderType"];

	if (transformer != nil)
		return transformer;

	transformer = [[ETItemValueTransformer alloc] initWithName: @"UIBuilderType"];

	[transformer setTransformBlock: ^id (id value, NSString *key, ETLayoutItem *item)
	{
		NSString *aspectName = [[value ifResponds] instantiatedAspectName];

		return (aspectName != nil ? aspectName : NSStringFromClass([value class]));
	}];

	[transformer setReverseTransformBlock: ^id (id value, NSString *key, ETLayoutItem *item)
	{
		if ([value isEqual: @""] || [value isEqual: @"nil"] || [value isEqual: @"Nil"])
			return nil;

		id controller = [[item controllerItem] controller];

		if ([self conformsToProtocol: @protocol(ETUIBuilderEditionCoordinator)] == NO)
			return nil;

		ETAspectCategory *category = [[controller aspectRepository] aspectCategoryNamed: key];
		id aspect = [category aspectForKey: value];

		/* For instantiating an aspect such as a ETController, 
		   that points to other aspects that can be shared instances (for 
		   example the cover style of [ETItemTemplate item]) */
		if (aspect == nil)
		{
			aspect = [[NSClassFromString(value) alloc]
				initWithObjectGraphContext: [COObjectGraphContext objectGraphContext]];
		}
		
		return aspect;
	}];

	return transformer;
}

- (ETItemValueTransformer *) newRelationshipValueTransformer
{
	ETItemValueTransformer *transformer =
		(id)[ETItemValueTransformer valueTransformerForName: @"UIBuilderRelationship"];

	if (transformer != nil)
		return transformer;

	transformer = [[ETItemValueTransformer alloc] initWithName: @"UIBuilderRelationship"];

	[transformer setTransformBlock: ^id (id value, NSString *key, ETLayoutItem *item)
	{
		if ([key isEqual: @"target"])
		{
			return [value identifier];
		}
		else
		{
			return [[value ifResponds] instantiatedAspectName];
		}
	}];

	[transformer setReverseTransformBlock: ^id (id value, NSString *key, ETLayoutItem *item)
	{
		if ([value isEqual: @""] || [value isEqual: @"nil"] || [value isEqual: @"Nil"])
			return nil;

		id controller = [[[item controllerItem] controller] editionCoordinator];

		if ([controller conformsToProtocol: @protocol(ETUIBuilderEditionCoordinator)] == NO)
			return nil;

		if ([key isEqual: @"target"])
		{
			if ([[controller documentContentItem] isGroup] == NO)
				return nil;

			return [[[controller documentContentItem] ifResponds] itemForIdentifier: value];

		}
		else
		{
			ETAspectCategory *category = [[controller aspectRepository] aspectCategoryNamed: key];
			return [category aspectForKey: value];
		}
	}];

	return transformer;
}

- (ETItemValueTransformer *) newImageValueTransformer
{
	ETItemValueTransformer *transformer =
		(id)[ETItemValueTransformer valueTransformerForName: @"UIBuilderImage"];

	if (transformer != nil)
		return transformer;

	transformer = [[ETItemValueTransformer alloc] initWithName: @"UIBuilderImage"];

	[transformer setTransformBlock: ^id (id value, NSString *key, ETLayoutItem *item)
	{
		NSParameterAssert([value isKindOfClass: [NSImage class]]);
		return [value name];
	}];

	[transformer setReverseTransformBlock: ^id (id value, NSString *key, ETLayoutItem *item)
	{
		if ([value isEqual: @""] || [value isEqual: @"nil"] || [value isEqual: @"Nil"])
			return nil;

		NSImage *image = [NSImage imageNamed: value];
		
		if (image == nil)
		{
			image = [[NSImage alloc] initWithContentsOfFile: value];
		}
		return image;
	}];

	return transformer;
}

- (ETObjectValueFormatter *) typeValueFormatter
{
	ETObjectValueFormatter *formatter = [ETObjectValueFormatter new];
	[formatter setName: @"type"];
	[formatter setDelegate: self];
	return formatter;
}

- (ETObjectValueFormatter *) relationshipValueFormatter
{
	ETObjectValueFormatter *formatter = [ETObjectValueFormatter new];
	[formatter setName: @"relationship"];
	[formatter setDelegate: self];
	return formatter;
}

- (ETObjectValueFormatter *) imageValueFormatter
{
	ETObjectValueFormatter *formatter = [ETObjectValueFormatter new];
	[formatter setName: @"image"];
	[formatter setDelegate: self];
	return formatter;
}

- (ETItemValueTransformer *) valueTransformerForFormatter: (ETObjectValueFormatter *)aFormatter
{
	return [self valueForKey: [[aFormatter name] stringByAppendingString: @"ValueTransformer"]];
}

/* There is no need to implement -formatter:stringForObjectValue: because
   -[ETLayoutItem valueForProperty:] does the transformation through
   -[ETLayoutItem valueTransformerForProperty:]. */
- (NSString *) formatter: (ETObjectValueFormatter *)aFormatter stringValueForString: (id)aValue
{
	BOOL isEditing = ([self editedProperty] != nil);

	/* The empty string is a valid value so we don't return nil (the value represents nil) */
	if ([aValue isEqual: @""] || isEditing == NO)
		return aValue;

	ETItemValueTransformer *valueTransformer = [self valueTransformerForFormatter: aFormatter];
	id result = [valueTransformer reverseTransformedValue: aValue
	                                               forKey: [self editedProperty]
	                                               ofItem: [self editedItem]];
	return (result != nil ? aValue : nil);
}

- (ETPropertyDescription *)propertyDescriptionForName: (NSString *)aName
                                           editedItem: (ETLayoutItem *)anItem
{
	ETModelDescriptionRepository *repo = [[[self persistentObjectContext] editingContext] modelDescriptionRepository];
	ETEntityDescription *entityDesc = [repo entityDescriptionForClass: [anItem subject]];
	
	return [entityDesc propertyDescriptionForName: aName];
}

- (void) subjectDidEndEditingForItem: (ETLayoutItem *)anItem property: (NSString *)aKey
{
	// TODO: For the inspector, detect if the item argument is not a meta-item.
	[super subjectDidEndEditingForItem: anItem property: aKey];
	
	if ([anItem isEqual: [self typeFieldItem]])
	{
		[self reloadAspectPane];
	}

	ETLayoutItem *editedObject = ([[anItem subject] conformsToProtocol: @protocol(ETPropertyViewpoint)] ? [[anItem subject] representedObject] : [anItem representedObject]);
	
	/* For properties such as autoresizingMask or contentAspect that doesn't 
	   mark the item as needing a redisplay on a change. */
	[[editedObject ifResponds] setNeedsDisplay: YES];
	/* For aspect properties such -[ETBasicItemStyle labelPosition], we need to 
	   mark the selected objects (selected items in -documentContentItem) as
	   needing a redisplay on a change. */
	[[[self selectedObjects] mappedCollection] setNeedsDisplay: YES];

	if ([editedObject isPersistent] == NO)
		return;

	NSDictionary *metadata = @{ kCOCommitMetadataTypeDescription: @"Property Change",
	                           kCOCommitMetadataShortDescription: @"Edited property %@",
	                  kCOCommitMetadataShortDescriptionArguments: aKey };
	COError *error = nil;

	[[[self persistentObjectContext] editingContext]
		commitWithIdentifier: kETCommitEditProperty metadata: metadata undoTrack: nil error: &error];
	ETAssert(error = nil);
}

- (void) didBecomeFocusedItem: (ETLayoutItem *)anItem
{
	
}

- (void) didResignFocusedItem: (ETLayoutItem *)anItem
{
	
}

@end
