//
//  LPCEncoder.h
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/2/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#ifndef LPCEncoder_h
#define LPCEncoder_h

#define LPCDefaultOrder 10
#define BitsPerFrame 54
#define SampleRate 8000
#define frameDuration 0.02

@interface LPCEncoder : NSObject {
    
}

@property float* data;

// Estimate the LPC-10's 10 coefficients
- (float *) coefficientEstimate;

// Estimate the pitchPeriod
- (float) pitchPeriodEstimate: (float*) frameData
                  frameLength:(int) frameLength;

// Estimate the Gain
- (float) gainEstimate;

// voiced or Unvoiced judgement
- (BOOL) isVoiced;

- (float *) encoderTop;

@end


#endif /* LPCEncoder_h */
