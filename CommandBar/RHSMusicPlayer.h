//
//  RHSMusicPlayer.h
//  CommandBar
//
//  Created by Rasmus Sten on 10-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RHSMusicPlayer : NSObject
@property NSDictionary* scales;
@property NSMutableArray* allNotes;
- (void) playMusic;
- (void) playNote:(int) noteNum;
- (void) playScaleNoteFromFraction:(float) fraction;
- (void) setScale:(NSString*) scaleKey;
@end

