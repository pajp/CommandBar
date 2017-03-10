//
//  RHSCommandWindow.m
//  CommandBar
//
//  Created by Rasmus Sten on 02-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//

#import "RHSCommandWindow.h"
#import <QuartzCore/QuartzCore.h>

@implementation RHSCommandWindow

- (id) initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag {
    self = [super initWithContentRect:contentRect styleMask:style backing:bufferingType defer:flag];
    self.musicPlayer = [RHSMusicPlayer new];
    return self;
}

- (NSTouchBar*) makeTouchBar {
    NSString* commandBarIdentifier = @"nu.dll.CommandBar";
    NSTouchBar* touchBar = [[NSTouchBar alloc] init];
    touchBar.delegate = self;
    touchBar.customizationIdentifier = commandBarIdentifier;
    touchBar.defaultItemIdentifiers = @[ commandBarIdentifier, NSTouchBarItemIdentifierOtherItemsProxy ];
    touchBar.customizationAllowedItemIdentifiers = @[ commandBarIdentifier ];
    touchBar.principalItemIdentifier = commandBarIdentifier;
    return touchBar;
}

- (void) cancelOperation:(id)sender {
    [self.swipeView removeBalls];
}

- (NSTouchBarItem*) touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    NSCustomTouchBarItem* item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
    /*
    NSButton* button = [NSButton buttonWithTitle:@"EHLO world" target:nil action:@selector(boo)];
    button.bezelColor = [NSColor greenColor];
    NSDictionary *attributesDictionary =
    @{
           NSForegroundColorAttributeName : [NSColor redColor],
           NSFontAttributeName : [NSFont fontWithName:@"American Typewriter" size:15.0],
           };
    NSMutableAttributedString *attributedString =
    [[NSMutableAttributedString alloc] initWithString:button.title attributes:attributesDictionary];
    [attributedString setAlignment:NSTextAlignmentCenter range:NSMakeRange(0, attributedString.length)];
    button.attributedTitle = attributedString;
    */
    self.swipeView = [[RHSSwipeView alloc] init];
    item.view = self.swipeView;
    self.swipeView.wantsLayer = YES;


    // This is for pan gesture recognizer to work.
    item.view.allowedTouchTypes = NSTouchTypeMaskDirect;
    
//    NSPanGestureRecognizer *panGesture = [[NSPanGestureRecognizer alloc] initWithTarget:self action:@selector(panAction:)];
//    panGesture.allowedTouchTypes = NSTouchTypeMaskDirect;
//    [item.view addGestureRecognizer:panGesture];
    
    NSPressGestureRecognizer* pressGesture = [[NSPressGestureRecognizer alloc] initWithTarget:self action:@selector(touchBarGestureAction:)];
    pressGesture.minimumPressDuration = 0;
    pressGesture.allowedTouchTypes = NSTouchTypeMaskDirect;
    [item.view addGestureRecognizer:pressGesture];
    
    NSPressGestureRecognizer* pressGuestureForWindow = [[NSPressGestureRecognizer alloc] initWithTarget:self action:@selector(windowGestureAction:)];
    pressGuestureForWindow.minimumPressDuration = 0;
    [self.contentView addGestureRecognizer:pressGuestureForWindow];
    
    return item;
}

- (void)playNoteAt:(float) fraction1 andThen:(float) fraction2 {
    [self.musicPlayer playMajorNoteFromFraction:fraction1];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.musicPlayer playMajorNoteFromFraction:fraction2];
        
    });
}

- (void)gestureAction:(NSGestureRecognizer*) sender forView:(RHSSwipeView*) view1 otherView:(RHSSwipeView*) view2 {
    if (sender.state != NSGestureRecognizerStateBegan &&
        sender.state != NSGestureRecognizerStateChanged) {
        NSLog(@"Ignoring gesture state %ld", (long)sender.state);
        return;
    }
    
    NSPoint location = [sender locationInView:view1];
    NSLog(@"Action for view %@: %@ @ x=%.f y=%.f", view1, sender, location.x, location.y);
    view1.ballLocation = CGPointMake(location.x, location.y);
    [view1 addBall:location];
    float touchBarRelativeX = location.x / view1.bounds.size.width;
    float touchBarRelativeXAtTop = (location.x+25.0) / view1.bounds.size.width;
    [self playNoteAt:touchBarRelativeX andThen:touchBarRelativeXAtTop];
    NSPoint otherViewLocation = location;
    float view1ToView2Ratio = view2.bounds.size.width / view1.bounds.size.width;
    otherViewLocation.x = otherViewLocation.x * view1ToView2Ratio;
    [view2 addBall:otherViewLocation];
}

- (void)touchBarGestureAction:(NSGestureRecognizer *)sender {
    [self gestureAction:sender forView:self.swipeView otherView:self.swipeViewOnScreen];
}

- (void)windowGestureAction:(NSGestureRecognizer *)sender {
    [self gestureAction:sender forView:self.swipeViewOnScreen otherView:self.swipeView];
}

@end
