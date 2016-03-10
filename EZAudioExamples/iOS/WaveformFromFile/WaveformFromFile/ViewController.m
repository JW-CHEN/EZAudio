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
    }
    NSLog(@"orignal dataLength after sampling %d", encoder.dataLength);
    
    
    
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
    
    Comm *comm = [[Comm alloc] init];
    [comm saveToFile:decodedData dataLength:encoder.dataLength];
    
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
    [self.audioPlot updateBuffer:combinedData withBufferSize:bufferSizeArr YabsPosition:yabsPosition mPlot:2];
    
    // remove notification
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"fetchDidComplete"
                                                  object:nil];
    
    // create notification for audio file write
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(outputRawDataToWAVFile:)
                                                 name:@"outputRawDataToWAVFile"
                                               object:nil];
    // float Array and NSMutableArray Conversion for Notification Sending
    NSMutableArray *decodeDataArray = [NSMutableArray arrayWithCapacity:encoder.dataLength];
    for (int i = 0; i < encoder.dataLength; i++) {
        NSNumber *number = [[NSNumber alloc] initWithFloat:decodedData[i]];
        [myArray addObject:number];
    }
    NSLog(@"First Here!");
    // Auctually send the notification and myArray is transferred to the receiver
    [[NSNotificationCenter defaultCenter] postNotificationName:@"outputRawDataToWAVFile"
                                                        object:decodeDataArray
                                                      userInfo:nil];
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
    int reSampleRate = 8000;
    
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
    NSURL *audioFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"s1omwb" ofType:@"wav"]];
    [self openFileWithFilePathURL: audioFileURL];
}

- (IBAction)inputSelector_2m:(id)sender {
    NSLog(@"s2omwb");
    NSURL *audioFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"s2omwb" ofType:@"wav"]];
    [self openFileWithFilePathURL: audioFileURL];
}

- (IBAction)inputSelector_1f:(id)sender {
    NSLog(@"s1ofwb");
    NSURL *audioFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"s1ofwb" ofType:@"wav"]];
    [self openFileWithFilePathURL: audioFileURL];
}

- (IBAction)inputSelector_2f:(id)sender {
    NSLog(@"s2ofwb");
    NSURL *audioFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"s2ofwb" ofType:@"wav"]];
    [self openFileWithFilePathURL: audioFileURL];
}

- (void) outputRawDataToWAVFile: (NSNotification *) notification {
    NSLog(@"Then Here!");

    AudioStreamBasicDescription outputFormat = {0};
    outputFormat.mSampleRate = 16000;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mBitsPerChannel = 32;
    outputFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBytesPerFrame = 4;
    outputFormat.mBytesPerPacket = 4;
    
    AudioFileID outputFile;
    NSURL* outputDirNSURL = [[NSURL alloc] initWithString: [[NSBundle mainBundle] bundlePath]];
    NSURL* outputFileNSURL = [outputDirNSURL URLByAppendingPathComponent:@"decoded.wav"];
    NSLog(@"%@", outputFileNSURL);
    
    CFURLRef outputFileURL =
    CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("decoded.wav"), kCFURLPOSIXPathStyle, FALSE);
    
    AudioFileCreateWithURL((__bridge CFURLRef)outputFileNSURL, kAudioFileWAVEType, &outputFormat, kAudioFileFlags_EraseFile, &outputFile);
    
    // Convert NSMutableArray to float array
    NSMutableArray *myArray = [notification object];
    int dataLength = (int) [myArray count];
    UInt32 sizeOfBuffer = (UInt32) dataLength * sizeof(float);
    float *audioBuffer = (float*)malloc(sizeOfBuffer);
    
    for (int i = 0; i < dataLength; i++) {
        audioBuffer[i] = [[myArray objectAtIndex:i] floatValue];
    }
    AudioFileWriteBytes(outputFile, FALSE, 0, &sizeOfBuffer, audioBuffer);
    
    self._audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:outputFileNSURL error:nil];
    [self._audioPlayer play];
    
    CFRelease(outputFileURL);
    AudioFileClose(outputFile);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"outputRawDataToWAVFile"
                                                  object:nil];
}

@end
