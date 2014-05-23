//
//  VideoProcessor.h
//  Remote Shot
//
//  Created by Luke Wilson on 4/30/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMBufferQueue.h>
#import <AVFoundation/AVFoundation.h>
#import "CameraPreviewView.h"
@protocol VideoProcessorDelegate;

@interface VideoProcessor : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
{
	
	NSMutableArray *previousSecondTimestamps;
	Float64 videoFrameRate;
	CMVideoDimensions videoDimensions;
	CMVideoCodecType videoType;
    
	AVCaptureConnection *audioConnection;
	AVCaptureConnection *videoConnection;
	
	NSURL *movieURL;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterAudioIn;
	AVAssetWriterInput *assetWriterVideoIn;
	dispatch_queue_t movieWritingQueue;
    
	AVCaptureVideoOrientation referenceOrientation;
	AVCaptureVideoOrientation videoOrientation;
    
	// Only accessed on movie writing queue
    BOOL readyToRecordAudio;
    BOOL readyToRecordVideo;
	BOOL recordingWillBeStarted;
	BOOL recordingWillBeStopped;
    
	BOOL recording;
    int actionShotsTaken;
    NSDate *lastActionShotDate;
@public
    AVCaptureSession *captureSession;
}

@property (readwrite, assign) id <VideoProcessorDelegate> delegate;


@property (readonly) Float64 videoFrameRate;
@property (readonly) CMVideoDimensions videoDimensions;
@property (readonly) CMVideoCodecType videoType;

@property (readwrite) AVCaptureVideoOrientation referenceOrientation;
// Camera stills
@property (nonatomic) AVCaptureConnection *stillImageConnection;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic) AVCaptureDevice *captureDevice;
@property (nonatomic) CameraPreviewView *previewView;

- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation;

- (void) showError:(NSError*)error;

- (void) setupAndStartCaptureSession;
- (void) stopAndTearDownCaptureSession;

- (void) startRecording;
- (void) stopRecording;

- (void) pauseCaptureSession; // Pausing while a recording is in progress will cause the recording to be stopped and saved.
- (void) resumeCaptureSession;

// called by CameraViewController
-(void)snapStillImage;
-(void)toggleActionShot;
-(void)toggleRecordVideo;

-(void)beginSwitchingCamera;
- (void)setFlashMode:(AVCaptureFlashMode)flashMode;
- (void)setTorchMode:(AVCaptureTorchMode)torchMode;
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange;
- (void)focusAtPoint:(CGPoint)devicePoint;
- (CGPoint)startFocusMode:(AVCaptureFocusMode)focusMode;
- (void)exposeAtPoint:(CGPoint)devicePoint;
- (CGPoint)startExposeMode:(AVCaptureExposureMode)exposureMode;

@property(readonly, getter=isRecording) BOOL recording;
@property(nonatomic) BOOL actionShooting;


@end

@protocol VideoProcessorDelegate <NSObject>
@required
- (void)recordingWillStart;
- (void)recordingDidStart;
- (void)recordingWillStop;
- (void)recordingDidStop:(UIImage *)image;
- (void)willTakeStillImage;
- (void)didTakeStillImage:(UIImage *)image;
- (void)didFinishSavingStillImage;
- (void)actionShotDidStart;
- (void)didTakeActionShot:(UIImage *)image number:(int)seriesNumber;
- (void)actionShotDidStop;
- (void)willSwitchCamera:(UIImage *)image;

@end
