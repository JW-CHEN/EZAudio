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
    // voiced pulse train
    if (self.encodedData.isvoice[frameNumber]) {
        NSLog(@"voiced frame");
        int period = self.encodedData.pitchPeriod[frameNumber];
        int mPeriod = floor((mPointsPerFrame-1) / period) + 1;
        srand48(time(0));
        for (int i = 0; i < mPeriod; i++)
            pulseTrain[i*period] = 1;
        for (int i = 0; i < mPointsPerFrame; i++)
            pulseTrain[i] += 0.01*drand48();
    } // unvoiced pulse train
    else {
        NSLog(@"unvoiced frame");
        for (int i = 0; i < mPointsPerFrame; i++)
            pulseTrain[i] = drand48();
    }
    return pulseTrain;
}

- (void) decoderTop {
    int mFrame = self.encodedData.mFrame;
    float* pulseTrainForFrame;
    int mPointsPerFrame = frameDuration * SampleRate;
    int overlapPerFrame = mPointsPerFrame * overlapRate;
    int movePerFrame = mPointsPerFrame - overlapPerFrame;
    float** syncDataFrame = (float**) malloc(sizeof(float*) * mFrame);
    for (int i = 0; i < mFrame; i++)
        syncDataFrame[i] = (float*) malloc(sizeof(float) * mPointsPerFrame);
    float* decodedWaveForm = (float*) malloc(sizeof(float) * self.encodedData.dataLength);
    int remainDataLength = self.encodedData.dataLength;
    int currFrameDataLength;
    float* ramp = (float*) malloc(sizeof(float)*overlapPerFrame);
    float* overlapDataFrame = (float*) malloc(sizeof(float)*overlapPerFrame);
    for (int i = 0; i < overlapPerFrame; i++)
        ramp[i] = i * (1.0/(overlapPerFrame-1));
    
    float predictPastSignal;
    for (int i = 0; i < mFrame; i++) {
        pulseTrainForFrame = [self generatePulseTrain: i];
        
        // Step 1: Passing G and filter with self.encodedData.coefficient
        currFrameDataLength = MIN(remainDataLength, mPointsPerFrame);
        for (int m = 0; m < currFrameDataLength; m++) {
            predictPastSignal = 0.0;
            for (int j = m-1; j >= MAX(m-10,0); j--) {
                // This array has length LPCDefaultOrder+1, a1 --> coefficient[1]
                predictPastSignal += self.encodedData.coefficient[m-j]*syncDataFrame[i][j];
            }
            syncDataFrame[i][m] = predictPastSignal + self.encodedData.gain[i]*pulseTrainForFrame[m];
        }
        
        // Step 2: Combine the overlapped waveform together with ramp coefficient
        if (i == 0) {
            for (int j = 0; j < movePerFrame; j++)
                decodedWaveForm[j] = syncDataFrame[0][j];
        }
        else {
            for (int j = 0; j < MIN(movePerFrame, remainDataLength); j++) {
                if (j < overlapPerFrame)
                    decodedWaveForm[i*movePerFrame + j] = overlapDataFrame[j] + syncDataFrame[i][j] * ramp[j];
                else
                    decodedWaveForm[i*movePerFrame + j] = syncDataFrame[i][j];
            }
        }
        
            // calculate overlap frame ( last frame must has length less than movePerFrame )
        if (i != mFrame - 1) {
            for (int j = 0; j < overlapPerFrame; j++)
                overlapDataFrame[j] = syncDataFrame[i][movePerFrame+j] * ramp[overlapPerFrame-1-j];
        }
        // Step 3: Update remainDatalength
        remainDataLength -= movePerFrame;
    }
    
    // [LOG in CMDLINE]
    //for (int i = 0; i < self.encodedData.dataLength; i++)
    //    NSLog(@"decodedWaveform[%d]: %f", i, decodedWaveForm[i]);
    
    // [LOG in FILE]
    NSString* filepath = [NSHomeDirectory() stringByAppendingPathComponent:@"output.txt"];
    NSLog(@"%@",filepath);
    NSString* textToWrite = @"";
    NSError *err;
    for (int i = 0; i < self.encodedData.dataLength; i++) {
        textToWrite = [textToWrite stringByAppendingString:[NSString stringWithFormat:@"decodedWaveform[%d]: %f\n", i, decodedWaveForm[i]]];
    }
    // Do not use NSUnicodeStringEncoding, it will add "@" before every character
    [textToWrite writeToFile:filepath atomically:YES encoding:NSUTF8StringEncoding error:&err];
}


@end