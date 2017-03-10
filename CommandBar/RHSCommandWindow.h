//
//  RHSCommandWindow.h
//  CommandBar
//
//  Created by Rasmus Sten on 02-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RHSSwipeView.h"
#import "RHSMusicPlayer.h"

@interface RHSCommandWindow : NSWindow <NSTouchBarDelegate, NSTouchBarProvider>
@property RHSSwipeView* swipeView;
@property (weak) IBOutlet RHSSwipeView *swipeViewOnScreen;
@property RHSMusicPlayer* musicPlayer;
@end
