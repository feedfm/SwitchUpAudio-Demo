//
//  ViewController.m
//  SwitchUp
//
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <FeedMedia/FeedMedia.h>
#import <UICircularProgressRing/UICircularProgressRing.h>
#import "UICircularProgressRing-Swift.h"
static void *PlayerItemContext = &PlayerItemContext;

NSString *const Phase1Label = @"Phase 1: Warm Up";
NSString *const Phase2Label = @"Phase 2: High Intensity";
NSString *const Phase3Label = @"Phase 3: Cooldown";

NSString *const Phase1Description = @"Low intensity warm up";
NSString *const Phase2Description = @"High/low intensity cycles";
NSString *const Phase3Description = @"Low intensity Cooldown";

float outOfPhase1Transition =  195.0;
float outOfPhase2Transition =  1780.0;


@interface ViewController ()

@property (nonatomic, strong) AVPlayer *workoutPlayer;
@property (nonatomic, strong) AVPlayerItem *playerItem;

@property (nonatomic, strong) id playerTimeObserver;
@property (nonatomic, strong) FMStationCrossfader *stationCrossfader;
@property (nonatomic, weak) FMAudioPlayer *musicPlayer;

@property (nonatomic, weak) IBOutlet UIImageView *backgroudImage;
@property (nonatomic, weak) IBOutlet UIButton *previousButton;
@property (nonatomic, weak) IBOutlet UIButton *playPauseButton;
@property (nonatomic, weak) IBOutlet UIButton *nextButton;
@property (nonatomic, weak) IBOutlet UIButton *muteMusicButton;
@property (nonatomic, weak) IBOutlet UIButton *musicNextButton;

@property (nonatomic, weak) IBOutlet UIPageControl *phaseIndicator;

@property (weak, nonatomic) IBOutlet UICircularProgressRing *progressRing;

@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UILabel *workoutLabel;

@property (weak, nonatomic) IBOutlet UILabel *workoutDescription;

@property (weak, nonatomic) IBOutlet UILabel *playPauseLabel;




@end

@implementation ViewController {

    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *workout = @"Spin_30_min";
    NSNumber *lowVolume = @0.2f;
    NSNumber *mediumVolume = @0.3f;
    NSArray *cuePoints = @[
                           // Welcome to the Feed.fm SwitchUp demo app. This app
                           // will demo how to use the Feed.fm SDK to integrate
                           // music into your app. Let's go with a
                           // relatively slow BPM station for the first 60 seconds.
                           @0.0f, lowVolume,
                           @0.0f, @{ @"bpm" : @"slow" },
                           @7.0f, mediumVolume,
                           
                           
                          
                           // Now let's speed up to a medium BPM for 20 seconds
                          
                           @200.0f, mediumVolume,
                           @199.0f, @{ @"bpm" : @"fast" },
                           
                           // Back down to medium for another 20 seconds
                           
                           @1780.0f, @{ @"bpm" : @"slow" },
                           
                           ];
    
    // queue up workout audio
    [self prepareWorkoutAudioAt: workout];
    
    // next action depends on music being available
    _musicPlayer = [FMAudioPlayer sharedPlayer];
    _progressRing.startAngle = 270;
    //_progressRing.tintColor = 
    [_musicPlayer whenAvailable:^{
        // we're displaying song info on the screen, so no need for these right now
        self.musicPlayer.disableSongStartNotifications = YES;
        // 4 second crossfade
        self.musicPlayer.secondsOfCrossfade = 4.0;
        
        
        // map time points in the song to different stations
        self.stationCrossfader = [FMStationCrossfader stationCrossfaderWithInitialStation: nil andCuePoints:cuePoints];
        [self.stationCrossfader connect];
        
        
    } notAvailable:^{
        // no music available
        
        // just set up workout controls
    }];
    
}
- (IBAction)skipCurrentItem:(id)sender {
    
    [_musicPlayer skip];
}


#pragma mark Music Controls

- (void) enableMusicControls {
    
    // watch for station and state changes, to update the station label button

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(musicStateChanged:) name:
     FMAudioPlayerPlaybackStateDidChangeNotification object:_musicPlayer];
    
   
}

- (void) musicStateChanged: (NSNotification *)notification {
    
}
#pragma mark Workout Controls


- (IBAction)workoutPlayPasueButtonWasTouched:(id)sender {
    if (self.playPauseButton.isSelected) {
        // user wants to pause
        [_workoutPlayer pause];
        [_stationCrossfader pause];
        [_playPauseLabel setText:@"Play"];
        self.playPauseButton.selected = NO;
        
    } else {
        // user wants to play
        [_workoutPlayer play];
        [_stationCrossfader play];
        [_playPauseLabel setText:@"Pause"];
        self.playPauseButton.selected = YES;
    }
}
- (IBAction)phaseIndicatorChanged:(id)sender {
    
}

#pragma mark Workout Audio Initialization

/*
 * Locate local workout audio clip and kick off preparing
 * it for playback.
 */
- (IBAction)nextPhaseButtonTouched:(id)sender {
    
    CMTime time = [_workoutPlayer currentTime];
    float seconds = (float) CMTimeGetSeconds(time);
    if(seconds < outOfPhase1Transition ) {
        // Phase 2
        CMTime interval = CMTimeMakeWithSeconds(outOfPhase1Transition, NSEC_PER_SEC);
        [_workoutPlayer seekToTime:interval];
        [self.workoutLabel setText:Phase2Label];
        [self.phaseIndicator setCurrentPage:1];
        [self.workoutDescription setText:Phase2Description];
        //[self.phaseIndicator ]
        
    }
    else if (seconds < outOfPhase2Transition){
        // Phase 3
        CMTime interval = CMTimeMakeWithSeconds(outOfPhase2Transition, NSEC_PER_SEC);
        [_workoutPlayer seekToTime:interval];
        [self.workoutLabel setText:Phase3Label];
        [self.phaseIndicator setCurrentPage:2];
        [self.workoutDescription setText:Phase3Description];
    }
   
}

- (IBAction)previousPhaseButton:(id)sender {
    CMTime time = [_workoutPlayer currentTime];
    float seconds = (float) CMTimeGetSeconds(time);
    if (seconds > outOfPhase2Transition){
        // Phase 2
        CMTime interval = CMTimeMakeWithSeconds(outOfPhase1Transition, NSEC_PER_SEC);
        [_workoutPlayer seekToTime:interval];
        [self.workoutLabel setText:Phase2Label];
        [self.phaseIndicator setCurrentPage:1];
        [self.workoutDescription setText:Phase2Description];
    }
    else if(seconds > outOfPhase1Transition) {
        // Phase 1
        CMTime interval = CMTimeMakeWithSeconds(0.0, NSEC_PER_SEC);
        [_workoutPlayer seekToTime:interval];
        [self.workoutLabel setText:Phase1Label];
        [self.phaseIndicator setCurrentPage:0];
        [self.workoutDescription setText:Phase1Description];
    }
}

- (IBAction)muteButtonTouched:(id)sender {
    if(![_muteMusicButton isSelected])
    {
        [_musicPlayer setMixVolume:0];
        _muteMusicButton.selected = YES;
    }
    else{
        [_musicPlayer setMixVolume:0.4];
        _muteMusicButton.selected = NO;
    }
}

- (void) prepareWorkoutAudioAt: (NSString *) audioResourcePath {
    NSString *audioPath = [NSBundle.mainBundle pathForResource:audioResourcePath ofType:@"mp3"];
    NSURL *audioURL = [NSURL fileURLWithPath:audioPath];
    _playerItem = [AVPlayerItem playerItemWithURL:audioURL];
    
    [_playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:&PlayerItemContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:_playerItem];

    _workoutPlayer = [AVPlayer playerWithPlayerItem:_playerItem];
    _workoutPlayer.volume = 1.0f;
}


-(void) itemDidFinishPlaying: (NSNotification *) notif{
    
    [_musicPlayer pause];
}

/*
 * Local workout audio clip is ready for playback. Adjust
 * slider extents to match clip duration, and create event
 * listeners to watch progress of playback.
 */

- (void)workoutAudioDidPrepare {
    // local workout audio is ready for playback.
    // watch playback elapse
    CMTime interval = CMTimeMake(5, 10); // every half second
    
    __weak ViewController *weakSelf = self;
    _playerTimeObserver = [_workoutPlayer addPeriodicTimeObserverForInterval:interval queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf workoutAudioCurrentTimeDidChange: time];
    }];
    
}

- (void) workoutAudioCurrentTimeDidChange: (CMTime) time {
    float seconds = (float) CMTimeGetSeconds(time);
    if(seconds < outOfPhase1Transition) {
        // Phase 1
        [self.workoutLabel setText:Phase1Label];
        [self.workoutDescription setText:Phase1Description];
        [self.phaseIndicator setCurrentPage:0];
    }
    else if (seconds > outOfPhase2Transition){
        // Phase 3
        [self.workoutLabel setText:Phase3Label];
        [self.workoutDescription setText:Phase3Description];
        [self.phaseIndicator setCurrentPage:2];
    }
    else {
        // Phase 2
        [self.workoutLabel setText:Phase2Label];
        [self.workoutDescription setText:Phase2Description];
        [self.phaseIndicator setCurrentPage:1];
        
    }
    self.progressRing.minValue = 0;
    self.progressRing.maxValue = (float) CMTimeGetSeconds(_playerItem.duration);
    self.progressRing.value = seconds;
    // NSLog(@"workout audio elapsed to %f, Music volume is %f", seconds, _musicPlayer.mixVolume);
    
    if (_musicPlayer.playbackState != FMAudioPlayerPlaybackStateUnavailable) {
        [_stationCrossfader elapseToTime:seconds];
    }
    [self updateElapsedAndRemainingLabelsForTime:seconds];
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

- (void) updateElapsedAndRemainingLabelsForTime: (float) time {
   
    long seconds = ((long) time % 60);
    long minutes = ((long) time / 60);
    [_timeLabel setText: [NSString stringWithFormat:@"%02ld:%02ld", minutes, seconds ]];
}

- (IBAction) startingEdit:(id) sender {
    [_workoutPlayer pause];
    _playPauseButton.selected = NO;
    
    if (_musicPlayer.playbackState != FMAudioPlayerPlaybackStateUnavailable) {
        [_musicPlayer pause];
    }
}

@end
