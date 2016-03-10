//
//  LPCEncoder.m
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/2/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPCEncoder.h"
#import "EncodedData.h"
#import <Accelerate/Accelerate.h>

@interface LPCEncoder()

// This is the private method of LPCEncoder method
- (float*) autoCorrelation: (float*) sequence
                seqLength: (int) seqLength
                corrLength: (int) corrLength;

@end

@implementation LPCEncoder

- (float*) autoCorrelation: (float*) sequence
                seqLength: (int) seqLength
                corrLength: (int) corrLength {
    
    float * autoResults = (float*) malloc(sizeof(float)*corrLength);
    float sum;
    
    for (int step = 0; step < corrLength; step++) {
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

- (float*) coefficientEstimate : (float*) frameData
                    frameLength: (int) frameLength
                    frameNumber: (int) frameNumber {
    float* coefficient = (float*) malloc(sizeof(float) * (LPCDefaultOrder+1));
    float* parcoCoefficient = (float*) malloc(sizeof(float) * (LPCDefaultOrder+1));
    float * R = [self autoCorrelation:frameData seqLength:frameLength corrLength:(LPCDefaultOrder+1)];
    float * E = (float*) malloc(sizeof(float) * (LPCDefaultOrder+1));
    
    // Levins Durbin Algorithm Implementation
    float ** alpha = (float**) malloc(sizeof(float*) * (LPCDefaultOrder+1));
    // first dimension is upper coefficient, second dimension is lower coefficient
    for (int i = 0; i < (LPCDefaultOrder+1); i++)
        alpha[i] = (float*) malloc(sizeof(float*) * (i+1));
    E[0] = R[0];
    parcoCoefficient[0] = 0;
    float temp;
    for (int i = 1; i < (LPCDefaultOrder+1); i++) {
        temp = 0.0;
        for (int j = 1; j < i; j++) {
            temp += alpha[i-1][j]*R[i-j];
        }
        parcoCoefficient[i] = (R[i] - temp) / E[i-1];
        alpha[i][i] = parcoCoefficient[i];
        if (i > 1) {
            for (int j = 1; j < i; j++) {
                alpha[i][j] = alpha[i-1][j] - parcoCoefficient[i]*alpha[i-1][i-j];
            }
        }
        E[i] = (1 - parcoCoefficient[i]*parcoCoefficient[i])*E[i-1];
        
    }
    for (int i = 1; i < (LPCDefaultOrder+1); i++)
        coefficient[i] = alpha[LPCDefaultOrder][i];
    
    // take logrithm for first two coefficient
    parcoCoefficient[0] = log((1-parcoCoefficient[0]) / (1+parcoCoefficient[0]));
    parcoCoefficient[1] = log((1-parcoCoefficient[1]) / (1+parcoCoefficient[1]));
    
    // Complete all the estimation here: pitchPeriod (include isvoice info), gain
    
    // Use energy to predict:
    float energy = 0.0;
    float zeroCrossCnt = 0.0;
    for (int i = 0; i < frameLength; i++) {
        energy += fabsf(frameData[i]);
        if (i < frameLength-1 && ((frameData[i] > 0 && frameData[i+1] < 0) ||
            (frameData[i] < 0 && frameData[i+1] > 0)))
            zeroCrossCnt += 1;
    }
    
    // pitchPeriod:
    self.encodedData.pitchPeriod[frameNumber] = 0;
    //if (energy > energyThreshold && zeroCrossCnt/frameLength < ZeroCrossRateThreshold) {
        float* predictionError = (float*) malloc(sizeof(float) * frameLength);
        for (int i = 0; i < frameLength; i++) {
            temp = 0.0;
            // don't use previous frame data
            for (int j = 1; j <= MIN(i, LPCDefaultOrder); j++)
                temp += frameData[i-j] * coefficient[j];
            predictionError[i] = frameData[i] - temp;
        }
        float* autoForError = [self autoCorrelation: predictionError seqLength: frameLength corrLength: frameLength];
        float sndLargestValue = -INFINITY;
        for (int i = 1; i < frameLength; i++) {
            if (autoForError[i] > sndLargestValue) {
                sndLargestValue = autoForError[i];
                if (autoForError[i] > 0.05 * autoForError[0])
                    self.encodedData.pitchPeriod[frameNumber] = i;
            }
        }
    //}
    
    // G:
    self.encodedData.gain[frameNumber] = sqrt(E[LPCDefaultOrder]);
    if (self.encodedData.pitchPeriod[frameNumber] != 0)
        self.encodedData.gain[frameNumber] *= sqrt(self.encodedData.pitchPeriod[frameNumber]);
    
    return coefficient;
}

- (void) encoderTop {
    // Initial EncodedData Object to store all the results
    self.encodedData = [[EncodedData alloc] init];
    
    int mPointsPerFrame = frameDuration * SampleRate;
    // Including overlapping between frames (LPC 10 has no overlap, so the overlapRate = 0)
    int overlapPerFrame = mPointsPerFrame * overlapRate;
    //int overlapPerFrame = 0;
    int movePointsPerFrame = mPointsPerFrame - overlapPerFrame;
    
    // Estimate everything below and set the property for the object
    int currentFrameLength;
    int remainingPoints = self.dataLength;
    NSLog(@"dataLength %d", self.dataLength);
    int mFrame = floor(self.dataLength/movePointsPerFrame)+1;
    self.encodedData.dataLength = self.dataLength;
    self.encodedData.mFrame = mFrame;
    self.encodedData.isvoice = (BOOL*) malloc(sizeof(BOOL) * mFrame);
    self.encodedData.gain = (float*) malloc(sizeof(float) * mFrame);
    self.encodedData.pitchPeriod = (int*) malloc(sizeof(int) * mFrame);
    self.encodedData.coefficient = (float**) malloc(sizeof(float*) * mFrame);
    self.encodedData.parcoCoefficient = (float**) malloc(sizeof(float*) * mFrame);
    
    for (int i = 0; i < mFrame; i++) {
        float* waveFrame = self.data + movePointsPerFrame * i;
        currentFrameLength = MIN(mPointsPerFrame, remainingPoints);
        self.encodedData.coefficient[i] = [self coefficientEstimate:waveFrame frameLength:currentFrameLength frameNumber:i];
        remainingPoints -= movePointsPerFrame;
    }

}

@end