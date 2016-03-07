//
//  Comm.h
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/4/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#ifndef Comm_h
#define Comm_h

// Define some common settings for both encoder and decoder
#define LPCDefaultOrder 10
#define BitsPerFrame 54
#define preEmphasisFilterRatio 0.93
#define SampleRate 8000
#define frameDuration 0.0225
#define overlapRate 0.4

#import <TheAmazingAudioEngine.h>

@interface Comm : NSObject {
    
}

- (void) saveToFile: (float*) dataFrame
         dataLength: (int) dataLength ;

@end


#endif /* Comm_h */
