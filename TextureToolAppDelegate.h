//
//  TextureToolAppDelegate.h
//  TextureTool
//
//  Created by Richard Insley on 9/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TextureToolAppDelegate : NSObject <NSApplicationDelegate> 
{
    NSWindow *window;
	IBOutlet NSTextField * genUVWidth;
	IBOutlet NSTextField * genUVHeight;
}

@property (assign) IBOutlet NSWindow *window;

- (void) genUVButton:(id)sender;
- (void) convUVButton:(id)sender;
@end
