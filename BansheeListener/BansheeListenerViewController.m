//
//  BansheeListenerViewController.m
//  BansheeListener
//
//  Created by Henry Lowengard on 3/17/11.
//  Copyright 2011 www.jhhl.net. All rights reserved.
//

#import "BansheeListenerViewController.h"

@implementation BansheeListenerViewController

- (void)dealloc
{
    [super dealloc];
    [myRPP release];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

 
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    myRPP = [[[RecordProcessPlay alloc] init] retain];
    myRPP.delegate = self;
    [myRPP AQInit];
    float ph = 400.0/(float)NMAGS;
    // hmm
    float top = 5.0;
    float et12 = pow(2.0,1.0/12.0);
    
    float freq = BASE_GOERTZEL_FREQ;
    for(int n=0;n<NMAGS;n++)
    {
        progresses[n] = [[UIProgressView alloc] initWithFrame:CGRectMake(110.0,top+(ph/2)-2.0,200.0,ph-2.0)];
        [self.view addSubview:progresses[n]];
        
        progressLabels[n] = [[UILabel alloc] initWithFrame:CGRectMake(0.1,top,100.0,ph-2.0)];
        progressLabels[n].text= [NSString stringWithFormat:@"%8.2f",freq];
        freq *=et12;
        [self.view addSubview:progressLabels[n]];

        top += ph;
    }
    // because I'm using fft's 
 //   unitTestFFT(RECORD_FRAMECOUNT_LOG2);
//    setupFFT();
    myAVPlayers = calloc(NMAGS,sizeof(AVAudioPlayer *));
    claimedAVP = calloc(NMAGS,sizeof(int));
    // allocate all AVAudioPlayers
    NSError * error;
	
    for(int i = 0;i<NMAGS;i++)
    {
        NSString * midiTag = [NSString stringWithFormat:@"%02d",i%12];
        //NSArray * afiles = [[NSBundle mainBundle] pathsForResourcesOfType:@"mp3"inDirectory:@"Audio"];
        //NSLog(@"aaa",afiles);
        NSString * path = [[NSBundle mainBundle] pathForResource:midiTag ofType:@"aif" inDirectory:@"NoteNames"];

        NSURL * audioFileURL = [NSURL fileURLWithPath:path];	
		myAVPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL: audioFileURL error:&error];
		if(error)
		{
			NSLog(@"bad thing making the player ... %@",[error localizedDescription]);
			return;
		}
		// loop once;
		myAVPlayer.numberOfLoops = 0;
		myAVPlayer.volume=0.0; /// will be determined via accellerometer!?
		myAVPlayer.delegate = self;
        myAVPlayers[i] = myAVPlayer;
        
    }

    
#if USE_OSC
    myOSCServer = [[OSCServer alloc] init];
    myOSCServer.mvDelegate = (id) self;
#endif	
    [self setupSession];

    // 
    [self playNoteNumber:60 Volume:0.85];
}
 
- (IBAction) segmentChanged
{
    if(mySegment.selectedSegmentIndex ==0)
    {
        [myRPP stopRecording];
    }
    else
    {
        [myRPP record];
    };
    
};

static float * hannWin=nil;

- (void) recordBufferCallback: (float*)  recordBuffer  size: (int) N
{
    float et = pow(2.0,1.0/12.0);
    float base = BASE_GOERTZEL_FREQ;
   // this "N" should be made to be about 512 instead ...
#define DO_HANNING 1
#if DO_HANNING
    if(!hannWin)
        hannWin = [AudioMath hanningN:N];
#endif
#if DO_HANNING
    vDSP_vmul (
                    recordBuffer ,
                    1,
                    hannWin,
                    1,
                    recordBuffer ,
                    1,
                    N
                    );
#endif
    normalize(recordBuffer ,N);

    // fft only!
  //  fft(recordBuffer ,N);
    for(int n = 0 ; n<NMAGS;n++)
    {
        // int lilN = MIN(2.0*44100.0/base,N);
        //float goertzelf3(float *x, int N, float frequency ) 
        // float mag =   fftAt(base);
        float mag = goertzelf2(recordBuffer,N,base);
        
        progresses[n].progress = MAX(0.0,MIN(1.0,mag));
        // convert to a not if it's loud enough.
        if(mag>0.1)
        {
            NSLog(@"magWillPlay %d",n);
            [self  playNoteNumber: n   Volume: mag];
        }
       // NSLog(@"%5.1f = %5.3f",base,mag);
        base *=et;
    }
    
};

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
   // teardownFFT();
    if(hannWin) free(hannWin);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}



#pragma mark PLAY
- (void) setupSession
{
	NSError *setCategoryError = nil;
    
	[[AVAudioSession sharedInstance]
	 setCategory: AVAudioSessionCategoryPlayback
	 error: &setCategoryError];
	
	if (setCategoryError) { /* handle the error condition */ }
	
	UInt32 mix = YES; 
	
	AudioSessionSetProperty (
							 kAudioSessionProperty_OverrideCategoryMixWithOthers, // 2
							 sizeof (mix), // 3
							 &mix // 4
							 );
    
	float aBufferLength = 0.005; // In seconds
	AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, 
							sizeof(aBufferLength), &aBufferLength);
    
  	
}
- (AVAudioPlayer *) alreadyAllocatedAVPFor: (int) noteNumber
{
	for(int i = 0; i<NMAGS; i++)
	{
		if(claimedAVP[i] ==noteNumber)
			return myAVPlayers[i];
	}
	return NULL;
	
}

- (AVAudioPlayer *) getAvailableAVPlayerFor: (int) noteNumber
{
	for(int i = 0; i<NMAGS; i++)
	{
		if(myAVPlayers[i] == NULL)
		{
			claimedAVP[i] = noteNumber;
			return myAVPlayers[i];
		}
	}
	return myAVPlayers[0];
	
}

- (void) playNoteNumber: (int) noteNumber Volume: (float) vol
{
	// use the tag to schedule a note . 
	// Custom initialization
    NSLog(@"playNoteNumber %d %0.2f",noteNumber,vol);
        
		myAVPlayer = myAVPlayers[noteNumber%12];
 	 
    //BOOL retrigger = myAVPlayer.volume <0.05;
    BOOL retrigger = YES;
  if(retrigger) 
      NSLog(@"retrigger %d %0.2f",noteNumber,myAVPlayer.volume);
		// loop once;
		myAVPlayer.numberOfLoops = 0;
		myAVPlayer.volume=vol; /// will be determined via accellerometer!?
		myAVPlayer.delegate = self;
		if(retrigger)
        {
            [myAVPlayer stop];
            [myAVPlayer play];
        }
}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (flag)
    {
        [player stop];
      //  [player release];
      //  player = NULL;
        NSLog(@"audioPlayerDidFinishPlaying: good play");

    }
    else
    {
        NSLog(@"audioPlayerDidFinishPlaying: bad play");
    }
}

@end
