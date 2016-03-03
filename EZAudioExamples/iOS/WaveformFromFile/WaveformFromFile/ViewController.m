//
//  ViewController.m
//  WaveformFromFile
//
//  Created by Syed Haris Ali on 12/1/13.
//  Updated by Syed Haris Ali on 1/23/16.
//  Copyright (c) 2013 Syed Haris Ali. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "ViewController.h"
#import "LPCEncoder.h"

@implementation ViewController

//------------------------------------------------------------------------------
#pragma mark - Status Bar Style
//------------------------------------------------------------------------------

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

//------------------------------------------------------------------------------
#pragma mark - Customize the Audio Plot
//------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //
    // Customizing the audio plot's look
    //
    
    //
    // Background color
    //
    self.audioPlot.backgroundColor = [UIColor colorWithRed: 0.169 green: 0.643 blue: 0.675 alpha: 1];
    
    //
    // Waveform color
    //
    self.audioPlot.color = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    
    //
    // Plot type
    //
    self.audioPlot.plotType = EZPlotTypeBuffer;
    
    //
    // Fill
    //
    self.audioPlot.shouldFill = YES;
    
    //
    // Mirror
    //
    self.audioPlot.shouldMirror = YES;
    
    //
    // No need to optimze for realtime
    //
    self.audioPlot.shouldOptimizeForRealtimePlot = NO;
    
    //
    // Customize the layer with a shadow for fun
    //
    self.audioPlot.waveformLayer.shadowOffset = CGSizeMake(0.0, 1.0);
    self.audioPlot.waveformLayer.shadowRadius = 0.0;
    self.audioPlot.waveformLayer.shadowColor = [UIColor colorWithRed: 0.069 green: 0.543 blue: 0.575 alpha: 1].CGColor;
    self.audioPlot.waveformLayer.shadowOpacity = 1.0;
    
    //
    // Load in the sample file
    //
    [self openFileWithFilePathURL:[NSURL fileURLWithPath:kAudioFileDefault]];
    
}

#pragma mark - Fetch Did Finished
- (void)fetchDidComplete: (NSNotification *) notification {
    
    // Convert NSMutableArray to float array
    NSMutableArray *myArray = [notification object];
    float *data = (float*) malloc(sizeof(float) * [myArray count]);
    for (int i = 0; i < [myArray count]; i++) {
        data[i] = [[myArray objectAtIndex:i] floatValue];
    }
    NSLog(@"Finally got here! and data[0] is %f", data[0]);
    
    // TODO start working on the real audio data from here
    LPCEncoder *encoder = [[LPCEncoder alloc] init];
    encoder.data = data;
    [encoder encoderTop];
    
    // remove notification
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"fetchDidComplete"
                                                  object:nil];
}


//------------------------------------------------------------------------------
#pragma mark - Action Extensions
//------------------------------------------------------------------------------

- (void)openFileWithFilePathURL:(NSURL*)filePathURL
{
    self.audioFile = [EZAudioFile audioFileWithURL:filePathURL];
    self.filePathLabel.text = filePathURL.lastPathComponent;
    
    //
    // Plot the whole waveform
    //
    self.audioPlot.plotType = EZPlotTypeBuffer;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = YES;
    
    
    // TODO this should be SampleRate in practice
    int reSampleRate = 1000;
    __block float *data = (malloc(sizeof(float)*100000));
    
    //
    // Get the audio data from the audio file
    //
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fetchDidComplete:)
                                                 name:@"fetchDidComplete"
                                               object:nil];
    
    __weak typeof (self) weakSelf = self;
    [self.audioFile getWaveformDataWithCompletionBlockResolution:^(float **waveformData,
                                                         int length)
    {
        [weakSelf.audioPlot updateBuffer:waveformData[0]
                          withBufferSize:length];
        
        // First channel deep copy
        //data = (float*) (malloc(sizeof(float)*length));
        for (int i = 0; i < length; i++) {
            data[i] = waveformData[0][i];
        }
        
        // float Array and NSMutableArray Conversion for Notification Sending
        NSMutableArray *myArray = [NSMutableArray arrayWithCapacity:length];
        for (int i = 0; i < length; i++) {
            NSNumber *number = [[NSNumber alloc] initWithFloat:waveformData[0][i]];
            [myArray addObject:number];
        }
        // Auctually send the notification and myArray is transferred to the receiver
        [[NSNotificationCenter defaultCenter] postNotificationName:@"fetchDidComplete"
                                                            object:myArray
                                                          userInfo:nil];
        
        NSLog(@"inside block data[0]: %f", data[0]);
        
    } reSampleRate:reSampleRate];
}

@end
