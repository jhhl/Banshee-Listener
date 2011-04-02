//
//  AudioMath.m
//  Banshee
//
//  Created by Henry Lowengard on 3/17/11.
//  Copyright 2011 www.jhhl.net. All rights reserved.
//

#import "AudioMath.h"


@implementation AudioMath

static SAMPLE_FORMAT *qSine;
static float qSineAngleInc;

+ (void) createQSine
{
	qSineAngleInc = 2.0*M_PI/(float)(QSINE_LEN);
    
	float fi = 0.0;
	qSine = malloc(sizeof(SAMPLE_FORMAT)*QSINE_LEN);
	
	for(int i = 0;i<QSINE_LEN;i++)
	{
		qSine[i] = sinf(fi)*32767.0;
		fi += qSineAngleInc;
	}
}
 
// more expensive, but more accurate?
// 1HZ  means advance t by 1/ QSineLen.
+ (float) qSin1Hz { 
    return 1.0/(float)QSINE_LEN;
};

+ (SAMPLE_FORMAT) qSinAt:(float) t
{
	float base = fmod(t,1.0);
 	int tBase = base*QSINE_LEN;
	return (SAMPLE_FORMAT) (qSine[tBase]) ;
}

+ (SAMPLE_FORMAT) qCosAt:(float) t
{
	float base = fmod(t+0.25,1.0);
 	int tBase = base*QSINE_LEN;
	return (SAMPLE_FORMAT) (qSine[tBase]) ;
}



+ (SAMPLE_FORMAT) qSinBetterAt:(float) t
{
	float base = fmod(t,1.0);
	float frac = (base*(float)QSINE_LEN) - floor((base*(float)QSINE_LEN));
	int tBase = base*QSINE_LEN;
	int tBase1 = (tBase +1) & QSINE_MASK;
	
	return (SAMPLE_FORMAT) (qSine[tBase]*(1.0-frac)) + (qSine[tBase1]*frac);
	
}

+ (float *) hanningN: (int) N
{
    float *hanne = calloc(N,sizeof(float));
    
    // kind of a stupid envelope .. 
	for(int i = 0 ; i<N;i++)
	{
		float hann = 0.5 * (1.0 - cosf( (2.0*M_PI*i)/(N-1)));
		//float hamming = 0.54 - (0.46*cosf( (2.0*M_PI*i)/(N-1)));
		hanne[i] = sqrt(hann);
	}
    return hanne;
}

void normalize(float * rb,int N)
{
float audioMax = 0;
for(int i = 0 ; i<N;i++)
{
    audioMax = MAX(audioMax,fabs(rb[i]));
};
    
//NSLog(@"recordingCallback: audioMax: %0.3f",audioMax);
    for(int i = 0 ; i<N ;i++)
    {
        rb[i] = rb[i]/audioMax;
    };
}

float goertzelf(float * sample, int N, float target_f)
{
    // N is the size of the buffer
    int k =  (int) (0.5+ ((float)N*target_f)/SAMPLE_RATE);
    float w = (2*M_PI/N)*(float) k;
    float cosine = cosf(w);
    float sine = sinf(w);
    float coeff = 2.0*cosine;
    
    float Q0;
    float Q1;
    float Q2;
    
    Q0=0;
    Q1=0;
    Q2=0;
    
    for(int i=0;i<N;i++)
    {
        Q0 = coeff*Q1 - Q2 +   sample[i];
        Q2=Q1;
        Q1=Q0;
    }
    float real = (Q1-Q2-cosine);
    float imag = (Q2*sine);
    float magnitude = sqrt(real*real + imag*imag)/(float)N;
    return magnitude;
    
}

float goertzelf2(float * x, int N, float k)
{
    float fN = (float) N;
   float realW = 2.0*cosf(2.0*M_PI*k/(SAMPLE_RATE));
   float imagW =     sinf(2.0*M_PI*k/(SAMPLE_RATE));
    
    float d1 = 0.0;
    float d2 = 0.0;
    for (int n=0; n<N; ++n)
    {
        float y  = x[n] + (realW*d1) - d2;
        d2 = d1;
        d1 = y;
    }
    float resultr = (0.5*realW*d1) - d2;
    float resulti = imagW*d1;
    float magnitude = 2.0*sqrt((resultr*resultr) + (resulti*resulti))  /fN;
    return magnitude;
    
}

float goertzelf3(float *x, int N, float frequency ) {
    float Skn, Skn1, Skn2;
    Skn = Skn1 = Skn2 = 0;
    float C=frequency*2.0*M_PI/SAMPLE_RATE;
    float Cc=cosf(C);
    for (int i=0; i<N; i++) {
        Skn2 = Skn1;
        Skn1 = Skn;
        Skn = 2*Cc*Skn1 - Skn2 + x[i];
    }
    
    float WNk = exp(-C); // this one ignores complex stuff
    //float WNk = exp(-2*j*PI*k/N);
    return (Skn - WNk*Skn1);
}


float hetero(float * x, int N, float target_f)
{
    // N is the size of the buffer
    float angle = 6.283185307179586f*target_f/(float)SAMPLE_RATE;
    float r = 0.0;
    float i = 1.0;
    float s = sinf(angle);
    float c = cosf(angle);
    float g = 0.0;
    float h = 0.0;
    
    for(int ii = 0; ii<N;ii++)
    {
        g += x[ii]*r;
        h += x[ii]*i;
        float r1 = r*s + i*c;
        float i1 = -r*c + i*s;
        r = r1;
        i = i1;
    }
    float mag = sqrt(g*g + h*h) /(float) N ;
    return mag;
}

float goertzel(SAMPLE_FORMAT * sample, int N, float target_f)
{
    // N is the size of the buffer
    int k = (int) (0.5+ (N*target_f)/SAMPLE_RATE);
    float w = (2*M_PI/N)*k;
    float cosine = cosf(w);
    float sine = sinf(w);
    float coeff = 2.0*cosine;
    
    float Q0;
    float Q1;
    float Q2;
    
    Q0=0;
    Q1=0;
    Q2=0;
    
    for(int i=0;i<N;i++)
    {
        Q0 = coeff*Q1 - Q2 + (float) sample[i]/32767.0;
        Q2=Q1;
        Q1=Q0;
    }
    float real = (Q1-Q2-cosine);
    float imag = (Q2*sine);
    float magnitude = sqrt(real*real + imag*imag);
    return magnitude;
    
}
+ (float) Qgoertzel:(SAMPLE_FORMAT *) sample N: ( int) N F: ( float) target_f
{
    // N is the size of the buffer
    int k = (int) (0.5+ (N*target_f)/SAMPLE_RATE);
    float w = (2*M_PI/N)*k;
    
    float cosine = cosf(w);
    float sine = sinf(w);
    
    float coeff = 2.0*cosine;
    
    float Q0;
    float Q1;
    float Q2;
    
    Q0=0;
    Q1=0;
    Q2=0;
    
    for(int i=0;i<N;i++)
    {
        Q0 = coeff*Q1 - Q2 + (float) sample[i]/32767.0;
        Q2=Q1;
        Q1=Q0;
    }
    float real = (Q1-Q2-cosine);
    float imag = (Q2*sine);
    float magnitude = sqrt(real*real + imag*imag);
    return magnitude;
    
}

#pragma mark FFT
static FFTSetup myFFTSetup;
static COMPLEX_SPLIT   A;
static float * myFFT;

void unitTestFFT(int NLOG2)
{
    setupFFT();
    int N = 1<<NLOG2;
   // float freq = 200.0;
    int Q = N/20;
    
    float * data = calloc(N,sizeof(float));

     for(int i = 0;i<N;i++)
    {
        data[i] = 2.0*(((float) (i%Q)/(float) Q) - 0.5); 
    }
    fft(data,N);
    teardownFFT();
}

 

void setupFFT(void)
{
    myFFTSetup =  vDSP_create_fftsetup (
                                   RECORD_FRAMECOUNT_LOG2,
                                        kFFTRadix2
                                        );
// Assert(myFFTSetup,@"vDSP_create_fftsetup failed ");
    if (myFFTSetup == NULL) {
        NSLog (@"\nFFT_Setup failed to allocate enough memory  for myFFTSetup\n"
               );
        exit(0);
    };
    myFFT = calloc(RECORD_FRAMECOUNT,sizeof(float));
    A.realp = calloc(RECORD_FRAMECOUNT/2,sizeof(float));
    A.imagp = calloc(RECORD_FRAMECOUNT/2,sizeof(float));
    
 //  Assert(myFFT,@"no memory for FFT");
    
};

void teardownFFT(void)
{
    vDSP_destroy_fftsetup(myFFTSetup);
    myFFTSetup = NULL;
    free(A.realp);
    free(A.imagp);

    free(myFFT);
}
int fftPeak()
{
    float max = 0;
    int maxi = 0;
    for (int i =2 ; i<RECORD_FRAMECOUNT;i++)
    {
        float fs = fabs(myFFT[i]);
        if(max<fs)
        {
            max=fs;
            maxi = i;
        }
    }
    return maxi;
}
void fft(float * x, int N)
{
    vDSP_ctoz((COMPLEX *) x, 2, &A, 1, N / 2);
#if SEE_FFT
    for(int i = 0 ; i<40;i++)
        NSLog(@"A before %d: (%5.2f, %5.2f)",i,A.realp[i],A.imagp[i]);
#endif
    // stride is that '1' , may be useful sometime.
     vDSP_fft_zrip(myFFTSetup, &A, 1, RECORD_FRAMECOUNT_LOG2, FFT_FORWARD);
#if SEE_FFT
    for(int i = 0 ; i<40;i++)
        NSLog(@"A after %d: (%5.2f, %5.2f)",i,A.realp[i],A.imagp[i]);
    
#endif
    vDSP_ztoc(&A, 1, (COMPLEX *) myFFT , 2, N/2);
    
#if SEE_FFT
    for(int i = 0 ; i<80;i++)
        NSLog(@"fft %d: %5.2f",i,myFFT[i]);
#endif    
  //  NSLog(@"fftpeak: %d",fftPeak());
    normalize(myFFT,N);
}

// so, if sr is 44100, and f = 100, wl = 441
// seeing a 1024 buffer of that  represents 1024/44100 seconds.
// each sample of the buffer really is 1/44100.0, bet we only have 1024 of them.
// the harmonics represents are of 1024/44100, though.
// so to find the slot corresponding to a real frequency, 
// slot 1 is 1* (1024/44100)
// slot f(n) is n* (1024/44100)
// so  n(f) is f/(1024/44100) or f*44100/1024;

float fftAt(float f)
{
    
    float hsecs = ((float)SAMPLE_RATE/(float)RECORD_FRAMECOUNT);
    // here's the question .. where is this particulat slot?
    // hmm the 1024 slots are a linear harmonic list of 0..sr/2
     float fspot = f/hsecs ;
    float slot = 2.0*fspot;
    // average?
    int ix = slot-0.5;
    float rem = slot-(float) ix;
    float mag = fabs(myFFT[ix])* (1.0 - rem) + fabs(myFFT[ix+1])*rem; 
    return mag/(1+fabs(myFFT[0]));
}
float fftSlot(int ix)
{
    float mag =  myFFT[ix] ; 
    return mag;
}

float crude(float * x, int N, float target_f)
{
    int k = SAMPLE_RATE/target_f;
    int k2 = k/2;
   // f would have to be about 86, not likely!
    if(k*1.5>N/2)
        return 0.0;
    
    // multiply x[0..K-1] with x[K..2K-1]
    // also .. -x[k/2]
    float sum= 0;
    for(int i = 0;i<k;i++)
    {
        sum += (x[i]*x[i+k]);    
        sum += (x[i+k2]*x[i+k+k2]);    
    }
    return sqrt(sum)/k;
};


@end
