/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  February 2013
    License:  Modified BSD (see COPYING)
 */

#import "TestCommon.h"
#import "ETApplication.h"
#import "ETLayoutItemGroup.h"
#import "ETLayoutItemFactory.h"
#import "ETLayoutItem.h"

@interface TestItemProvider : TestCommon <UKTest>
{
	ETLayoutItemGroup *itemGroup;
}

@end


@implementation TestItemProvider

- (id) init
{
	SUPERINIT
	itemGroup = [itemFactory itemGroup];
	return self;
}

- (void) testAutoboxingWithCommonObjectValues
{
	[itemGroup addObject: [NSImage imageNamed: @"pin"]];
	[itemGroup addObject: @"Blue"];
	[itemGroup addObject: [NSNumber numberWithInt: 3]];
	
	ETLayoutItem *imgItem = [itemGroup itemAtIndex: 0];
	ETLayoutItem *stringItem = [itemGroup itemAtIndex: 1];
	ETLayoutItem *numberItem = [itemGroup itemAtIndex: 2];

	UKObjectsEqual([[NSImage imageNamed: @"pin"] name], [[imgItem value] name]);
	UKObjectsEqual(@"Blue", [stringItem value]);
	UKObjectsEqual([NSNumber numberWithInt: 3], [numberItem value]);

	UKObjectsSame([imgItem value], [imgItem representedObject]);
	UKObjectsSame([stringItem value], [stringItem representedObject]);
	UKObjectsSame([numberItem value], [numberItem representedObject]);
}
	 
- (void) testAutoboxingWithRepresentedObject
{
	id randomObject = [NSObject new];
	id randomCollection = [NSArray array];

	[itemGroup addObject: randomObject];
	[itemGroup addObject: randomCollection];

	ETLayoutItem *objectItem = [itemGroup itemAtIndex: 0];
	ETLayoutItem *collectionItem = [itemGroup itemAtIndex: 1];

	UKNotNil([objectItem representedObject]);
	UKObjectsSame([objectItem representedObject], [objectItem value]);
	UKFalse([objectItem isGroup]);

	UKNotNil([collectionItem representedObject]);
	UKObjectsSame([collectionItem representedObject], [collectionItem value]);
	UKTrue([collectionItem isGroup]);
}

@end
