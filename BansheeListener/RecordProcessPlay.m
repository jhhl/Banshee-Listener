//
//  RecordProcessPlay.m
//  Minute
//
//  Created by Henry Lowengard on 3/23/10.
//  Copyright 2010 www.jhhl.net. All rights reserved.
//

#import "RecordProcessPlay.h"


@implementation RecordProcessPlay


#define STOP_AUDIO_ON_RECORD 1
#define WIPE_AUDIO 0

//@synthesize sReadPtr;
@synthesize queue;
@synthesize frameCount;
//@synthesize mBuffers;
@synthesize mDataFormat;

//@synthesize sound; // stereo shorts 
@synthesize soundLengthInSeconds;
@synthesize soundLength; // in frames .. so multiply by 2?
@synthesize recOffset;
@synthesize recSize;
@synthesize isRecording;
//@synthesize  isComputingSonogram;
@synthesize recQueue;
@synthesize recFrameCount;
//@synthesize recBuffers[BUFFERS];
@synthesize silenceLevel;
//@synthesize   callbackDelegate;
@synthesize canRecord;
@synthesize sampleRate;
@synthesize maxPlaySeconds;
@synthesize maxRecordSeconds;
@synthesize stretch;
@synthesize playQuietAsSilent;
@synthesize recordBufferLevel;
@synthesize recordBufferLevelIx;
@synthesize avgLevelMax;
@synthesize floatRecBuffer;

@synthesize stretchIsYES;
#

#pragma mark AUDIO section
#define JUST_AUDIO 0 

#define PLAY_GRAIN_INFO 1

#define TIMING 1

#define INTERPOLATE_REPEATS  1
#define INTERPOLATE_OVERLAP 40
 

 
void recordStatusRunningCallback (
								  void                  *inUserData,
								  AudioQueueRef         inAQ,
								  AudioQueuePropertyID  inID
								  )
{
	
	RecordProcessPlay *   me = inUserData;
	
	// this is the real end/begin of recording ...
	
	int isRunningQ;
	UInt32 dataSize = sizeof(isRunningQ);
	
	OSStatus err = AudioQueueGetProperty (inAQ,inID,&isRunningQ,&dataSize);
	if(err) 
		NSLog(@"recordStatusRunningCallback AudioQueueGetProperty err %d\n", err);	
	
	//	NSLog(@"recordStatusRunningCallback: %d",isRunningQ);
	// we may want to start the heterodyning  process here too. 
	me->isRecording = isRunningQ!=0;
    
   
	 
	
}

- (void) stopRecording
{
	OSStatus err;
	//	err = AudioQueueFlush (recQueue	);
	//	if(err) 
	//		NSLog(@"record AudioQueueFlush err %d\n", err);
	err = AudioQueueStop(recQueue, true);
	if(err) 
	//	NSLog(@"record AudioQueueStop err %d\n", err);
	isRecording = NO;
	//allowAudio=YES;
#if STOP_AUDIO_ON_RECORD
	if(queue)
	{
#if WIPE_AUDIO
		UInt32 bufferBytes  = frameCount * mDataFormat.mBytesPerFrame;
		for (int i=0; i<BUFFERS; i++) 
		{
			memset(mBuffers[i],0,bufferBytes);
			AQBufferCallback (self, queue, mBuffers[i]);
			
		}
#endif
		
		 
		
	};
#endif
	
}



static void recordingCallback (
							   void								*inUserData,
							   AudioQueueRef						inRecQueue,
							   AudioQueueBufferRef					inBuffer,
							   const AudioTimeStamp				*inStartTime,
							   UInt32								inNumPackets,
							   const AudioStreamPacketDescription	*inPacketDesc
							   ) {
	// This callback, being outside the implementation block, needs a reference to the AudioRecorder object
	RecordProcessPlay *recorder = (RecordProcessPlay *) inUserData;
	//	NSLog(@"recording, offset: %d buffer: %X recording? %d",[recorder recOffset],inBuffer,[recorder isRecording]);
	// if there is audio data, write it to the recording buffer .. which is the usual audio bufer we have.  
	// 
	if (inNumPackets > 0) 
	{
        SAMPLE_FORMAT * recordBuffer = inBuffer->mAudioData;
        
         for(int i = 0 ; i<inNumPackets;i++)
        {
            recorder->floatRecBuffer[i] = (float)recordBuffer[i*2]/32767.0;;
         };
         
      //  if(audioMax > 0)        
             [recorder->delegate recordBufferCallback:  recorder->floatRecBuffer  size: inNumPackets];
        
    };
	// if not stopping, re-enqueue the buffer so that it can be filled again
 		AudioQueueEnqueueBuffer(inRecQueue,inBuffer,0,NULL);
}


//???
void interruptionListenerCallback (
								   void    *inUserData,                                                // 1
								   UInt32  interruptionState                                           // 2
								   ) {
	NSLog(@"interrupted!");
}


- (void) resumePlayback {
	// this gives us a chance to reset some things . 
	//	OSStatus err;
	// can this device record at all?
	UInt32 audioInputIsAvailable;                            // 1
	UInt32 propertySize = sizeof (audioInputIsAvailable);    // 2
	
	AudioSessionGetProperty (                                // 3
							 kAudioSessionProperty_AudioInputAvailable,
							 &propertySize,
							 &audioInputIsAvailable
							 );
	canRecord =audioInputIsAvailable;
	
	UInt32 sessionCategory;
	if(canRecord)
	{
		sessionCategory= kAudioSessionCategory_PlayAndRecord;
	}
	else {
		sessionCategory = kAudioSessionCategory_LiveAudio; 
	}
	
	// reset this in case....
	
	if(canRecord)
	{
		// route to speaker, not headphone!
		UInt32 useSpeaker =  kAudioSessionOverrideAudioRoute_Speaker;
		AudioSessionSetProperty (                                      // 2
								 kAudioSessionProperty_OverrideAudioRoute,                       // 3
								 sizeof (useSpeaker),                                  // 4
								 &useSpeaker                                           // 5
								 );
	}
	
    AudioSessionSetActive (true);                                  // 6
	
	//  [self.audioPlayer resume];                                     // 7
}

// route change callback .. basically, someone may have plugged in a headphone or something.
void audioRouteChangeListenerCallback (
									   void                   *inUserData,                                 // 1
									   AudioSessionPropertyID inPropertyID,                                // 2
									   UInt32                 inPropertyValueSize,                         // 3
									   const void             *inPropertyValue                             // 4
									   ) 
{
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return; // 5
	
 	
	{
        CFDictionaryRef routeChangeDictionary = inPropertyValue;        // 8
        CFNumberRef routeChangeReasonRef =
		CFDictionaryGetValue (
							  routeChangeDictionary,
							  CFSTR (kAudioSession_AudioRouteChangeKey_Reason)
							  );
		
        SInt32 routeChangeReason;
        CFNumberGetValue (
						  routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason
						  );
		
        if (routeChangeReason ==
			kAudioSessionRouteChangeReason_OldDeviceUnavailable) {  // 9
			
 			/* rerout back to the speaker???
			 
			 UIAlertView *routeChangeAlertView =
			 [[UIAlertView alloc]
			 initWithTitle: @"Hmmm"
			 message: @"Audio output was changed."
			 delegate: inUserData
			 cancelButtonTitle: @"Stop"
			 otherButtonTitles: @"Play", nil];
			 [routeChangeAlertView show];
			 */
			UInt32 useSpeaker =  kAudioSessionOverrideAudioRoute_Speaker;
			AudioSessionSetProperty (                                      // 2
									 kAudioSessionProperty_OverrideAudioRoute,                       // 3
									 sizeof (useSpeaker),                                  // 4
									 &useSpeaker                                           // 5
									 );
			
        }
    }
}



- (void) AQInitWithRunLoop: (CFRunLoopRef) myRunLoop ;
{
 	
	OSStatus err;
	
	AudioSessionInitialize (
							myRunLoop,						// 1
							kCFRunLoopCommonModes,          // 2
							interruptionListenerCallback,    // 3
							NULL                         //  userData
							);
	
	// can this device record at all?
	UInt32 audioInputIsAvailable=0;
	UInt32 propertySize = sizeof (audioInputIsAvailable);
	
	AudioSessionGetProperty (
							 kAudioSessionProperty_AudioInputAvailable,
							 &propertySize,
							 &audioInputIsAvailable
							 );
	
	canRecord =audioInputIsAvailable;
	
	//
	UInt32 sessionCategory;
	if(canRecord)
	{
		sessionCategory= kAudioSessionCategory_PlayAndRecord;
	}
	else 
	{
		sessionCategory = kAudioSessionCategory_LiveAudio; 
	}
	
    AudioSessionSetProperty (
							 kAudioSessionProperty_AudioCategory,
							 sizeof (sessionCategory),
							 &sessionCategory
							 );
	
    AudioSessionSetActive(true);
	
	if(canRecord)
	{
		
		// route to speaker, not phone phone .. unless real headphone is plugged in?
		
		// what is the current audio route?
		NSString * currentAudioRoute=NULL;
		propertySize = sizeof (currentAudioRoute);
		
		AudioSessionGetProperty (
								 kAudioSessionProperty_AudioRoute,
								 &propertySize,
								 &currentAudioRoute
								 );
		// There's no explicit way to set to the headset, but if it's not plugged in, use the speaker (not the headphone)
		if([currentAudioRoute compare:@"HeadsetInOut"]!= NSOrderedSame )
		{
			UInt32  useSpeakerOrHeadSet =  kAudioSessionOverrideAudioRoute_Speaker;		
			AudioSessionSetProperty (
									 kAudioSessionProperty_OverrideAudioRoute,
									 sizeof (useSpeakerOrHeadSet),
									 &useSpeakerOrHeadSet
									 );
		}
	}
	// Registers the audio route change listener callback function
    AudioSessionAddPropertyListener (
									 kAudioSessionProperty_AudioRouteChange,
									 audioRouteChangeListenerCallback,
									 self
									 );

	
	// Set up our audio format -- signed interleaved shorts (-32767 -> 32767), 16 bit stereo
	// The iphone does not want to play back float32s.
	
	//asDesc setup:
	
	mDataFormat.mSampleRate = sampleRate;
	mDataFormat.mFormatID = kAudioFormatLinearPCM;
	mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger  | kAudioFormatFlagIsPacked;
	mDataFormat.mBytesPerPacket = 4;
	mDataFormat.mFramesPerPacket = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
	mDataFormat.mBytesPerFrame = 4;
	mDataFormat.mChannelsPerFrame = 2;
	mDataFormat.mBitsPerChannel = 16;
	
	
	// Set the size and packet count of each buffer read. (e.g. "frameCount")
//	frameCount = FRAMECOUNT;
	// Byte size is 4*frames (see above)
	UInt32 bufferBytes  = frameCount * mDataFormat.mBytesPerFrame;
	
 	// the buffers are preallocated .. I think.
	
	 	// set the volume of the queue -- note that the volume knobs on the ipod / celestial also change this
	 
#pragma  mark Initialize recording stuff
 	if(canRecord)
	{
		isRecording=NO;
		recOffset=0;
		recSize=0;
		recFrameCount = RECORD_FRAMECOUNT;
		
		
		err= AudioQueueNewInput (
							&mDataFormat,
							recordingCallback,
							self,									// userData
							myRunLoop,								// run loop
							kCFRunLoopCommonModes,					// run loop mode
							0,										// flags
							&recQueue
							);
		if(err) 
			NSLog(@"record AudioQueueNewInput err %ld\n", err);
		
		// listen for recording on/off
		err = AudioQueueAddPropertyListener (recQueue,
											 kAudioQueueProperty_IsRunning,
											 recordStatusRunningCallback,
											 self
											 );
		if(err) 
			NSLog(@"record AudioQueueAddPropertyListener err %ld\n", err);
		
		
		int bufferIndex;
		// make more buffers and enqueue them 
		bufferBytes  = recFrameCount * mDataFormat.mBytesPerFrame;
		floatRecBuffer = calloc(recFrameCount,sizeof(float));
        
		for (bufferIndex = 0; bufferIndex < RECORD_BUFFERS; ++bufferIndex) 
		{
			err = AudioQueueAllocateBuffer(recQueue, bufferBytes, &recBuffers[bufferIndex]);
			if(err) 
				NSLog(@"record AudioQueueAllocateBuffer [%d] err %ld\n",bufferIndex, err);
			
			/* do we need this now?
			 err =AudioQueueEnqueueBuffer (
			 recQueue,
			 recBuffers[bufferIndex],
			 0,
			 NULL
			 );
			 if(err) 
			 NSLog(@"record AudioQueueEnqueueBuffer [%d] err %d\n",bufferIndex, err);
			 */
		}
	};
 	
	// Start the queue
	//err = AudioQueueStart(queue, NULL);
	//if(err) NSLog(@"(m) AudioQueueStart err %d\n", err);
	
	// is this really needed ?   it conks out the display. 
	// I'm passing in the main procedure's run loop so that doesn't happen.
	// CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
	
	//return 0;
}

- (void) AQInit
{
	// is it possible to get another runloop?
	
	//[self   AQInitWithRunLoop: CFRunLoopGetCurrent()] ;
	[self   AQInitWithRunLoop:NULL] ;
	
};

 
// this is called.. before start record
// it's supposed to wipe both play and record areas!
- (IBAction) clearRecording 
{
//?	memset(recordedSound,0,soundLength*sizeof(SInt16)*2);

	//allowAudio=NO;

#if STOP_AUDIO_ON_RECORD
	OSStatus err;

	if(queue)
	{
		err = AudioQueueFlush(queue);
		if(err) 
			NSLog(@"play AudioQueueFlush err %ld\n", err);
#if WIPE_AUDIO

		err = AudioQueueStop(queue, NO);
		if(err) 
			NSLog(@"play AudioQueueStop err %ld\n", err);
#endif
	};
#endif
	
};

- (void) startRecording
{
	// stop playing audio ...
	OSStatus err;
	
	recSize = 0;
	recOffset=0;
	//sReadPtr = 0;
	 recordBufferLevelIx=0;

	// queue it?
	
	// enqueue  buffers 
//#if DONT_ENQUEUE_RECORD_BUFFERS
	int bufferIndex;

	for (bufferIndex = 0; bufferIndex <RECORD_BUFFERS; ++bufferIndex) 
	{
		err =AudioQueueEnqueueBuffer (
									  recQueue,
									  recBuffers[bufferIndex],
									  0,
									  NULL
									  );
		if(err) 
			NSLog(@"record AudioQueueEnqueueBuffer [%d] err %ld\n",bufferIndex, err);
	}  
//#endif
	/* what device? */
	NSString * deviceType;
	UInt32 deviceTypeSize;
	AudioQueueGetPropertySize(recQueue,kAudioQueueProperty_CurrentDevice,&deviceTypeSize);
	
	err = AudioQueueGetProperty (recQueue,kAudioQueueProperty_CurrentDevice,&deviceType,&deviceTypeSize);
	
	//	NSLog(@"device type: %@",deviceType);
	
	err = AudioQueueStart(recQueue, NULL);
	if(err)
	{
		NSLog(@"record AudioQueueStart err %ld\n", err);
	
		err = AudioQueueStop(recQueue, NO);
		isRecording = NO;
		
	}
     if (err) {
        NSLog(@"startPlaying AudioQueueStart returned %ld.", err);
        
        if (err == kAudioSessionNotActiveError) {
            err = AudioSessionSetActive(true);
            if (err) {
                NSLog(@"startPlaying - AudioSessionSetActive(true) returned %ld.", err);
            } else {
                NSLog(@"startPlaying - restarted Audio Session");
            }
        }
    }
}


#pragma mark normal stuff
- (RecordProcessPlay *) init
{
	[super init];
	
 	
	sampleRate=SAMPLE_RATE;
 	silenceLevel =0.002;

 	soundLength = maxRecordSeconds*sampleRate;
	
	//	sound = (SInt16 *)malloc(soundLength*sizeof(SInt16)*2);
	recordedSound = (SInt16 *)malloc(soundLength*sizeof(SInt16)*2);
	// debugging aid ..makes eack one 0x0101 == 257
	//memset(recordedSound,1,soundLength*sizeof(SInt16)*2);
 

	return self;
}

- (void) record
{
	//recordingIsNew=YES;
	[self startRecording];
};

 //#define LOWPASS_Z_LEN (44100/512)
#define LOWPASS_Z_LEN (8)
//static SInt16 lowpass_z[LOWPASS_Z_LEN];
//static int lowpass_z_p=0;
//static SInt32 lowpass_z_cum;

 
- (void) normalizeRecordedAudio
{
	int max = 0 ;
	for(int i = 0;i<recSize*2;i++)
	{
		max = MAX(max,abs(recordedSound[i]));
	}
	for(int i = 0;i<recSize*2;i++)
	{
		recordedSound[i] =  (recordedSound[i]*32760/max);
	}
	
}
// try to return the optimal 
// get the correlation numbers for spanning samples at all these distances .
// then try to pick the best one . 
//
#define SAMPLE(a,b) (((float)a[(b)*2])/32768.0)

- (int) wavelengthFromSound: (SInt16 *) sound 
					 Offset: (int) offset 
					 Length: (int) len
				   Shortest: (int) shortest 
					Longest: (int) longest
					Spanning: (int) spanning
{
	// keep trak of the sum of the squares of the differences from shortest to longest wave lengths
	int corr_num = longest-shortest;
	float corrs[corr_num];
	// we longest is a low freq, shortest is a high one . 
	for (int wli = 0;wli <corr_num;wli++)
	{
		if(offset+spanning+wli>len)
		{
			corr_num=wli;
			break;
		};
		
 		float corr = 0.0;
		for(int i = offset ;i<offset+spanning;i++)
		{
			float basesample = SAMPLE(sound,i);
			float testsample = SAMPLE(sound,shortest+i+wli);
			 corr += ((testsample-basesample)*(testsample-basesample));
		}
		// corr will be very low at this 
		corrs[wli] = corr;
	}
	// now look at corrs to find all the local minima.
	// differential #1 = so what we'll seek will be negative followed by positive ... 
	for (int i = 1;i <corr_num;i++)
	{
		//NSLog(@"%02d) %f, d= %f",i,corrs[i-1],corrs[i]-corrs[i-1]);
		corrs[i-1]= corrs[i]-corrs[i-1];
	}
	
	
	for (int i = 0;i <corr_num-2;i++)
	{
		if(corrs[i]>0) continue;
		if(corrs[i+1]>0)
		{
			return shortest+i+1;
		}
	};
	return 0;
}
 
- (void) UnitTestWL
{
	float srate = 11000; // 2 "seconds"
	int samples =srate*2;
	int longest = srate/10.0;
	int shortest = srate/60.0;
	int ms50 = srate*50.0/1000.0;

 	SInt16 * tsound = calloc(samples, sizeof(SInt16)*2);
	// amke test sample:
	for(float tFreq= 15.0;tFreq<50.0;tFreq+=0.5)
	{
	float targetWL = srate/tFreq; 

	for(int i = 0 ; i<samples;i++)
	{
		float ang = tFreq*6.2831853071795862*(float)i/srate;
		// some harmonics
		tsound[i*2] = 1000.0*sin(ang )+400.0*sin(ang*2.0)+200.0*sin(ang*3.0);
		tsound[i*2+1] = i; // for me to look at. 
		// don't bother withthe odd sample which we don't even read.
	}
	//
	int gWL = [self wavelengthFromSound: tsound
								 Offset: 0 
								 Length: samples
							   Shortest: shortest 
								Longest: longest
							   Spanning: ms50];
	NSLog(@"tf: %f WL? %f gWL: %d",tFreq,targetWL,gWL);
	}
}

//#define LOG_GRAIN(tag,ix) NSLog(@"%@ %d %d ",tag,grainInfo[ix].begin,grainInfo[ix].end);
#define LOG_GRAIN(tag,ix)
 
#define PROC_SILENCE 0
#define PROC_NOISE 1

#define PROC_SUSTAIN 1

// just reverse the sense of silence. 
#define USE_SUSTAIN 0

#define DEBOUNCE 8
// test this??
  
 
 


- (void)dealloc {
    [super dealloc];
 
	if(recordedSound)	free(recordedSound);
 	
	
	AudioQueueDispose (                            // 1
					   queue,                             // 2
					   true                                       // 3
					   );
 	if(canRecord)
	{
		AudioQueueDispose (                            // 1
						   recQueue,                             // 2
						   true                                       // 3
						   );
	}
 	
	
}
// info
 
 
 

@synthesize delegate;
@end
