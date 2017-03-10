//
//  RHSMusicPlayer.h
//  CommandBar
//
//  Created by Rasmus Sten on 10-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RHSMusicPlayer : NSObject
- (void) playMusic;
- (void) playNote:(int) noteNum;
- (void) playMajorNoteFromFraction:(float) fraction;
@end

