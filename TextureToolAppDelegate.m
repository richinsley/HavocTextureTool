//
//  TextureToolAppDelegate.m
//  TextureTool
//
//  Created by Richard Insley on 9/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "TextureToolAppDelegate.h"

@implementation TextureToolAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
}

- (void) genUVButton:(id)sender
{
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    int width = [self->genUVWidth intValue];
    int height = [self->genUVHeight intValue];
    int bytesPerRow = (width * 8 + 63) & ~63;
    void * bitmapData = calloc(bytesPerRow * height, 1);
	long long unsigned * pixels = (long long unsigned *)bitmapData;
	
	for(int y = 0; y < height; y++)
	{
		for(int x = 0; x < width; x++)
		{
			// little endian ABGR
			// pixels[y * width + x] = 0xffff00000000ff00;
			unsigned short rx = (unsigned short)((((float)x) / ((float)width - 1.0)) * 65535.0);
			rx = (rx >> 8) | (rx << 8);
			unsigned short ry = (unsigned short)((((float)y) / ((float)height - 1.0)) * 65535.0);
			ry = (ry >> 8) | (ry << 8);
			pixels[y * width + x] = (0xffff000000000000 | rx | (ry << 16)) & 0xffff0000ffffffff;
		}
	}
	
    CGContextRef bitmapContext = CGBitmapContextCreate(bitmapData, width, height, 16 ,bytesPerRow, colorspace, kCGImageAlphaPremultipliedLast);
    NSGraphicsContext * graphicsContext = [[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO] retain];
    CGDataProviderRef bitmapContextDataProvider = CGDataProviderCreateWithData(nil, bitmapData, bytesPerRow * height, nil);
    CGImageRef bitmapImage = CGImageCreate(width,  
								height, 
								16, 
								64, 
								bytesPerRow, 
								colorspace, 
								kCGImageAlphaLast, 
								bitmapContextDataProvider, 
								nil, 
								false, 
								kCGRenderingIntentDefault);
    CGDataProviderRelease(bitmapContextDataProvider);
    CGColorSpaceRelease(colorspace);
	
	NSBitmapImageRep *bits = [[NSBitmapImageRep alloc] initWithCGImage:bitmapImage];

    NSSavePanel*    panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:@"output.png"];
    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton)
        {
            NSURL*  theFile = [panel URL];
            NSData *data;
            data = [bits representationUsingType: NSPNGFileType
                                      properties: nil];
            [data writeToFile: theFile.path
                   atomically: NO];
        }
    }];
}

void outputPng(NSString * file, void * buffer, int width, int height, int bytesPerRow)
{
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef bitmapContextDataProvider = CGDataProviderCreateWithData(nil, buffer, bytesPerRow * height, nil);
    CGImageRef bitmapImage = CGImageCreate(width,
                                           height,
                                           8,
                                           32,
                                           bytesPerRow,
                                           colorspace,
                                           kCGImageAlphaLast,
                                           bitmapContextDataProvider,
                                           nil,
                                           false,
                                           kCGRenderingIntentDefault);
    
    CFMutableDataRef pngdata = NULL;
    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault,0);
    if(data)
    {
        CGImageDestinationRef dest=CGImageDestinationCreateWithData(data, kUTTypePNG, 1, NULL);
        if(dest)
        {
            CGImageDestinationAddImage(dest, bitmapImage, NULL/*(CFDictionaryRef)options*/);
            
            if(CGImageDestinationFinalize(dest))
            {
                pngdata = (CFMutableDataRef)CFRetain(data);
            }
            
            CFRelease(dest);
        }
        CFRelease(data);
    }
    
    // save the data to the file
    if(pngdata)
    {
        int length = CFDataGetLength(pngdata);
        void * pptr = (void*)CFDataGetBytePtr(pngdata);
        NSData* dp = [NSData dataWithBytesNoCopy:pptr length:length];
        [dp writeToFile:file atomically:false];
        CFRelease(pngdata);
    }
}

- (void) convUVButton:(id)sender
{
	// Create the File Open Dialog class.
	NSOpenPanel* openDlg = [NSOpenPanel openPanel];
	
	// Enable the selection of files in the dialog.
	[openDlg setCanChooseFiles:YES];
	
	// Enable the selection of directories in the dialog.
	[openDlg setCanChooseDirectories:YES];
	
	// Display the dialog.  If the OK button was pressed,
	// process the files.
	if ( [openDlg runModalForDirectory:nil file:nil] == NSModalResponseOK )
	{
		NSArray* files = [openDlg filenames];
		NSString* fileName = [files objectAtIndex:0];
		
		NSImage *img = [[NSImage alloc] initWithContentsOfFile:fileName];
		NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc] initWithData:[img TIFFRepresentation]];
		int bpp = [bitmapImageRep bitsPerPixel];
		
		CGImageRef iref = [bitmapImageRep CGImage];
		int width = CGImageGetWidth(iref);
		int height = CGImageGetHeight(iref);
    
        // see if there is a mask file
        NSString* maskPath = [[[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"mask"] stringByAppendingPathExtension:@"png"];
        CGImageRef mref = NULL;
        NSBitmapImageRep * maskbitmapImageRep = NULL;
        NSImage * mimg = NULL;
        if([[NSFileManager defaultManager] fileExistsAtPath:maskPath])
        {
            mimg = [[NSImage alloc] initWithContentsOfFile:maskPath];
            maskbitmapImageRep = [[NSBitmapImageRep alloc] initWithData:[mimg TIFFRepresentation]];
            mref = [maskbitmapImageRep CGImage];
        }
        
		int bytesPerRow = (width * 4 + 63) & ~63;
        
		void * tbmd_u = calloc(bytesPerRow * height, 1);
        uint32_t * pixels_u = (uint32_t *)tbmd_u;
		
        void * tbmd_v = calloc(bytesPerRow * height, 1);
		uint32_t * pixels_v = (uint32_t *)tbmd_v;
        
		for(int y = 0; y < height; y++)
		{
			for(int x = 0; x < width; x++)
			{
				NSColor * pc = [bitmapImageRep colorAtX:x y:y];
				float u = [pc redComponent];
				float v = [pc greenComponent];
                
                uint32_t mask;
                if(mref)
                {
                    NSColor * mc = [maskbitmapImageRep colorAtX:x y:y];
                    mask = (int)([mc redComponent] * 255) << 16 | 0xff000000;
                }
                else
                {
                    mask = (int)([pc alphaComponent] * 255) << 16 | 0xff000000;
                }
                
                uint32_t other = 0xffff0000;
                
				uint16_t us = (uint16_t)(65535.0 * u);
				uint16_t vs = (uint16_t)(65535.0 * v);
				// ABGR
				// UL A
				// UH B
				// VL G
				// VH R

				//pixels_u[y * width + x] = ((us & 0x00ff) << 24) | ((us & 0xff00) << 8) | ((vs & 0x00ff) << 8) | ((vs & 0xff00) >> 8);
                
                pixels_u[y * width + x] = us | mask;
                pixels_v[y * width + x] = vs | other;
			}
		}
        
		//output pngs
        outputPng(@"/Users/rinsley/Desktop/test_u.png", tbmd_u, width, height, bytesPerRow);
        outputPng(@"/Users/rinsley/Desktop/test_v.png", tbmd_v, width, height, bytesPerRow);
	}
}

@end
