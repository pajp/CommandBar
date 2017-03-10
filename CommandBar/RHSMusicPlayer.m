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
    AUNode synthNode, limiterNode, outNode;
    
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
    
    _rhs_require_noerr (result = AUGraphAddNode (*outGraph, &cd, &limiterNode), home);
    
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
int allNotes[42];
char charNotes[43];

@implementation RHSMusicPlayer

- (id) init {
    self = [super init];
    [self setupMidi];

    // 6 octaves, 7 major notes per octave = 42 notes
    // third octave = middle C, MIDI note 60
    for (int octave=0; octave < 6; octave++) {
        for (int majorNote=0; majorNote < 7; majorNote++) {
            int noteIndex = octave*7+majorNote;
            int noteValue = majorscale[majorNote] + 12*octave + 36;
            allNotes[noteIndex] = noteValue;
            charNotes[noteIndex] = majorscale_char[majorNote];
            printf("\nNote index %2d, MIDI note %3d, pitch %c, scale note %d", noteIndex, noteValue, charNotes[noteIndex], majorNote);
            printf("");
            
        }
    }
    charNotes[42] = 0;
    printf("\n\n");
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

- (void) playNote:(int) noteNum {
    OSStatus result = 0;

    UInt32 onVelocity = 127;
    UInt32 noteOnCommand  = kMidiMessage_NoteOn << 4 | midiChannelInUse;
    UInt32 noteOffCommand = kMidiMessage_NoteOff << 4 | midiChannelInUse;
    
    NSLog (@"Playing Note: Status: 0x%X Note: %u, Vel: %u\n", (unsigned int)noteOnCommand, (unsigned int)noteNum, (unsigned int)onVelocity);
    
    _rhs_require_noerr (result = MusicDeviceMIDIEvent(synthUnit, noteOnCommand, noteNum, onVelocity, 0), home);

    // turn off note after n seconds. If the same note is played several times before n seconds has elapsed
    // the note off command is still sent after n seconds, which will cause inconsistent sustain
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        OSStatus _result = MusicDeviceMIDIEvent(synthUnit, noteOffCommand, noteNum, 0, 0);
        if (_result != 0) {
            NSLog(@"%s: OSStatus %d", __func__, result);
        }
    });
home:
    if (result != 0) {
        NSLog(@"%s: OSStatus %d", __func__, result);
    }
    
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

- (void) playMajorNoteFromFraction:(float) fraction {
    if (fraction > 1.0) fraction = 1.0;
    if (fraction < 0.0) fraction = 0.0;
    
    int noteIndex = 41 * fraction;
    NSLog(@"Fraction %f -> note index %d -> note %d (%c)", fraction, noteIndex, allNotes[noteIndex], charNotes[noteIndex]);
    [self playNote:allNotes[noteIndex]];
}

- (void) dealloc {
    if (graph) {
        AUGraphStop (graph); // stop playback - AUGraphDispose will do that for us but just showing you what to do
        DisposeAUGraph (graph);
    }
}
@end
