//
//  RHSBallView.m
//  CommandBar
//
//  Created by Rasmus Sten on 05-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//

#import "RHSBallView.h"

@implementation RHSBallView

- (id) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    self.wantsLayer = YES;
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    NSColor* c = [NSColor colorWithRed:0
                                 green:1.0
                                  blue:1.0
                                 alpha:1.0];
    [c setStroke];
    NSBezierPath* p = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1, 1, self.bounds.size.width-2, self.bounds.size.height-2)];
    [p stroke];
}

@end
