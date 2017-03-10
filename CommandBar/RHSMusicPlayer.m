//
//  RHSMusicPlayer.m
//  CommandBar
//
//  Created by Rasmus Sten on 10-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//
// see https://developer.apple.com/library/content/samplecode/PlaySoftMIDI/Introduction/Intro.html#//apple_ref/doc/uid/DTS40008635-Intro

#import "RHSMusicPlayer.h"


#include <CoreServices/CoreServices.h> //for file stuff
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h> //for AUGraph
#include <unistd.h> // used for usleep...

// see https://github.com/AFNetworking/AFNetworking/commit/de8b20ff4b48542be0697304226de20d9cccf553
#ifndef _rhs_require_noerr
       #define _rhs_require_noerr(errorCode, exceptionLabel)                      \
          do {                                                                    \
              if (__builtin_expect(0 != (errorCode), 0)) {                        \
                  goto exceptionLabel;                                            \
              }                                                                   \
          } while (0)
#endif

// This call creates the Graph and the Synth unit...
OSStatus	CreateAUGraph (AUGraph* outGraph, AudioUnit* outSynth)
{
    OSStatus result;
    //create the nodes of the graph
    AUNode synthNode, outNode;
    
    AudioComponentDescription cd;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    
    _rhs_require_noerr (result = NewAUGraph (outGraph), home);
    
    cd.componentType = kAudioUnitType_MusicDevice;
    cd.componentSubType = kAudioUnitSubType_DLSSynth;
    
    _rhs_require_noerr (result = AUGraphAddNode (*outGraph, &cd, &synthNode), home);
    
    cd.componentType = kAudioUnitType_Effect;
    cd.componentSubType = kAudioUnitSubType_PeakLimiter;
    
//    _rhs_require_noerr (result = AUGraphAddNode (*outGraph, &cd, &limiterNode), home);
    
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_DefaultOutput;
    _rhs_require_noerr (result = AUGraphAddNode (*outGraph, &cd, &outNode), home);
    
    _rhs_require_noerr (result = AUGraphOpen (*outGraph), home);
    
    _rhs_require_noerr (result = AUGraphConnectNodeInput (*outGraph, synthNode, 0, outNode, 0), home);
    //	_rhs_require_noerr (result = AUGraphConnectNodeInput (outGraph, limiterNode, 0, outNode, 0), home);
    
    // ok we're good to go - get the Synth Unit...
    _rhs_require_noerr (result = AUGraphNodeInfo(*outGraph, synthNode, 0, outSynth), home);
    
home:
    return result;
}

// some MIDI constants:
enum {
    kMidiMessage_ControlChange 		= 0xB,
    kMidiMessage_ProgramChange 		= 0xC,
    kMidiMessage_BankMSBControl 	= 0,
    kMidiMessage_BankLSBControl		= 32,
    kMidiMessage_NoteOn 			= 0x9,
    kMidiMessage_NoteOff            = 0x8
};

int majorscale[] = {0, 2, 4, 5, 7, 9, 11};
char majorscale_char[] = { 'c', 'd', 'e', 'f', 'g', 'a', 'b', 0 };
@interface RHSMusicPlayer()
@property NSMutableDictionary* notesBeingPlayed;
@property NSMutableSet* cancelledNoteOffs;
@property NSDictionary* scales;
@property NSMutableArray* allNotes;
@end

@implementation RHSMusicPlayer

- (NSArray*) scale:(NSString*) scaleName forKey:(char) key {
    int keyOffset = 0;
    for (;keyOffset < sizeof(majorscale_char) && majorscale_char[keyOffset] == key; ++keyOffset);
    keyOffset--;
    NSArray* scaleReference = self.scales[scaleName];
    NSMutableArray* scale = [[NSMutableArray alloc] initWithCapacity:scaleReference.count];
    [scaleReference enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        scale[idx] = @( [scaleReference[idx] intValue] + keyOffset );
    }];
    NSLog(@"Scale %@ key %c: %@", scaleName, key, scale);
    return scale;
}

- (void) setScale:(NSString*) scaleKey {
    NSArray* keyAndScale = [scaleKey componentsSeparatedByString:@"-"];
    NSString* keyString = keyAndScale[0];
    const char* keyChars = [keyString cStringUsingEncoding:NSASCIIStringEncoding];
    char key = keyChars[0];

    // 6 octaves, 7 major notes per octave = 42 notes
    // starting at 36th MIDI note (4th octave from 0)
    NSArray* scale = [self scale:keyAndScale[1] forKey:key];
    self.allNotes = [NSMutableArray arrayWithCapacity:scale.count*6];
    for (int octave=0; octave < 6; octave++) {
        for (int scaleNote=0; scaleNote < scale.count; scaleNote++) {
            int noteIndex = octave * (int)scale.count + scaleNote;
            int noteValue = [scale[scaleNote] intValue] + 12*octave + 36;
            self.allNotes[noteIndex] = @(noteValue);
            printf("\nNote index %2d, MIDI note %3d", noteIndex, noteValue);
        }
    }
    printf("\n\n");

    NSLog(@"Scale set to %@", scaleKey);
}

- (id) init {
    self = [super init];
    self.notesBeingPlayed = [[NSMutableDictionary alloc] init];
    self.cancelledNoteOffs = [[NSMutableSet alloc] init];
    self.scales = @{ @"maj" : @[ @0, @2, @4, @5, @7, @9, @11 ],
                     @"min" : @[ @0, @2, @3, @5, @7, @8, @10 ],
                     @"blues" : @[ @0, @2, @3, @4, @5, @7, @9, @10, @11 ]
                     };

    [self setupMidi];
    [self setScale:@"c-maj"];
    fflush(stdout);
    return self;
}
AUGraph graph = 0;
AudioUnit synthUnit;
UInt8 midiChannelInUse = 0; //we're using midi channel 1...

- (OSStatus) setupMidi {
    OSStatus result;
    char* bankPath = 0;
    
    
    // this is the only option to main that we have...
    // just the full path of the sample bank...
    
    // On OS X there are known places were sample banks can be stored
    // Library/Audio/Sounds/Banks - so you could scan this directory and give the user options
    // about which sample bank to use...
    //    if (argc > 1)
    //        bankPath = const_cast<char*>(argv[1]);
    
    _rhs_require_noerr (result = CreateAUGraph (&graph, &synthUnit), home);
    
    // if the user supplies a sound bank, we'll set that before we initialize and start playing
    if (bankPath)
    {
        FSRef fsRef;
        _rhs_require_noerr (result = FSPathMakeRef ((const UInt8*)bankPath, &fsRef, 0), home);
        
        printf ("Setting Sound Bank:%s\n", bankPath);
        
        _rhs_require_noerr (result = AudioUnitSetProperty (synthUnit,
                                                           kMusicDeviceProperty_SoundBankFSRef,
                                                           kAudioUnitScope_Global, 0,
                                                           &fsRef, sizeof(fsRef)), home);
        
    }
    
    // ok we're set up to go - initialize and start the graph
    _rhs_require_noerr (result = AUGraphInitialize (graph), home);
    
    //set our bank
    _rhs_require_noerr (result = MusicDeviceMIDIEvent(synthUnit,
                                                      kMidiMessage_ControlChange << 4 | midiChannelInUse,
                                                      kMidiMessage_BankMSBControl, 0,
                                                      0/*sample offset*/), home);
    
    
    _rhs_require_noerr (result = MusicDeviceMIDIEvent(synthUnit,
                                                      kMidiMessage_ProgramChange << 4 | midiChannelInUse,
                                                      0/*prog change num*/, 0, // 57 = trumpet
                                                      0/*sample offset*/), home);
    
    CAShow (graph); // prints out the graph so we can see what it looks like...
    
    _rhs_require_noerr (result = AUGraphStart (graph), home);
home:
    return result;
}

int notePlayCount;
- (void) playNote:(int) noteNum {
    assert([NSThread isMainThread]);
    notePlayCount++;
    OSStatus result = 0;
    NSMutableDictionary* notesBeingPlayed = self.notesBeingPlayed;
    NSMutableSet* cancelledNoteOffs = self.cancelledNoteOffs;
    UInt32 onVelocity = 127;
    UInt32 noteOnCommand  = kMidiMessage_NoteOn << 4 | midiChannelInUse;
    UInt32 noteOffCommand = kMidiMessage_NoteOff << 4 | midiChannelInUse;
    
    NSLog (@"Playing Note: Status: 0x%X Note: %u, Vel: %u\n", (unsigned int)noteOnCommand, (unsigned int)noteNum, (unsigned int)onVelocity);
    result = MusicDeviceMIDIEvent(synthUnit, noteOnCommand, noteNum, onVelocity, 0);
    if (result != 0) {
        NSLog(@"%s: OSStatus %d", __func__, result);
        return;
    }
    
    
    if (self.notesBeingPlayed[@(noteNum)] != nil) {
        [cancelledNoteOffs addObject:notesBeingPlayed[@(noteNum)]];
        NSLog(@"%s: will add cancellation for note-off for note %d count %d, cancelled by count %d", __func__, noteNum, [notesBeingPlayed[@(noteNum)] intValue], notePlayCount);
    }
    notesBeingPlayed[@( noteNum )] = @(notePlayCount);
    
    int noteOffCount = notePlayCount;
    
    // turn off note after n seconds, unless the note off has been cancelled by the same note being played again
    // before
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([cancelledNoteOffs containsObject:@(noteOffCount)]) {
            NSLog(@"%s: cancelling note-off %d, count %d", __func__, noteNum, noteOffCount);
            [cancelledNoteOffs removeObject:@(noteOffCount)];
            return;
        }
        NSLog(@"%s note-off for note %d count %d", __func__, noteNum, noteOffCount);
        OSStatus _result = MusicDeviceMIDIEvent(synthUnit, noteOffCommand, noteNum, 0, 0);
        if (_result != 0) {
            NSLog(@"%s: OSStatus %d", __func__, result);
        }
        [notesBeingPlayed removeObjectForKey:@( noteNum )];
    });    
}

- (void) playMusic {
    OSStatus result = 0;
    // we're going to play an octave of MIDI notes: one a second
    for (int i = 13; i >= 0; i--) {
        UInt32 noteNum = i + 60;
        [self playNote:noteNum];
        usleep(NSEC_PER_MSEC/4);
    }
    
    // ok we're done now
    usleep(5*NSEC_PER_MSEC);
home:
    if (result != 0) {
        NSLog(@"OSStatus = %d", result);
    }
//    return result;
}

- (void) playScaleNoteFromFraction:(float) fraction {
    if (fraction > 1.0) fraction = 1.0;
    if (fraction < 0.0) fraction = 0.0;
    
    int noteIndex = 41 * fraction;
    NSLog(@"Fraction %f -> note index %d -> note %d", fraction, noteIndex, [self.allNotes[noteIndex] intValue]);
    [self playNote:[self.allNotes[noteIndex] intValue]];
}

- (void) dealloc {
    if (graph) {
        AUGraphStop (graph); // stop playback - AUGraphDispose will do that for us but just showing you what to do
        DisposeAUGraph (graph);
    }
}
@end
