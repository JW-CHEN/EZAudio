//
//  LPCDecoder.h
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/4/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#import "Comm.h"
#import "EncodedData.h"

#ifndef LPCDecoder_h
#define LPCDecoder_h

@interface LPCDecoder: NSObject {
    
}

@property EncodedData* encodedData;

@property float* decodedData;


- (float*) decoderTop;

@end


#endif /* LPCDecoder_h */
