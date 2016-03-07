//
//  EZAudioPlot.m
//  EZAudio
//
//  Created by Syed Haris Ali on 9/2/13.
//  Copyright (c) 2015 Syed Haris Ali. All rights reserved.
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

#import "EZAudioPlot.h"

//------------------------------------------------------------------------------
#pragma mark - Constants
//------------------------------------------------------------------------------

UInt32 const kEZAudioPlotMaxHistoryBufferLength = 8192;
UInt32 const kEZAudioPlotDefaultHistoryBufferLength = 512;
UInt32 const EZAudioPlotDefaultHistoryBufferLength = 512;
UInt32 const EZAudioPlotDefaultMaxHistoryBufferLength = 8192;

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlot (Implementation)
//------------------------------------------------------------------------------

@implementation EZAudioPlot

//------------------------------------------------------------------------------
#pragma mark - Dealloc
//------------------------------------------------------------------------------

- (void)dealloc
{
    [EZAudioUtilities freeHistoryInfo:self.historyInfo];
    free(self.points);
}

//------------------------------------------------------------------------------
#pragma mark - Initialization
//------------------------------------------------------------------------------

- (id)init
{
    self = [super init];
    if (self)
    {
        [self initPlot];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initPlot];
    }
    return self;
}

#if TARGET_OS_IPHONE
- (id)initWithFrame:(CGRect)frameRect
#elif TARGET_OS_MAC
- (id)initWithFrame:(NSRect)frameRect
#endif
{
    self = [super initWithFrame:frameRect];
    if (self)
    {
        [self initPlot];
    }
    return self;
}

#if TARGET_OS_IPHONE
- (void)layoutSubviews
{
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.waveformLayer.frame = self.bounds;
    [self redraw];
    [CATransaction commit];
}
#elif TARGET_OS_MAC
- (void)layout
{
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.waveformLayer.frame = self.bounds;
    [self redraw];
    [CATransaction commit];
}
#endif

- (void)initPlot
{
    self.shouldCenterYAxis = YES;
    self.shouldOptimizeForRealtimePlot = YES;
    self.gain = 1.0;
    self.plotType = EZPlotTypeBuffer;
    self.shouldMirror = NO;
    self.shouldFill = NO;
    
    // Setup history window
    [self resetHistoryBuffers];
    
    self.waveformLayer = [EZAudioPlotWaveformLayer layer];
    self.waveformLayer.frame = self.bounds;
    self.waveformLayer.lineWidth = 1.0f;
    self.waveformLayer.fillColor = nil;
    self.waveformLayer.backgroundColor = nil;
    self.waveformLayer.opaque = YES;
    
#if TARGET_OS_IPHONE
    self.color = [UIColor colorWithHue:0 saturation:1.0 brightness:1.0 alpha:1.0]; 
#elif TARGET_OS_MAC
    self.color = [NSColor colorWithCalibratedHue:0 saturation:1.0 brightness:1.0 alpha:1.0];
    self.wantsLayer = YES;
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
#endif
    self.backgroundColor = nil;
    [self.layer insertSublayer:self.waveformLayer atIndex:0];
    
    //
    // Allow subclass to initialize plot
    //
    [self setupPlot];
    
    self.points = calloc(EZAudioPlotDefaultMaxHistoryBufferLength, sizeof(CGPoint));
    self.pointCount = [self initialPointCount];
    [self redraw];
}

//------------------------------------------------------------------------------

- (void)setupPlot
{
    //
    // Override in subclass
    //
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)resetHistoryBuffers
{
    //
    // Clear any existing data
    //
    if (self.historyInfo)
    {
        [EZAudioUtilities freeHistoryInfo:self.historyInfo];
    }
    
    self.historyInfo = [EZAudioUtilities historyInfoWithDefaultLength:[self defaultRollingHistoryLength]
                                                        maximumLength:[self maximumRollingHistoryLength]];
}

//------------------------------------------------------------------------------
#pragma mark - Setters
//------------------------------------------------------------------------------

- (void)setBackgroundColor:(id)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    self.layer.backgroundColor = [backgroundColor CGColor];
}

//------------------------------------------------------------------------------

- (void)setColor:(id)color
{
    [super setColor:color];
    self.waveformLayer.strokeColor = [color CGColor];
    if (self.shouldFill)
    {
        self.waveformLayer.fillColor = [color CGColor];
    }
}

//------------------------------------------------------------------------------

- (void)setShouldOptimizeForRealtimePlot:(BOOL)shouldOptimizeForRealtimePlot
{
    _shouldOptimizeForRealtimePlot = shouldOptimizeForRealtimePlot;
    if (shouldOptimizeForRealtimePlot && !self.displayLink)
    {
        self.displayLink = [EZAudioDisplayLink displayLinkWithDelegate:self];
        [self.displayLink start];
    }
    else
    {
        [self.displayLink stop];
        self.displayLink = nil;
    }
}

//------------------------------------------------------------------------------

- (void)setShouldFill:(BOOL)shouldFill
{
    [super setShouldFill:shouldFill];
    self.waveformLayer.fillColor = shouldFill ? [self.color CGColor] : nil;
}

//------------------------------------------------------------------------------
#pragma mark - Drawing
//------------------------------------------------------------------------------

- (void)clear
{
    if (self.pointCount > 0)
    {
        [self resetHistoryBuffers];
        float data[self.pointCount];
        memset(data, 0, self.pointCount * sizeof(float));
        [self setSampleData:data length:self.pointCount];
        [self redraw];
    }
}

//------------------------------------------------------------------------------

- (void)redraw
{
    EZRect frame = [self.waveformLayer frame];
    CGPathRef path = [self createPathWithPoints:self.points
                                     pointCount:self.pointCount
                                         inRect:frame];
    if (self.shouldOptimizeForRealtimePlot)
    {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.waveformLayer.path = path;
        [CATransaction commit];
    }
    else
    {
        self.waveformLayer.path = path;
    }
    CGPathRelease(path);
}


- (void)redraw: (float*) YabsPosition
         mPlot: (int) mPlot
{
    EZRect frame = [self.waveformLayer frame];
    CGPathRef path = [self createPathWithPoints:self.pointsArray
                                pointCountArray:self.pointCountArray
                                         inRect:frame
                                   YabsPosition:YabsPosition
                                          mPlot:mPlot];
    if (self.shouldOptimizeForRealtimePlot)
    {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.waveformLayer.path = path;
        [CATransaction commit];
    }
    else
    {
        self.waveformLayer.path = path;
    }
    CGPathRelease(path);
}

//------------------------------------------------------------------------------

- (CGPathRef)createPathWithPoints:(CGPoint *)points
                       pointCount:(UInt32)pointCount
                           inRect:(EZRect)rect
{
    CGMutablePathRef path = NULL;
    if (pointCount > 0)
    {
        path = CGPathCreateMutable();
        double xscale = (rect.size.width) / ((float)self.pointCount);
        // 4.0 means it locate in the upper 1/4 part of screen
        double halfHeight = floor(rect.size.height / 2.0);
        int deviceOriginFlipped = [self isDeviceOriginFlipped] ? -1 : 1;
        CGAffineTransform xf = CGAffineTransformIdentity;
        CGFloat translateY = 0.0f;
        if (!self.shouldCenterYAxis)
        {
#if TARGET_OS_IPHONE
            translateY = CGRectGetHeight(rect);
            NSLog(@"shouldCenterYAxis is NO with translateY :%f", translateY);
#elif TARGET_OS_MAC
            translateY = 0.0f;
#endif
        }
        else
        {
            translateY = halfHeight + rect.origin.y;
            NSLog(@"shouldCenterYAxis is YES with translateY :%f", translateY);
        }
        xf = CGAffineTransformTranslate(xf, 0.0, translateY);
        double yScaleFactor = halfHeight;
        if (!self.shouldCenterYAxis)
        {
            yScaleFactor = 2.0 * halfHeight;
        }
        NSLog(@"deviceOriginFlipped :%d, yScaleFactor :%f", deviceOriginFlipped, yScaleFactor);
        xf = CGAffineTransformScale(xf, xscale, deviceOriginFlipped * yScaleFactor);
        CGPathAddLines(path, &xf, self.points, self.pointCount);
        if (self.shouldMirror)
        {
            xf = CGAffineTransformScale(xf, 1.0f, -1.0f);
            CGPathAddLines(path, &xf, self.points, self.pointCount);
        }
        if (self.shouldFill)
        {
            CGPathCloseSubpath(path);
        }
    }
    return path;
}

- (CGPathRef)createPathWithPoints:(CGPoint **)pointsArray
                       pointCountArray:(UInt32*)pointCountArray
                           inRect:(EZRect)rect
                     YabsPosition:(float*)YabsPosition
                          mPlot:(int)mPlot
{
    CGMutablePathRef path = NULL;
    path = CGPathCreateMutable();
    for (int plotInd = 0; plotInd < mPlot; plotInd++)
    {
        double xscale = (rect.size.width) / ((float)self.pointCountArray[plotInd]);
        // 4.0 means it locate in the upper 1/4 part of screen
        double halfHeight = floor(rect.size.height / 2.0);
        int deviceOriginFlipped = [self isDeviceOriginFlipped] ? -1 : 1;
        CGAffineTransform xf = CGAffineTransformIdentity;
        CGFloat translateY = 0.0f;
        if (!self.shouldCenterYAxis)
        {
#if TARGET_OS_IPHONE
            translateY = CGRectGetHeight(rect);
            NSLog(@"shouldCenterYAxis is NO with translateY :%f", translateY);
#elif TARGET_OS_MAC
            translateY = 0.0f;
#endif
        }
        else
        {
            translateY = halfHeight * YabsPosition[plotInd] + rect.origin.y;
            NSLog(@"shouldCenterYAxis is YES with translateY :%f", translateY);
        }
        xf = CGAffineTransformTranslate(xf, 0.0, translateY);
        double yScaleFactor = halfHeight;
        if (!self.shouldCenterYAxis)
        {
            yScaleFactor = 2.0 * halfHeight;
        }
        NSLog(@"deviceOriginFlipped :%d, yScaleFactor :%f", deviceOriginFlipped, yScaleFactor);
        xf = CGAffineTransformScale(xf, xscale, deviceOriginFlipped * yScaleFactor);
        CGPathAddLines(path, &xf, self.pointsArray[plotInd], self.self.pointCountArray[plotInd]);
        if (self.shouldMirror)
        {
            xf = CGAffineTransformScale(xf, 1.0f, -1.0f);
            CGPathAddLines(path, &xf, self.pointsArray[plotInd], self.self.pointCountArray[plotInd]);
        }
        if (self.shouldFill)
        {
            CGPathCloseSubpath(path);
        }
    }
    return path;
}

//------------------------------------------------------------------------------
#pragma mark - Update
//------------------------------------------------------------------------------

- (void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize
{
    // append the buffer to the history
    [EZAudioUtilities appendBufferRMS:buffer
                       withBufferSize:bufferSize
                        toHistoryInfo:self.historyInfo];
    
    // copy samples
    
    switch (self.plotType)
    {
        case EZPlotTypeBuffer:
            NSLog(@"Type Buffer");
            [self setSampleData:buffer
                         length:bufferSize];
            break;
        case EZPlotTypeRolling:
            NSLog(@"Type Rolling");
            [self setSampleData:self.historyInfo->buffer
                         length:self.historyInfo->bufferSize];
            break;
        default:
            break;
    }
    
    // update drawing
    if (!self.shouldOptimizeForRealtimePlot)
    {
        [self redraw];
    }
}

- (void)updateBuffer:(float*)buffer
      withBufferSize:(UInt32*)bufferSize
        YabsPosition:(float*) YabsPosition
               mPlot:(int) mPlot
{
    // append the buffer to the history
//    [EZAudioUtilities appendBufferRMS:buffer
//                       withBufferSize:bufferSize
//                        toHistoryInfo:self.historyInfo];
    
    // copy samples
    NSLog(@"updateBuffer %f != %f", buffer[20], buffer[20+2915]);
    [self setSampleData:buffer
                 length:bufferSize
                  mPlot:mPlot];
    
//    switch (self.plotType)
//    {
//        case EZPlotTypeBuffer:
//            NSLog(@"Type Buffer");
//            [self setSampleData:buffer
//                         length:bufferSize];
//            break;
//        case EZPlotTypeRolling:
//            NSLog(@"Type Rolling");
//            [self setSampleData:self.historyInfo->buffer
//                         length:self.historyInfo->bufferSize];
//            break;
//        default:
//            break;
//    }
    
    // update drawing
    if (!self.shouldOptimizeForRealtimePlot)
    {
        [self redraw: (float*) YabsPosition mPlot:mPlot];
    }
}

//------------------------------------------------------------------------------

- (void)setSampleData:(float *)data length:(int)length
{
    //NSLog(@"points length: %d", length);
    CGPoint *points = self.points;
    for (int i = 0; i < length; i++)
    {
        points[i].x = i;
        points[i].y = data[i] * self.gain;
        //NSLog(@"%f", points[i].y);
    }
    points[0].y = points[length - 1].y = 0.0f;
    self.pointCount = length;
}

- (void)setSampleData:(float *)data length:(UInt32*)length mPlot:(int)mPlot
{
    //NSLog(@"points length: %d", length);
    self.pointsArray = malloc(sizeof(CGPoint*) * mPlot);
    self.pointCountArray = malloc(sizeof(UInt32) * mPlot);
    
    int currPoints = 0;
    for (int j = 0; j < mPlot; j++) {
        self.pointsArray[j] = malloc(sizeof(CGPoint) * length[j]);
        for (int i = 0; i < length[j]; i++)
        {
            self.pointsArray[j][i].x = i;
            self.pointsArray[j][i].y = data[i+currPoints] * self.gain;
            if (j == 1 && i == 10) {
                NSLog(@"currPoints %d", currPoints);
                NSLog(@"%f == %f", data[10], data[10+currPoints]);
            }
        }
        self.pointsArray[j][0].y = self.pointsArray[j][length[j] - 1].y = 0.0f;
        self.pointCountArray[j] = length[j];
        currPoints += length[j];
    }
    
    
//    NSString* filepath = [NSHomeDirectory() stringByAppendingPathComponent:@"output.txt"];
//    NSLog(@"%@",filepath);
//    NSString* textToWrite = @"";
//    NSError *err;
//    for (int i = 0; i < length[0]; i++) {
//        textToWrite = [textToWrite stringByAppendingString:[NSString stringWithFormat:@"decodedWaveform[%d]: %f\n", i, self.pointsArray[0][i].y]];
//    }
//    // Do not use NSUnicodeStringEncoding, it will add "@" before every character
//    [textToWrite writeToFile:filepath atomically:YES encoding:NSUTF8StringEncoding error:&err];
}

//------------------------------------------------------------------------------
#pragma mark - Adjusting History Resolution
//------------------------------------------------------------------------------

- (int)rollingHistoryLength
{
    return self.historyInfo->bufferSize;
}

//------------------------------------------------------------------------------

- (int)setRollingHistoryLength:(int)historyLength
{
    self.historyInfo->bufferSize = MIN(EZAudioPlotDefaultMaxHistoryBufferLength, historyLength);
    return self.historyInfo->bufferSize;
}

//------------------------------------------------------------------------------
#pragma mark - Subclass
//------------------------------------------------------------------------------

- (int)defaultRollingHistoryLength
{
    return EZAudioPlotDefaultHistoryBufferLength;
}

//------------------------------------------------------------------------------

- (int)initialPointCount
{
    return 100;
}

//------------------------------------------------------------------------------

- (int)maximumRollingHistoryLength
{
    return EZAudioPlotDefaultMaxHistoryBufferLength;
}

//------------------------------------------------------------------------------
#pragma mark - Utility
//------------------------------------------------------------------------------

- (BOOL)isDeviceOriginFlipped
{
    BOOL isDeviceOriginFlipped = NO;
#if TARGET_OS_IPHONE
    isDeviceOriginFlipped = YES;
#elif TARGET_OS_MAC
#endif
    return isDeviceOriginFlipped;
}

//------------------------------------------------------------------------------
#pragma mark - EZAudioDisplayLinkDelegate
//------------------------------------------------------------------------------

- (void)displayLinkNeedsDisplay:(EZAudioDisplayLink *)displayLink
{
    [self redraw];
}

//------------------------------------------------------------------------------

@end

////------------------------------------------------------------------------------
#pragma mark - EZAudioPlotWaveformLayer (Implementation)
////------------------------------------------------------------------------------

@implementation EZAudioPlotWaveformLayer

- (id<CAAction>)actionForKey:(NSString *)event
{
    if ([event isEqualToString:@"path"])
    {
        if ([CATransaction disableActions])
        {
            return nil;
        }
        else
        {
            CABasicAnimation *animation = [CABasicAnimation animation];
            animation.timingFunction = [CATransaction animationTimingFunction];
            animation.duration = [CATransaction animationDuration];
            return animation;
        }
        return nil;
    }
    return [super actionForKey:event];
}

@end