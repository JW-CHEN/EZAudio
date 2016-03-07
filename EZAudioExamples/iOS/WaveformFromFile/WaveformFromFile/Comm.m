//
//  Comm.m
//  WaveformFromFile
//
//  Created by Jiawei Chen on 3/6/16.
//  Copyright © 2016 Syed Haris Ali. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Comm.h"

@implementation Comm

- (void) saveToFile:(float *)dataFrame dataLength:(int)dataLength {
    NSString* filepath = [NSHomeDirectory() stringByAppendingPathComponent:@"output.txt"];
    NSLog(@"%@",filepath);
    NSString* textToWrite = @"";
    NSError *err;
    for (int i = 0; i < dataLength; i++) {
        textToWrite = [textToWrite stringByAppendingString:[NSString stringWithFormat:@"decodedWaveform[%d]: %f\n", i, dataFrame[i]]];
    }
    // Do not use NSUnicodeStringEncoding, it will add "@" before every character
    [textToWrite writeToFile:filepath atomically:YES encoding:NSUTF8StringEncoding error:&err];
}

@end