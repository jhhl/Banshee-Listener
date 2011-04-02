//
//  RecordProcessPlay.h
//  Minute
//
//  Created by Henry Lowengard on 3/23/10.
//  Copyright 2010 www.jhhl.net. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "config.h"
#import <AudioToolBox/AudioToolBox.h>


 
@protocol RPPDelegate
- (void) recordBufferCallback: (float*)  recordBuffer  size: (int) inNumPackets;
@end;


@interface RecordProcessPlay : NSObject {
	
	id<RPPDelegate> delegate;
	
	float sampleRate;
 	float maxPlaySeconds;
	float maxRecordSeconds;
    
    float * floatRecBuffer;
	// Audio stuff
	
 	int soundLength; // in frames, multiply by channels and bytesPerSample or whatever to get byte size. 
	
 	float soundLengthInSeconds;
	float rec_soundLengthInSeconds;
 	
	// audio buffers, queue

 	BOOL canRecord;
	SInt16 * recordedSound;
	int recordedSoundLength;
	
	BOOL isRecording;
	UInt32 recOffset;
	UInt32 recSize;
	AudioQueueRef recQueue;
	UInt32 recFrameCount;
	AudioQueueBufferRef recBuffers[RECORD_BUFFERS];
	
//	int	silenceLevel;
	
	//LoopiViewDelegate * callbackDelegate;		// to regen screen when done.
	NSObject *recordLock; // proxy for the actual sound structure.
	 
 
	
	int recordBufferLevelCapacity;
	float * recordBufferLevel;
	int recordBufferLevelIx;
 
}
- (RecordProcessPlay *) init;
- (void) AQInit;
- (void) record;
- (IBAction) clearRecording;

 - (void) stopRecording;
 
// - (void) parseAudio: (int) whichAnalysis;
 
 
 
//@property int sReadPtr;

//@property(readonly) SInt16 *sound; // stereo shorts 
@property(readonly) float soundLengthInSeconds;
@property(readonly) int soundLength; // in frames .. so multiply by 2?
@property (readonly)     float * floatRecBuffer;
// audio is also kept here?
@property(readonly)		float							sampleRate;
@property(readonly) 	AudioQueueRef					queue;
@property(readonly) 	UInt32							frameCount;
//@property(readonly) 	AudioQueueBufferRef				*mBuffers ;
@property(readonly) 	AudioStreamBasicDescription		mDataFormat;
@property				UInt32							recOffset;
@property				UInt32							recSize;
@property				BOOL							isRecording;
//@property				BOOL							isComputingSonogram;
@property				AudioQueueRef					recQueue;
@property				UInt32							recFrameCount;
//@property				AudioQueueBufferRef				recBuffers;
@property 	float 	silenceLevel;
///@property (retain) LoopiViewDelegate * callbackDelegate;
@property (readonly) BOOL canRecord;
@property  	float maxPlaySeconds;
@property float maxRecordSeconds;
@property (readonly) float stretch;
@property 	BOOL playQuietAsSilent;
@property 	float * recordBufferLevel;
@property int recordBufferLevelIx;
@property (readonly) 	float avgLevelMax;
@property (readonly) 	BOOL stretchIsYES;
@property (assign)	id<RPPDelegate> delegate;

@end
