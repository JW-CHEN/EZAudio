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
                    frameLength : (int) frameLength {
    
    float* parcoCoefficient = (float*) malloc(sizeof(float) * (LPCDefaultOrder+1));
    float * R = [self autoCorrelation:frameData seqLength:frameLength corrLength:(LPCDefaultOrder+1)];
    float * E = (float*) malloc(sizeof(float) * (LPCDefaultOrder+1));
    
    // Levins Durbin Algorithm Implementation
    self.encodedData.coefficient = (float*) malloc(sizeof(float) * (LPCDefaultOrder+1));
    float ** alpha = (float**) malloc(sizeof(float*) * (LPCDefaultOrder+1));
    // first dimension is upper coefficient, second dimension is lower coefficient
    for (int i = 0; i < (LPCDefaultOrder+1); i++)
        alpha[i] = (float*) malloc(sizeof(float*) * (i+1));
    E[0] = R[0];
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
        self.encodedData.coefficient[i] = alpha[LPCDefaultOrder][i];
    
    // take logrithm for first two coefficient
    parcoCoefficient[0] = log((1-parcoCoefficient[0]) / (1+parcoCoefficient[0]));
    parcoCoefficient[1] = log((1-parcoCoefficient[1]) / (1+parcoCoefficient[1]));
    return parcoCoefficient;
}

- (int) pitchPeriodEstimate: (float*) frameData
                 frameLength: (int) frameLength {
    // TODO Using autocorrelation method to detect the pitch period
    float* autoResults = [self autoCorrelation:frameData seqLength:frameLength corrLength:frameLength];
    float pitchValue = -INFINITY;
    BOOL goingUp = false;
    int pitchPeriod = 0;
    for (int i = 1; i < frameLength; i++) {
        if ( !goingUp && autoResults[i-1] < autoResults[i]) {
            goingUp = true;
        }
        else if ( goingUp && autoResults[i-1] > autoResults[i]) {
            goingUp = false;
            if (autoResults[i-1] > pitchValue) {
                pitchValue = autoResults[i-1];
                pitchPeriod = i-1;
            }
        }
    }
    return pitchPeriod;
}

- (float) gainEstimate: (float*) frameData
           frameLength: (int) frameLength
            frameNumer: (int) frameNumber {
    // coefficientEstimation should be done first and store the coefficient property in object
    float* error = (float*) malloc(sizeof(float) * frameLength);
    float temp;
    for (int i = 0; i < frameLength; i++) {
        temp = 0.0;
        // don't use previous frame data
        for (int j = 1; j <= MIN(i, LPCDefaultOrder); j++)
            temp += frameData[i-j] * self.encodedData.coefficient[j];
        error[i] = frameData[i] - temp;
    }
    int cumulateLength = frameLength;
    if (self.encodedData.isvoice[frameNumber]) {
        cumulateLength = floor(frameLength / self.encodedData.pitchPeriod[frameNumber]);
    }
    temp = 0.0;
    for (int i = 0; i < cumulateLength; i++) {
        temp += error[i] * error[i];
    }
    if (frameNumber == 6)
        NSLog(@"temp %f, cumulateLength %d", temp, cumulateLength);
    return temp / cumulateLength;
}

- (BOOL) isVoiced : (float*) frameData
      frameLength :(int) frameLength {
    
     // Using Autocorrelation method First
    float* autoResults = [self autoCorrelation:frameData seqLength:frameLength corrLength:frameLength];
    float autoCorr = autoResults[0];
    BOOL goingUp = false;
    for (int i = 1; i < frameLength; i++) {
        if ( !goingUp && autoResults[i-1] < autoResults[i]) {
            goingUp = true;
        }
        else if ( goingUp && autoResults[i-1] > autoResults[i]) {
            goingUp = false;
            if (autoResults[i-1] / autoCorr > CorrToAutocorrThreshold) {
                //TODO: input2.wav (22.5ms) frameNumber 6 has small gain but high corrToAutocorrRate. How to diff?
                //NSLog(@"autoCorr %f", autoCorr);
                //NSLog(@"autoResults %d: %f", i-1, autoResults[i-1]);
                return true;
            }
        }
    }
    
    /*
     // Method 1: Using only zero-crossing first
     float zeroCrossCount = 0.0;
     BOOL largerThanZero = true;
     for (int i = 0; i < frameLength; i++) {
     if (largerThanZero && frameData[i] < 0) {
     zeroCrossCount += 1;
     largerThanZero = false;
     } else if (!largerThanZero && frameData[i] > 0) {
     zeroCrossCount += 1;
     largerThanZero = true;
     }
     }
     if ((zeroCrossCount / frameLength) > ZeroCrossRate)
     return true;
     else
     return false;
     */
    
    return false;
}

- (void) encoderTop {
    // Initial EncodedData Object to store all the results
    self.encodedData = [[EncodedData alloc] init];
    
    // TODO non-completion intLength specify how many 32 bit integer to store all 54 encoded bits
    //UInt32 intLength = floor(BitsPerFrame / 32) + 1;
    //float * encodeFrameBitStream = (float*) malloc(sizeof(float)*intLength);
    
    
    // in http://www.seas.ucla.edu/spapl/projects/ee214aW2002/1/report.html
    // fr: Frame time increment <==> movePointsPerFrame
    // fs: Frame size in ms <==> mPointsPerFrame
    int mPointsPerFrame = frameDuration * SampleRate;
    // Including overlapping between frames
    int overlapPerFrame = mPointsPerFrame / 2;
    //int overlapPerFrame = 0;
    int movePointsPerFrame = mPointsPerFrame - overlapPerFrame;
    
    // Estimate everything below and set the property for the object
    int currentFrameLength;
    int remainingPoints = self.dataLength;
    int mFrame = floor(self.dataLength/movePointsPerFrame)+1;
    self.encodedData.isvoice = (BOOL*) malloc(sizeof(BOOL) * mFrame);
    self.encodedData.gain = (float*) malloc(sizeof(float) * mFrame);
    self.encodedData.pitchPeriod = (int*) malloc(sizeof(int) * mFrame);
    self.encodedData.parcoCoefficient = (float**) malloc(sizeof(float*) * mFrame);
    
    for (int i = 0; i < mFrame; i++) {
        float* waveFrame = self.data + movePointsPerFrame * i;
        currentFrameLength = MIN(mPointsPerFrame, remainingPoints);
        self.encodedData.isvoice[i] = [self isVoiced:waveFrame frameLength:currentFrameLength];
        self.encodedData.pitchPeriod[i] = [self pitchPeriodEstimate:waveFrame frameLength:mPointsPerFrame];
        self.encodedData.parcoCoefficient[i] = [self coefficientEstimate:waveFrame frameLength:currentFrameLength];
        self.encodedData.gain[i] = [self gainEstimate:waveFrame frameLength:currentFrameLength frameNumer:i];
        remainingPoints -= movePointsPerFrame;
        if (!self.encodedData.isvoice[i])
            NSLog(@"Unvoiced Frame %d, gain: %f", i, self.encodedData.gain[i]);
        else
            NSLog(@"Voiced Frame %d, pitchPeriod %d, gain: %f, parcoCoefficient %f", i, self.encodedData.pitchPeriod[i], self.encodedData.gain[i], self.encodedData.parcoCoefficient[i][3]);
    }
    
    // TODO test pitchPeriodEstimate
    //[self testAutoCorrelation];
    //[self testPitchEstimation];
    
    // TODO Forming the bitstream frame
    //return encodeFrameBitStream;
}

#pragma mark - TestFunctionImplementation

- (void) testAutoCorrelation {
    float * testSequence = (float*) malloc(sizeof(float)*10);
    for (int i = 0; i < 10; i++)
        testSequence[i] = i;
    float * result;
    result = [self autoCorrelation:testSequence seqLength:10 corrLength:10];
    for (int i = 0; i < 10; i++)
        NSLog(@"auto %f", result[i]);
}

- (void) testPitchEstimation {
    float dataFrame[13] = {1, 0.85, 0.1, -1, -0.5, 0.4, 0.6, 0.5, 0.3, 0.2, 0.7, 0.9, 0.4};
    [self pitchPeriodEstimate:dataFrame frameLength:13];
    //NSLog(@"pitchPeriod: %f", pitchPeriod);
}

@end