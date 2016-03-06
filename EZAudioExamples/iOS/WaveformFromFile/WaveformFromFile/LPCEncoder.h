//
//  LPCEncoder.h
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/2/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#import "EncodedData.h"
#import "Comm.h"

#ifndef LPCEncoder_h
#define LPCEncoder_h

#define ZeroCrossRateThreshold 0.6
#define CorrToAutocorrThreshold 0.3


@interface LPCEncoder : NSObject {
    
}

// These properties are per audio waveform
@property float* data;

@property int dataLength;

@property EncodedData *encodedData;

// Estimate the LPC-10's 10 coefficients
- (float*) coefficientEstimate: (float*) frameData
                    frameLength:(int) frameLength;

// Estimate the pitchPeriod
- (int) pitchPeriodEstimate:(float*) frameData
                  frameLength:(int) frameLength;

// Estimate the Gain
- (float) gainEstimate: (float*) frameData
           frameLength: (int) frameLength
            frameNumer: (int) frameNumber ;

// voiced or Unvoiced judgement
- (BOOL) isVoiced:(float*) frameData
      frameLength:(int) frameLength;

- (void) encoderTop;

@end


#endif /* LPCEncoder_h */
