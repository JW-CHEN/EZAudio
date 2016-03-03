//
//  LPCEncoder.m
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/2/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPCEncoder.h"

@interface LPCEncoder()

// This is the private method of LPCEncoder method
- (float*) autoCorrelation: (float*) sequence
                seqLength: (int) seqLength;

@end

@implementation LPCEncoder

- (float*) autoCorrelation: (float*) sequence
                seqLength: (int) seqLength{
    float * autoResults = (float*) malloc(sizeof(float)*seqLength);
    float sum;
    for (int step = 0; step < seqLength; step++) {
        sum = 0;
        for (int i = 0; i < seqLength - step; i++) {
            // TODO vDSP_hann_window can include window function (check vDSP)
            sum += sequence[i] * sequence[i+step];
        }
        autoResults[step] = sum;
        //NSLog(@"autoResults %d: %f", step, autoResults[step]);
    }
    return autoResults;
}

#pragma mark - EstimationFunctions

- (float *) coefficientEstimate {
    float * dummy;
    return dummy;
}

- (float) pitchPeriodEstimate: (float*) frameData
                 frameLength :(int) frameLength {
    // TODO Using autocorrelation method to detect the pitch period
    float* autoResults = [self autoCorrelation:frameData seqLength:frameLength];
    float sndLocalMaxima = -INFINITY;
    BOOL goingUp = false;
    for (int i = 1; i < frameLength; i++) {
        if ( !goingUp && autoResults[i-1] < autoResults[i]) {
            goingUp = true;
        }
        else if ( goingUp && autoResults[i-1] > autoResults[i]) {
            goingUp = false;
            if (autoResults[i-1] > sndLocalMaxima)
                sndLocalMaxima = autoResults[i-1];
        }
    }
    return sndLocalMaxima;
}

- (float) gainEstimate {
    return 0.0;
}

- (BOOL) isVoiced {
    return YES;
}

- (float *) encoderTop {
    // intLength specify how many 32 bit integer to store all 54 encoded bits
    UInt32 intLength = floor(BitsPerFrame / 32) + 1;
    float * encodeFrameBitStream = (float*) malloc(sizeof(float)*intLength);
    
    int mPointsPerFrame = frameDuration * SampleRate;
    
    // Estimate everything below
    float pitchPeriod;
    for (int i = 0; i < 1; i++) {
        float* waveFrame = self.data + mPointsPerFrame * i;
        pitchPeriod = [self pitchPeriodEstimate:waveFrame frameLength:mPointsPerFrame];
    }
    
    // TODO test pitchPeriodEstimate
    //[self testAutoCorrelation];
    [self testPitchEstimation];
    
    // TODO Forming the bitstream frame
    
    return encodeFrameBitStream;
}

#pragma mark - TestFunctionImplementation

- (void) testAutoCorrelation {
    float * testSequence = (float*) malloc(sizeof(float)*10);
    for (int i = 0; i < 10; i++)
        testSequence[i] = i;
    float * result;
    result = [self autoCorrelation:testSequence seqLength:10];
    for (int i = 0; i < 10; i++)
        NSLog(@"auto %f", result[i]);
}

- (void) testPitchEstimation {
    float dataFrame[13] = {1, 0.85, 0.1, -1, -0.5, 0.4, 0.6, 0.5, 0.3, 0.2, 0.7, 0.9, 0.4};
    float pitchPeriod = [self pitchPeriodEstimate:dataFrame frameLength:13];
    NSLog(@"pitchPeriod: %f", pitchPeriod);
}

@end