//
//  AudioMath.h
//  Banshee
//
//  Created by Henry Lowengard on 3/17/11.
//  Copyright 2011 www.jhhl.net. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "config.h"
#import "Accelerate/Accelerate.h"

#define QSINE_BITS 13
#define QSINE_LEN (1<<QSINE_BITS)
#define QSINE_MASK (QSINE_LEN-1)

@interface AudioMath : NSObject {

}
+ (void) createQSine;
+ (float) qSin1Hz  ;
+ (SAMPLE_FORMAT) qSinAt:(float) t;
+ (SAMPLE_FORMAT) qCosAt:(float) t;
+ (float *) hanningN: (int) N;
+ (float) Qgoertzel:(SAMPLE_FORMAT *) sample N: ( int) N F: ( float) target_f;
float goertzel(SAMPLE_FORMAT * sample, int N, float target_f);
float goertzelf(float * sample, int N, float target_f);
float goertzelf2(float * x, int N, float k);
float goertzelf3(float *x, int N, float frequency ) ;
float hetero(float * x, int N, float target_f);
void normalize(float * rb,int N);
void setupFFT();
void teardownFFT(void);
void fft(float * x, int N);
float fftAt(float f);
float fftSlot(int ix);

float crude(float * x, int N, float target_f);
 
void unitTestFFT(int NLOG2);

@end
