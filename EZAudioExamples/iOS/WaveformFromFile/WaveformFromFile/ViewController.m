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
#import "Comm.h"
#import "LPCEncoder.h"
#import "LPCDecoder.h"
#import <malloc/malloc.h>

@interface ViewController ()

@property (nonatomic, strong) AEAudioController *audioController; // The Amazing Audio Engine
@property (nonatomic, strong) AEBlockChannel *audioChannel; // our noise 'generator'

@end

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
    self.audioPlot.waveformLayer.shadowOpacity = 0.5;
    
    //
    // Load in the sample file
    //
    //[self openFileWithFilePathURL:[NSURL fileURLWithPath:kAudioFileDefault]];
    
}

#pragma mark - Fetch Did Finished
- (void)fetchDidComplete: (NSNotification *) notification {
   
    LPCEncoder *encoder = [[LPCEncoder alloc] init];
    LPCDecoder *decoder = [[LPCDecoder alloc] init];
    
    // Convert NSMutableArray to float array
    NSMutableArray *myArray = [notification object];
    encoder.dataLength = (int) [myArray count];
    float *data = (float*) malloc(sizeof(float) * encoder.dataLength);
    for (int i = 0; i < encoder.dataLength; i++) {
        data[i] = [[myArray objectAtIndex:i] floatValue];
        //NSLog(@"data[%d] %f", i, data[i]);
    }
    
    
    
    // TODO start working on the real audio data from here
    encoder.data = data;
    [encoder encoderTop];
    // Pass Encoded Data to decoder object
    decoder.encodedData = encoder.encodedData;
    float* decodedData = [decoder decoderTop];
    float maxValue = -INFINITY;
    for (int i = 0; i < encoder.dataLength; i++) {
        if (decodedData[i] > maxValue)
            maxValue = decodedData[i];
    }
    for (int i = 0; i < encoder.dataLength; i++)
        decodedData[i] = decodedData[i] / maxValue;
    
    float* combinedData = malloc(sizeof(float) * encoder.dataLength * 2);
    for (int i = 0; i < encoder.dataLength*2; i++) {
        if (i < encoder.dataLength)
            combinedData[i] = data[i] / 2.0;
        else {
            combinedData[i] = decodedData[i-encoder.dataLength] / 4.0;
        }
    }
    
    UInt32* bufferSizeArr = malloc(sizeof(int) * 2);
    bufferSizeArr[0] = encoder.dataLength;
    bufferSizeArr[1] = encoder.dataLength;
    float* yabsPosition = malloc(sizeof(float) * 2);
    yabsPosition[0] = 0.3;
    yabsPosition[1] = 0.9;
    //[self.audioPlot updateBuffer:decodedData withBufferSize:encoder.dataLength YabsPosition:0.9];
    [self.audioPlot updateBuffer:combinedData withBufferSize:bufferSizeArr YabsPosition:yabsPosition mPlot:2];
    
//    for (int i = 1; i < encoder.encodedData.dataLength; i ++) {
//        decoder.decodedData[i-1] = decoder.decodedData[i] + decoder.decodedData[i-1];
//        //NSLog(@"decoder data[%d]: %f", i, decoder.decodedData[i-1]);
//    }
    
    // Make sound via decoder.decodedData & TheAmazingAudioEngine
    //[self playAudioFromFloatArray: decoder.decodedData
    //                   dataLength: (int) encoder.dataLength];
    
    // remove notification
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"fetchDidComplete"
                                                  object:nil];
}

# pragma mark - PlayAudioFromFloatArray
//static void cleanupHandler(AEAudioController *audioController, void *userInfo, int userInfoLength) {
//    struct cleanUpHandlerArgs *arg = (struct cleanUpHandlerArgs*)userInfo;
//    free(arg->buffer);
//    [audioController removeChannels:@[arg->channel]];
//}
//
//struct cleanUpHandlerArgs { float *buffer; __unsafe_unretained AEBlockChannel *channel; };
//
//- (void) playAudioFromFloatArray: (float*) dataWaveForm
//                      dataLength: (int) dataLength {
//    srand48(time(0));
//    // specify float point audio format
//    AudioStreamBasicDescription audioFormat = [AEAudioController nonInterleavedFloatStereoAudioDescription];
//    // setup the amazing audio engine
//    self.audioController = [[AEAudioController alloc] initWithAudioDescription:audioFormat];
//    float * buffer = (float*) malloc(sizeof(float) * dataLength);
//    for (int i = 0; i < dataLength; i++) {
//        buffer[i] = dataWaveForm[i];
//    }
//    
//    __block int remainingDataLength = dataLength;
//    __block BOOL processing = YES;
//    __weak typeof(self) weakSelf = self;
//    __block AEBlockChannel *channel = nil;
//    // create a channel of audio
//    //AEBlockChannel *audioChannel = [AEBlockChannel channelWithBlock:^(const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
//    channel = [AEBlockChannel channelWithBlock:^(const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
//        while (processing && frames) {
//            if (remainingDataLength == 0) {
//                processing = false;
//                struct cleanUpHandlerArgs args = {buffer, channel};
//                AEAudioControllerSendAsynchronousMessageToMainThread(weakSelf.audioController,
//                                                                     cleanupHandler,
//                                                                     &args,
//                                                                     sizeof(struct cleanUpHandlerArgs));
//                return;
//            }
//        
//                // Non-Interleaved Stereo formats should have two -- one for left one for right)
//                // UInt32 numberOfBuffers = audio->mNumberBuffers;
//                // Currently only work for one channel
//
//            //UInt32 numberOfBuffers = 1;
//            
//            // iterate over the buffers
//            //for (int i = 0; i < numberOfBuffers; i++) {
//                
//                UInt32 currFrame = MIN(remainingDataLength,frames);
//                // Tell the buffer how big it needs to be. (frames == samples)
//                audio->mBuffers[0].mDataByteSize = currFrame * sizeof(float);
//                
//                // Get a pointer to our output. We'll write samples here, and we'll hear
//                // those samples through the speaker.
//                float *output = (float *)audio->mBuffers[0].mData;
//                
//                // Compute the samples
//                for (int j = 0; j < currFrame; j++) {
//                    // Filling out random values will give us noise:
//                    output[j] = (float)drand48();
//                    NSLog(@"dataWaveForm[%d]: %f", j, drand48());
//                    output[j] = dataWaveForm[j+700] * 100;
//                }
//            remainingDataLength -= currFrame;
//            //}
//        }
//    }];
//    // Turn down the volume on the channel, so the noise isn't too loud
//    [channel setVolume:.02];
//    
//    // Set description
//    AudioStreamBasicDescription audioDescription = [AEAudioController nonInterleavedFloatStereoAudioDescription];
//    audioDescription.mSampleRate = 8000;
//    channel.audioDescription = audioDescription;
//    
//    // Add the channel to the audio controller
//    [self.audioController addChannels:@[channel]];
//    
//    // Hold onto the noiseChannel
//    self.audioChannel = channel;
//    
//    // Turn on the audio controller
//    NSError *error = NULL;
//    [self.audioController start:&error];
//    
//    if (error) {
//        NSLog(@"There was an error starting the controller: %@", error);
//    }
//}


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
    
    //
    // Get the audio data from the audio file
    //
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fetchDidComplete:)
                                                 name:@"fetchDidComplete"
                                               object:nil];
    
    //__weak typeof (self) weakSelf = self;
    [self.audioFile getWaveformDataWithCompletionBlockResolution:^(float **waveformData,
                                                         int length)
    {
//        UInt32* bufferSizeArr = malloc(sizeof(int) * 1);
//        bufferSizeArr[0] = length;
//        float* yabsPosition = malloc(sizeof(float) * 1);
//        yabsPosition[0] = 0.3;
//        
//        [weakSelf.audioPlot updateBuffer:waveformData[0]
//                          withBufferSize:bufferSizeArr
//                            YabsPosition:yabsPosition
//                                   mPlot:1];
//
//        Comm *comm = [[Comm alloc] init];
//        [comm saveToFile: waveformData[0] dataLength:length];
        
        // Using difference to represent the signal
        for (int i = 1; i < length; i ++) {
            waveformData[0][i] = waveformData[0][i] - preEmphasisFilterRatio*waveformData[0][i-1];
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
        
    } reSampleRate:reSampleRate];
}

- (IBAction)inputSelector_1m:(id)sender {
    NSLog(@"s1omwb");
    [self openFileWithFilePathURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"s1omwb" ofType:@"wav"]]];
}

- (IBAction)inputSelector_2m:(id)sender {
    NSLog(@"s2omwb");
    [self openFileWithFilePathURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"s2omwb" ofType:@"wav"]]];
}

- (IBAction)inputSelector_1f:(id)sender {
    NSLog(@"s1ofwb");
    [self openFileWithFilePathURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"s1ofwb" ofType:@"wav"]]];
}

- (IBAction)inputSelector_2f:(id)sender {
    NSLog(@"s2ofwb");
    [self openFileWithFilePathURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"s2ofwb" ofType:@"wav"]]];
}
@end
