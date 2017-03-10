//
//  RHSSwipeView.m
//  CommandBar
//
//  Created by Rasmus Sten on 03-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//

#import "RHSSwipeView.h"
#import <QuartzCore/QuartzCore.h>

@interface RHSSwipeView()
@end

@implementation RHSSwipeView

NSMutableSet* balls;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [self setup];
    return self;
}

- (id) initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    [self setup];
    return self;
}

- (void) setup {
    balls = [[NSMutableSet alloc] init];
    self.wantsLayer = YES;
    self.layerUsesCoreImageFilters = YES;
    // allow the runloop to finish to get the backing layer setup
    dispatch_async(dispatch_get_main_queue(), ^{
        self.layer.backgroundColor = [NSColor blackColor].CGColor;
    });
}

- (void)setSegmentCount:(NSUInteger)segmentCount {
    _segmentCount = segmentCount;
    self.needsDisplay = YES;
    NSLog(@"New segment count: %lu", (unsigned long)_segmentCount);
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    [[NSColor redColor] setStroke];
    
    NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height) xRadius:4 yRadius:4];
    
    [p stroke];
    
    double segmentWidth = self.bounds.size.width / self.segmentCount;
    [[[NSColor whiteColor] colorWithAlphaComponent:0.2] setStroke];
    for (int i=0; i < self.segmentCount; i++) {
        p = [NSBezierPath bezierPath];
        [p moveToPoint:NSMakePoint(i*segmentWidth, 0)];
        [p lineToPoint:NSMakePoint(i*segmentWidth, self.bounds.size.height)];
        [p stroke];
//        NSLog(@"path %@", p);
    }
//
//    for (NSValue* obj in balls) {
//        NSPoint ballLocation = [obj pointValue];
//        p = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(ballLocation.x-5, self.bounds.size.height/2-5, 10, 10)];
//        [p stroke];
//    }
    
}

- (void) removeBalls {
    for (NSView* bv in balls) {
        [bv removeFromSuperview];
    }
    [balls removeAllObjects];
//    self.needsDisplay = YES;
}

- (void) removeBall:(NSView*) v {
    [v removeFromSuperview];
    [balls removeObject:v];
}

- (void) setupFadeAnimation:(NSView*) bv duration:(NSTimeInterval) duration {
    CABasicAnimation* b = [CABasicAnimation animationWithKeyPath:@"opacity"];
    b.fromValue = @( 1.0 );
    b.toValue = @( 0.0 );
    b.duration = duration;
    b.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [bv.layer addAnimation:b forKey:@"fade"];
    bv.layer.opacity = 0.0;
    
}
- (void) setupBlurAnimation:(NSView*) bv duration:(NSTimeInterval) duration {
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setDefaults];
    [blurFilter setValue:@(5.0) forKey:@"inputRadius"];
    [blurFilter setName:@"blur"];
    bv.layer.filters = @[ blurFilter ];
    
    CABasicAnimation* blurAnimation = [CABasicAnimation animation];
    
    blurAnimation.keyPath = @"filters.blur.inputRadius";
    blurAnimation.fromValue = @(0.0);
    blurAnimation.toValue = @(5.0);
    blurAnimation.duration = duration;
    
    [bv.layer addAnimation:blurAnimation forKey:@"blurAnimation"];
}

- (void) setupBounceAnimation:(NSView*) bv duration:(NSTimeInterval) duration coordinates:(CGPoint) coordinates {
    CABasicAnimation* a = [CABasicAnimation animationWithKeyPath:@"position.x"];
    a.fromValue = @( coordinates.x );
    a.toValue = @( coordinates.x + 50 );
    a.duration = duration;
    [bv.layer addAnimation:a forKey:@"slide"];
    
    CABasicAnimation* y1 = [CABasicAnimation animationWithKeyPath:@"position.y"];
    y1.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    y1.fromValue = @( 0 );
    y1.toValue = @(self.bounds.size.height-10);
    y1.duration = a.duration/2.0;
    
    CABasicAnimation* y2 = [CABasicAnimation animationWithKeyPath:@"position.y"];
    y2.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    y2.fromValue = @(self.bounds.size.height-10);
    y2.toValue = @( 0 );
    y2.duration = a.duration/2.0;
    
    
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        bv.frame = NSMakeRect(coordinates.x+50, 0, 10, 10);
        [bv.layer addAnimation:y2 forKey:@"ybounce2"];
    }];
    [bv.layer addAnimation:y1 forKey:@"ybounce1"];
    [CATransaction commit];

}

- (void) addBall:(CGPoint) coordinates {
    RHSBallView* bv = [[RHSBallView alloc] initWithFrame:NSMakeRect(coordinates.x+50, self.bounds.size.height-10, 10, 10)];
    [self addSubview:bv];
    [balls addObject:bv];
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        [self removeBall:bv];
    }];
    NSTimeInterval duration = 5.0;
    
    
    [self setupFadeAnimation:bv duration:duration];
//    [self setupBlurAnimation:bv duration:duration];
    [self setupBounceAnimation:bv duration:duration coordinates:coordinates];
    
    [CATransaction commit];
    self.needsDisplay = YES;
}


@end
