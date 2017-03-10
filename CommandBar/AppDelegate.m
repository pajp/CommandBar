//
//  AppDelegate.m
//  CommandBar
//
//  Created by Rasmus Sten on 02-12-2016.
//  Copyright © 2016 Rasmus Sten. All rights reserved.
//

#import "AppDelegate.h"
#import "RHSMusicPlayer.h"
#import "RHSCommandWindow.h"

@interface AppDelegate ()

@property (weak) IBOutlet RHSCommandWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

}


- (NSMenu*) applicationDockMenu:(NSApplication *)sender {
    NSMenu* menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Hello" action:nil keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"World" action:nil keyEquivalent:@""]];
    return menu;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
