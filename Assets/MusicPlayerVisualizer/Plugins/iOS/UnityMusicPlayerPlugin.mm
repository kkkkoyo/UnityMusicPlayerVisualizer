//
//  UnityMusicPlayerPlugin.mm
//  UnityMPMusicPlayer
//

#import "UnityMusicPlayerPlugin.h"

#pragma mark - UnityMusicPlayerPlugin

extern UIViewController* UnityGetGLViewController();

extern "C" {
    void _unityMusicPlayer_load() {
        [UnityMusicPlayerPlugin.shared load:UnityGetGLViewController()];
    }
    
    void _unityMusicPlayer_play() {
        [UnityMusicPlayerPlugin.shared play];
    }

    double _unityMusicPlayer_currentTime() {
        return UnityMusicPlayerPlugin.shared.currentPlaybackTime;
    }

    double _unityMusicPlayer_level(int channel) {
        return [UnityMusicPlayerPlugin.shared getLevelWithChannel:channel];
    }
}

#pragma mark - UnityMusicPlayerPlugin

@interface UnityMusicPlayerPlugin()<MPMediaPickerControllerDelegate,AVAudioPlayerDelegate>
{
}
@property (atomic, strong) MPMusicPlayerController* player;
@property (atomic, weak) UIViewController* viewController;
- (void) showAlert:(NSString *)title alertMessage:(NSString *) message;
-(void) onPlaybackStateChanged:(int)state;
typedef NS_ENUM(NSInteger, PlaybackStateType) {
    Stopped = 0,
    Playing,
    Paused
};
@end

@implementation UnityMusicPlayerPlugin

static UnityMusicPlayerPlugin * _shared;
+ (UnityMusicPlayerPlugin*) shared {
    @synchronized(self) {
        if(_shared == nil) {
            _shared = [[self alloc] init];
        }
    }
    return _shared;
}

- (id) init {
    save_songTitle = @"";
    save_artist = @"";
    all_duration = 0.0;
    return self;
}

- (void) load:(UIViewController *)controller {
    self.viewController = controller;
    MPMediaPickerController *picker = [[MPMediaPickerController alloc] init];
    picker.delegate = self;
    picker.allowsPickingMultipleItems = NO;
    [controller presentViewController:picker animated:YES completion:nil];
}

- (void) play {
    if(avPlayer.playing) {
        [avPlayer pause];
        [self onPlaybackStateChanged: (PlaybackStateType)Paused];
    }
    else {
        [avPlayer play];
        [self onPlaybackStateChanged: (PlaybackStateType)Playing];
    }
}

- (void) selectedPicker {
    NSDictionary *json = @{
        @"title": UnityMusicPlayerPlugin.shared.title,
        @"artist": UnityMusicPlayerPlugin.shared.artist,
        @"duration": [NSNumber numberWithDouble:UnityMusicPlayerPlugin.shared.duration],
        @"currentTime": [NSNumber numberWithDouble:self.currentPlaybackTime],
        @"level": @0
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:nil];
    NSString* msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    UnitySendMessage("MusicPlayerPlugin", "OnItemChanged", msg.UTF8String);
}

- (double) currentPlaybackTime {
    double time = avPlayer.currentTime;
    return isnan(time) ? 0 : time;
}

-(NSString*) title {
    return save_songTitle;
}

-(NSString*) artist {
    return save_artist;
}

- (double) duration {
    return all_duration;
}

- (double) getLevelWithChannel:(int)channel {
    if(avPlayer != nil) {
        if(avPlayer.isPlaying) {
            [avPlayer updateMeters];
            double db = [avPlayer averagePowerForChannel:channel];
            double power = pow(10, (0.05 * db));
            return power;
        }
    }
    return 0.0;
}

- (void) showAlert:(NSString *)title alertMessage:(NSString *) message {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
     }]];
    [self.viewController presentViewController:alertController animated:YES completion:nil];
}

-(void) onPlaybackStateChanged:(int)state {
    UnitySendMessage("MusicPlayerPlugin", "CallbackEndOfPlayback", "");
    UnitySendMessage("MusicPlayerPlugin", "OnPlaybackStateChanged", [NSString stringWithFormat:@"%d", state].UTF8String);
}


#pragma - MPMediaPickerControllerDelegate

- (void) mediaPicker:(MPMediaPickerController *)mediaPicker
   didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
        
    MPMediaItem *item = [mediaItemCollection.items lastObject];
    save_songTitle = item.title;
    save_artist = item.artist;
    NSURL *url = [item valueForProperty:MPMediaItemPropertyAssetURL];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:url options:nil];

    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]
                                           initWithAsset:urlAsset
                                           presetName:AVAssetExportPresetPassthrough];
    
    NSArray *tracks = [urlAsset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *track = [tracks objectAtIndex:0];
    
    id desc = [track.formatDescriptions objectAtIndex:0];
    const AudioStreamBasicDescription *audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)desc);
    FourCharCode formatID = audioDesc->mFormatID;
    
    NSString *fileType = nil;
    NSString *ex = nil;

    switch (formatID) {
             
        case kAudioFormatLinearPCM:
        {
            UInt32 flags = audioDesc->mFormatFlags;
            if (flags & kAudioFormatFlagIsBigEndian) {
                fileType = @"public.aiff-audio";
                ex = @"aif";
            } else {
                fileType = @"com.microsoft.waveform-audio";
                ex = @"wav";
            }
        }
            break;
             
        case kAudioFormatMPEGLayer3:
            fileType = @"com.apple.quicktime-movie";
            ex = @"mp3";
            break;
             
        case kAudioFormatMPEG4AAC:
            fileType = @"com.apple.m4a-audio";
            ex = @"m4a";
            break;
             
        case kAudioFormatAppleLossless:
            fileType = @"com.apple.m4a-audio";
            ex = @"m4a";
            break;
             
        default:
            break;
    }
     
    exportSession.outputFileType = fileType;
    
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            
    NSString *filePath = [docDir stringByAppendingPathComponent:@"export.mov"];
    NSURL *exportUrl = [NSURL fileURLWithPath:filePath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    exportSession.outputURL = exportUrl;    
   [exportSession exportAsynchronouslyWithCompletionHandler:^{
        
    if (exportSession.status == AVAssetExportSessionStatusFailed)
    {
        NSLog(@"Export failed -> Reason: %@, User Info: %@",
                exportSession.error.localizedDescription,
                exportSession.error.userInfo.description);
           
    }else if (exportSession.status == AVAssetExportSessionStatusCompleted) {

        NSURL *someURL = exportSession.outputURL;
        //download file and play from disk
        NSData *audioData = [NSData dataWithContentsOfURL:someURL];
        NSString *docDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *filePath = [NSString stringWithFormat:@"%@/%@.mp3", docDirPath , fileType];
        [audioData writeToFile:filePath atomically:YES];
                    
        NSError *error;
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        avPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
        if (avPlayer == nil) {
            [self showAlert: @"export session error" alertMessage: [error description]];
        } else {
            [avPlayer prepareToPlay];
            all_duration = avPlayer.duration;
            avPlayer.meteringEnabled = true;
            avPlayer.delegate = self;
            // Set the sound to play even in silent mode.
            [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil];

            [UnityMusicPlayerPlugin.shared selectedPicker];
        }
    } else {
        [self showAlert: @"export session error" alertMessage: [NSString stringWithFormat:@"status:%ld",(long)exportSession.status]];
    }
   }];
    [self onPlaybackStateChanged: (PlaybackStateType)Stopped];
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void) mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}


#pragma - AVAudioPlayerDelegate

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)data successfully:(BOOL)flag{
    [self onPlaybackStateChanged: (PlaybackStateType)Stopped];
}

@end
