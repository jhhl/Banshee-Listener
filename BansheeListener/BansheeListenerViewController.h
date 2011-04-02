//
//  BansheeListenerViewController.h
//  BansheeListener
//
//  Created by Henry Lowengard on 3/17/11.
//  Copyright 2011 www.jhhl.net. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "config.h"
#import "RecordProcessPlay.h"
#import "AudioMath.h"
#import "AVFoundation/AVAudioPlayer.h"
#import "AVFoundation/AVAudioSession.h"
#import <AudioToolbox/AudioToolbox.h>

@interface BansheeListenerViewController : UIViewController <RPPDelegate,AVAudioPlayerDelegate>{
    IBOutlet UILabel * myLabel;
    IBOutlet UISegmentedControl * mySegment;
    RecordProcessPlay * myRPP;
    UIProgressView * progresses[NMAGS];
    UILabel * progressLabels[NMAGS];
    
    AVAudioPlayer * myAVPlayer;
	AVAudioPlayer ** myAVPlayers;
	int * claimedAVP;
    
}
- (IBAction) segmentChanged;
- (void) recordBufferCallback: (float*)  recordBuffer  size: (int) inNumPackets;
- (void) setupSession;
- (void) playNoteNumber: (int) noteNumber Volume: (float) vol;

@end
