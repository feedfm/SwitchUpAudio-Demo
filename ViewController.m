//
//  ViewController.m
//  SwitchUp
//
//  Created by Eric Lambrecht on 9/21/17.
//  Copyright © 2017 Feed Media. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <FeedMedia/FeedMedia.h>

static void *PlayerItemContext = &PlayerItemContext;

@interface ViewController ()

@property (nonatomic, strong) AVPlayer *workoutPlayer;
@property (nonatomic, strong) AVPlayerItem *playerItem;

@property (nonatomic, strong) id playerTimeObserver;
@property (nonatomic, strong) FMStationCrossfader *stationCrossfader;
@property (nonatomic, weak) FMAudioPlayer *musicPlayer;

@property (nonatomic, weak) IBOutlet UISlider *slider;
@property (nonatomic, weak) IBOutlet UILabel *elapsed;
@property (nonatomic, weak) IBOutlet UILabel *remaining;

@property (nonatomic, weak) IBOutlet UIButton *workoutPlayPauseButton;

@property (nonatomic, weak) IBOutlet UIView *musicControls;
@property (nonatomic, weak) IBOutlet UIButton *musicPlayPauseButton;
@property (nonatomic, weak) IBOutlet UILabel *stationLabel;


@end

@implementation ViewController {

    BOOL _wasPlayingBeforeDrag;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSString *workout = @"erinworkout";
    NSNumber *lowVolume = @0.2f;
    NSNumber *highVolume = @0.8f;
    NSArray *cuePoints = @[
                           // Welcome to the Feed.fm SwitchUp demo app. This app
                           // will demo how to use the Feed.fm SDK to integrate
                           // music into your app. Let's go with a
                           // relatively slow BPM station for the first 60 seconds.
                           @0.0f, lowVolume,
                           @7.0f, @{ @"bpm" : @"slow" },
                           @15.0f, highVolume,
                           
                           // While music is playing, we can duck the volume so
                           // your audio doesn't get drowned out.
                           @21.0, lowVolume,
                           @26.0, highVolume,
                           
                           // Now let's speed up to a medium BPM for 20 seconds
                           @59.0f, lowVolume,
                           @65.0f, highVolume,
                           @65.0f, @{ @"bpm" : @"medium" },

                           // Now let's turn it up to 11 with a fast BPM for 20
                           // seconds
                           @80.0f, lowVolume,
                           @84.0f, @{ @"bpm" : @"fast" },
                           @84.0f, highVolume,
                           
                           // Back down to medium for another 20 seconds
                           @100.0f, lowVolume,
                           @104.0f, highVolume,
                           @104.0f, @{ @"bpm" : @"medium" },
                           
                           // Now fast again for 20 seconds
                           @120.0f, lowVolume,
                           @122.0f, @{ @"bpm" : @"fast" },
                           @123.0f, highVolume,
                           
                           // Now slow it back down for 40 seconds
                           @140.0f, lowVolume,
                           @144.0f, highVolume,
                           @143.0f, @{ @"bpm" : @"medium" },
                           
                           // End where we started with our low BPM station
                           @180.0f, lowVolume,
                           @184.0f, highVolume,
                           @184.0f, @{ @"bpm" : @"slow" }
                                ];
    
    // queue up workout audio
    [self prepareWorkoutAudioAt: workout];

    // next action depends on music being available
    _musicPlayer = [FMAudioPlayer sharedPlayer];

    [_musicPlayer whenAvailable:^{
        // we're displaying song info on the screen, so no need for these right now
        _musicPlayer.disableSongStartNotifications = YES;
        // 4 second crossfade
        _musicPlayer.secondsOfCrossfade = 4.0;
        
        [self enableWorkoutControls];
        
        // map time points in the song to different stations
        _stationCrossfader = [FMStationCrossfader stationCrossfaderWithInitialStation: nil andCuePoints:cuePoints];
        [_stationCrossfader connect];
        
        [self enableMusicControls];
        
    } notAvailable:^{
        // no music available
        
        // just set up workout controls
        [self enableWorkoutControls];
    }];

}


#pragma mark Music Controls

- (void) enableMusicControls {
    _musicControls.hidden = NO;
    
    // watch for station and state changes, to update the station label button
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stationOrStateChanged:) name:FMAudioPlayerActiveStationDidChangeNotification object:_musicPlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stationOrStateChanged:) name:
     FMAudioPlayerPlaybackStateDidChangeNotification object:_musicPlayer];

    [self updateStationLabel];
}

- (void) stationOrStateChanged: (NSNotification *) notification {
    [self updateStationLabel];
}

- (void) updateStationLabel {
    if ((_musicPlayer.playbackState == FMAudioPlayerPlaybackStateReadyToPlay) ||
        (_musicPlayer.playbackState == FMAudioPlayerPlaybackStateComplete)) {
        _stationLabel.text = @"";

    } else {
        _stationLabel.text = [NSString stringWithFormat:@"Now tuned to %@", _musicPlayer.activeStation.name];
    }
}

- (IBAction)musicPlayPauseWasTouched:(id)sender {
    // if the user pauses music playback (but not workout audio playback), then
    // we 'disconnect' the player so that music stays silent until the user
    // turns it back on again.
    
    if (!_musicPlayPauseButton.selected) {
        // user is pausing playback, so disconnect
        NSLog(@"user hit pause on music player, so disconnecting");
        [_stationCrossfader disconnect];
        
    } else {
        // user is resuming playback so reconnect
        NSLog(@"user hit play on music player, so reconnecting");
        [_stationCrossfader reconnect];
    }
}

#pragma mark Workout Controls

- (void) enableWorkoutControls {
    // disbled by default until we know wether we have music or not
    _workoutPlayPauseButton.enabled = YES;
}

- (IBAction)workoutPlayPasueButtonWasTouched:(id)sender {
    if (_workoutPlayPauseButton.isSelected) {
        // user wants to pause
        [_workoutPlayer pause];
        [_stationCrossfader pause];
        
        _workoutPlayPauseButton.selected = NO;
        
    } else {
        // user wants to play
        [_workoutPlayer play];
        [_stationCrossfader play];
        
        _workoutPlayPauseButton.selected = YES;
    }
}

#pragma mark Workout Audio Initialization

/*
 * Locate local workout audio clip and kick off preparing
 * it for playback.
 */

- (void) prepareWorkoutAudioAt: (NSString *) audioResourcePath {
    NSString *audioPath = [NSBundle.mainBundle pathForResource:audioResourcePath ofType:@"m4a"];
    NSURL *audioURL = [NSURL fileURLWithPath:audioPath];
    _playerItem = [AVPlayerItem playerItemWithURL:audioURL];
    
    [_playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:&PlayerItemContext];
    
    _workoutPlayer = [AVPlayer playerWithPlayerItem:_playerItem];
    _workoutPlayer.volume = 1.0f;
}

/*
 * Local workout audio clip is ready for playback. Adjust
 * slider extents to match clip duration, and create event
 * listeners to watch progress of playback.
 */

- (void)workoutAudioDidPrepare {
    // local workout audio is ready for playback.
    [_slider setMinimumValue:0.0f];
    [_slider setMaximumValue:(float) CMTimeGetSeconds(_playerItem.duration)];
    [_slider setValue:0];
    _slider.enabled = YES;
    _slider.continuous = YES;
    
    // watch playback elapse
    CMTime interval = CMTimeMake(5, 10); // every half second
    
    __weak ViewController *weakSelf = self;
    _playerTimeObserver = [_workoutPlayer addPeriodicTimeObserverForInterval:interval queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf workoutAudioCurrentTimeDidChange: time];
    }];
}

- (void) workoutAudioCurrentTimeDidChange: (CMTime) time {
    float seconds = (float) CMTimeGetSeconds(time);

    NSLog(@"workout audio elapsed to %f, volume is %f", seconds, _workoutPlayer.volume);

    [_slider setValue:seconds animated:NO];
    [self updateElapsedAndRemainingLabelsForTime:seconds];
    
    if (_musicPlayer.playbackState != FMAudioPlayerPlaybackStateUnavailable) {
        [_stationCrossfader elapseToTime:seconds];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    // Only handle observations for the PlayerItemContext
    if (context == &PlayerItemContext) {
        [self workoutAudioDidPrepare];
    }
}

#pragma mark Slider Handling

- (IBAction)sliderEndDrag:(id)sender {
    float time = _slider.value;
    [_workoutPlayer seekToTime:CMTimeMake((int) (time * 1000.0), 1000)];

    [_workoutPlayer play];
    _workoutPlayPauseButton.selected = YES;
}

- (IBAction)sliderDidChangeValue:(id)sender {
    [self updateElapsedAndRemainingLabelsForTime:_slider.value];
}

- (void) updateElapsedAndRemainingLabelsForTime: (float) time {
    float duration = (float) CMTimeGetSeconds(_playerItem.duration);
    
    long seconds = ((long) time % 60);
    long minutes = ((long) time / 60);
    
    [_elapsed setText: [NSString stringWithFormat:@"%ld:%02ld", minutes, seconds ]];
    
    long remainingSeconds = ((long) (duration - time) % 60);
    long remainingMinutes = ((long) (duration - time) / 60);
    
    [_remaining setText: [NSString stringWithFormat:@"%ld:%02ld", remainingMinutes, remainingSeconds ]];
}

- (IBAction) startingEdit:(id) sender {
    _wasPlayingBeforeDrag = (_workoutPlayer.rate > 0);
    
    [_workoutPlayer pause];
    _workoutPlayPauseButton.selected = NO;
    
    if (_musicPlayer.playbackState != FMAudioPlayerPlaybackStateUnavailable) {
        [_musicPlayer pause];
    }
}

@end
