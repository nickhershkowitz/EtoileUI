//
//  ContainerController.h
//  FlowAutolayoutExample
//
//  Created by Quentin Mathé on 28/05/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ETContainer.h"


@interface ContainerController : NSObject
{
    IBOutlet id viewContainer;
	NSMutableArray *images;
}

- (IBAction)choosePicturesAndLayout:(id)sender;
- (IBAction) changeLayout: (id)sender;
- (IBAction) switchUsesSource: (id)sender;
- (IBAction) switchUsesScrollView: (id)sender;
- (IBAction) scale: (id)sender;

- (NSArray *) imageViewsForImages: (NSArray *)images;
- (NSImageView *) imageViewForImage: (NSImage *)image;

// Private use
- (void)selectPicturesPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
- (void) setUpLayoutItemsDirectly;

@end
