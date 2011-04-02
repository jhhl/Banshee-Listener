//
//  config.h
//  Banshee
//
//  Created by Henry Lowengard on 12/15/10.
//  Copyright 2010 www.jhhl.net. All rights reserved.
//

  

#define NUMBER_OF_BANSHEE_CHANNELS 5

#define SAMPLE_RATE (44100.0)
//#define SAMPLE_RATE (11050.0)
// 8.811188811188812


// gray coded, aint it .. 
#if MORE_SOPHISITCATED
#define CF0   1.0
#define CF1   3.0
#define CF2   5.0
#define CF3   7.0
#define CF4   11.0

#define CHANNEL_BASE_FREQ (SAMPLE_RATE /(2.0 * CF1 *CF2 * CF3* CF4)) 
#else
// speaker's highest freq is ... ?
#define CHANNEL_BASE_FREQ  (SAMPLE_RATE/3) ///5000.0
#define CHANNEL_OCTAVES 1.0
#endif

#define SAMPLE_FORMAT SInt16
#define PLAY_BUFFERS 3
#define RECORD_BUFFERS 3
#define PLAY_FRAMECOUNT 1024

#define RECORD_FRAMECOUNT 8192
#define RECORD_FRAMECOUNT_LOG2 13

#define CHANNELS 2

#define BANSHEE_SECONDS 20.0 // 6.0
// 1= YOWL == 1 audio char
#define MAX_MESSAGE_CHARS 32.0
#define YOWLS_PER_BANSHEE_SECOND (MAX_MESSAGE_CHARS/BANSHEE_SECONDS) 
#define BANSHEE_SECONDS_PER_YOWL (1.0/YOWLS_PER_BANSHEE_SECOND)
#define BANSHEE_SAMPLES_PER_YOWL (SAMPLE_RATE*BANSHEE_SECONDS_PER_YOWL)


#define NMAGS 16
// C
#define BASE_GOERTZEL_FREQ 261.6255653005987


