//
//  RHSSwipeView.h
//  CommandBar
//
//  Created by Rasmus Sten on 03-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RHSBallView.h"

@interface RHSSwipeView : NSView

@property CGPoint ballLocation;
@property BOOL isAnimating;

- (void) addBall:(CGPoint) coordinates;
- (void) removeBalls;
@end
