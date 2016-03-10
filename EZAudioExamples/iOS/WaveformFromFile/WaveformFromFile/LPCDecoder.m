//
//  LPCDecoder.m
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/4/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LPCDecoder.h"
#import <stdlib.h>

@interface LPCDecoder()

// This is the private method of LPCDecoder method
- (float*) generatePulseTrain: (int) frameNumber;

@end

@implementation LPCDecoder

- (float*) generatePulseTrain: (int) frameNumber {
    int mPointsPerFrame = frameDuration * SampleRate;
    float* pulseTrain;
    pulseTrain = (float*) malloc(sizeof(float) * mPointsPerFrame);
    for (int i = 0; i < mPointsPerFrame; i++)
        pulseTrain[i] = 0;
    
    // voiced pulse train
    if (self.encodedData.pitchPeriod[frameNumber] > 0) {
        //NSLog(@"voiced frame");
        int period = self.encodedData.pitchPeriod[frameNumber];
        int mPeriod = floor((mPointsPerFrame-1) / period) + 1;
        srand48(time(0));
        for (int i = 0; i < mPeriod; i++)
            pulseTrain[i*period] = 1;
        for (int i = 0; i < mPointsPerFrame; i++)
            pulseTrain[i] += 0.01*drand48();
    } // unvoiced pulse train
    else {
        //NSLog(@"unvoiced frame");
        for (int i = 0; i < mPointsPerFrame; i++)
            pulseTrain[i] = drand48();
    }
    return pulseTrain;
}

- (float*) decoderTop {
    int mFrame = self.encodedData.mFrame;
    float* pulseTrainForFrame;
    int mPointsPerFrame = frameDuration * SampleRate;
    int overlapPerFrame = mPointsPerFrame * overlapRate;
    int movePerFrame = mPointsPerFrame - overlapPerFrame;
    float** syncDataFrame = (float**) malloc(sizeof(float*) * mFrame);
    for (int i = 0; i < mFrame; i++)
        syncDataFrame[i] = (float*) malloc(sizeof(float) * mPointsPerFrame);
    self.decodedData = (float*) malloc(sizeof(float) * self.encodedData.dataLength);
    int remainDataLength = self.encodedData.dataLength;
    int currFrameDataLength;
    
    float predictPastSignal;
    for (int i = 0; i < mFrame; i++) {
        pulseTrainForFrame = [self generatePulseTrain: i];

        // Step 1: Passing G and filter with self.encodedData.coefficient
        currFrameDataLength = MIN(remainDataLength, mPointsPerFrame);
        for (int m = 0; m < currFrameDataLength; m++) {
            predictPastSignal = 0.0;
            for (int j = m-1; j >= MAX(m-10,0); j--) {
                // This array has length LPCDefaultOrder+1, a1 --> coefficient[1]
                predictPastSignal += self.encodedData.coefficient[i][m-j]*syncDataFrame[i][j];
            }
            syncDataFrame[i][m] = predictPastSignal + self.encodedData.gain[i]*pulseTrainForFrame[m];
        }
        
        // Step 2: Combine the overlapped waveform
        for (int j = 0; j < MIN(movePerFrame, remainDataLength); j++)
            self.decodedData[i*movePerFrame + j] = syncDataFrame[i][j];
        
        // Step 3: Update remainDatalength
        remainDataLength -= movePerFrame;
    }
    
    
    for (int i = 1; i < self.encodedData.dataLength; i++) {
        self.decodedData[i] = self.decodedData[i] + self.decodedData[i-1]*preEmphasisFilterRatio;
    }
    
    return self.decodedData;
}


@end