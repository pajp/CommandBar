//
//  ViewController.m
//  Pling Plong
//
//  Created by Rasmus Sten on 02-01-2018.
//  Copyright © 2018 Rasmus Sten. All rights reserved.
//

#import "ViewController.h"
#import "RHSMusicPlayer.h"

@interface ViewController ()
@property RHSMusicPlayer* musicPlayer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.musicPlayer = [RHSMusicPlayer new];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)floof:(id)sender {
    NSLog(@"hello…");
    [self.musicPlayer playMusic];
}

@end
