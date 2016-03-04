//
//  EncodedData.h
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/4/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#ifndef EncodedData_h
#define EncodedData_h

@interface EncodedData : NSObject {
    
}

// These properties are per frame
// a1, a2, ... ap
@property float* coefficient;

// log(k1), log(k2), k3, k4, ... kp
@property float** parcoCoefficient;

// T
@property int* pitchPeriod;

// G
@property float* gain;

// Voice or Unvoice
@property BOOL* isvoice;

@end

#endif /* EncodedData_h */
