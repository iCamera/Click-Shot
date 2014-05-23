//
//  VideoProcessor.m
//  Remote Shot
//
//  Created by Luke Wilson on 4/30/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "VideoProcessor.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "CameraViewController.h"

#define BYTES_PER_PIXEL 4
#define LOCK_EXPOSURE_DELAY 1.5

@interface VideoProcessor ()

// Redeclared as readwrite so that we can write to the property and still be atomic with external readers.
@property (readwrite) Float64 videoFrameRate;
@property (readwrite) CMVideoDimensions videoDimensions;
@property (readwrite) CMVideoCodecType videoType;
@property (nonatomic) UIImage *firstVideoFrame;
@property (nonatomic) BOOL willSwitchCamera;

@property (readwrite, getter=isRecording) BOOL recording;

@property (readwrite) AVCaptureVideoOrientation videoOrientation;

// Camera stills
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;


@end

@implementation VideoProcessor

@synthesize videoFrameRate, videoDimensions, videoType;
@synthesize referenceOrientation;
@synthesize videoOrientation;
@synthesize recording;

- (id) init
{
    if (self = [super init]) {
        previousSecondTimestamps = [[NSMutableArray alloc] init];
        referenceOrientation = AVCaptureVideoOrientationPortrait;
        
        // The temporary path for the video before saving it to the photo album
        movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"Movie.MOV"]];
    }
    return self;
}

#pragma mark Utilities

- (void) calculateFramerateAtTimestamp:(CMTime) timestamp
{
	[previousSecondTimestamps addObject:[NSValue valueWithCMTime:timestamp]];
    
	CMTime oneSecond = CMTimeMake( 1, 1 );
	CMTime oneSecondAgo = CMTimeSubtract( timestamp, oneSecond );
    
	while( CMTIME_COMPARE_INLINE( [[previousSecondTimestamps objectAtIndex:0] CMTimeValue], <, oneSecondAgo ) )
		[previousSecondTimestamps removeObjectAtIndex:0];
    
	Float64 newRate = (Float64) [previousSecondTimestamps count];
	self.videoFrameRate = (self.videoFrameRate + newRate) / 2;
}

- (void)removeFile:(NSURL *)fileURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [fileURL path];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        BOOL success = [fileManager removeItemAtPath:filePath error:&error];
		if (!success)
			[self showError:error];
    }
}

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGFloat angle = 0.0;
	
	switch (orientation) {
		case AVCaptureVideoOrientationPortrait:
			angle = 0.0;
			break;
		case AVCaptureVideoOrientationPortraitUpsideDown:
			angle = M_PI;
			break;
		case AVCaptureVideoOrientationLandscapeRight:
			angle = -M_PI_2;
			break;
		case AVCaptureVideoOrientationLandscapeLeft:
			angle = M_PI_2;
			break;
		default:
			break;
	}
    
	return angle;
}

- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGAffineTransform transform = CGAffineTransformIdentity;
    
    BOOL frontCam = ([self.captureDevice position] == AVCaptureDevicePositionFront);
    if (frontCam) {
        if (orientation == AVCaptureVideoOrientationLandscapeLeft) {
            orientation = AVCaptureVideoOrientationLandscapeRight;
        } else if (orientation == AVCaptureVideoOrientationLandscapeRight) {
            orientation = AVCaptureVideoOrientationLandscapeLeft;
        }
    }
	// Calculate offsets from an arbitrary reference orientation (portrait)
	CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:orientation];
	CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:self.videoOrientation];
	
	// Find the difference in angle between the passed in orientation and the current video orientation
	CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
	transform = CGAffineTransformMakeRotation(angleOffset);
	
	return transform;
}

#pragma mark Recording

- (void)saveMovieToCameraRoll
{
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	[library writeVideoAtPathToSavedPhotosAlbum:movieURL
								completionBlock:^(NSURL *assetURL, NSError *error) {
									if (error)
										[self showError:error];
									else
										[self removeFile:movieURL];
									
									dispatch_async(movieWritingQueue, ^{
										recordingWillBeStopped = NO;
										self.recording = NO;
                                        [self.delegate recordingDidStop:self.firstVideoFrame];

                                        self.firstVideoFrame = nil;

									});
								}];
}

- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
	if ( assetWriter.status == AVAssetWriterStatusUnknown ) {
		
        if ([assetWriter startWriting]) {
			[assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		}
		else {
			[self showError:[assetWriter error]];
		}
	}
	
	if ( assetWriter.status == AVAssetWriterStatusWriting ) {
		
		if (mediaType == AVMediaTypeVideo) {
			if (assetWriterVideoIn.readyForMoreMediaData) {
				if (![assetWriterVideoIn appendSampleBuffer:sampleBuffer]) {
					[self showError:[assetWriter error]];
				}
			}
		}
		else if (mediaType == AVMediaTypeAudio) {
			if (assetWriterAudioIn.readyForMoreMediaData) {
				if (![assetWriterAudioIn appendSampleBuffer:sampleBuffer]) {
					[self showError:[assetWriter error]];
				}
			}
		}
	}
}

- (BOOL) setupAssetWriterAudioInput:(CMFormatDescriptionRef)currentFormatDescription
{
	const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
    
	size_t aclSize = 0;
	const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
	NSData *currentChannelLayoutData = nil;
	
	// AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
	if ( currentChannelLayout && aclSize > 0 )
		currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
	else
		currentChannelLayoutData = [NSData data];
	
	NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
											  [NSNumber numberWithFloat:currentASBD->mSampleRate], AVSampleRateKey,
											  [NSNumber numberWithInt:64000], AVEncoderBitRatePerChannelKey,
											  [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame], AVNumberOfChannelsKey,
											  currentChannelLayoutData, AVChannelLayoutKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
		assetWriterAudioIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
		assetWriterAudioIn.expectsMediaDataInRealTime = YES;
		if ([assetWriter canAddInput:assetWriterAudioIn])
			[assetWriter addInput:assetWriterAudioIn];
		else {
			NSLog(@"Couldn't add asset writer audio input.");
            return NO;
		}
	}
	else {
		NSLog(@"Couldn't apply audio output settings.");
        return NO;
	}
    
    return YES;
}

- (BOOL) setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription
{
	float bitsPerPixel;
	CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
	int numPixels = dimensions.width * dimensions.height;
	int bitsPerSecond;
	// Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
	if ( numPixels < (640 * 480) )
		bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
	else
		bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
	
	bitsPerSecond = numPixels * bitsPerPixel;
	
	NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  AVVideoCodecH264, AVVideoCodecKey,
											  [NSNumber numberWithInteger:dimensions.width], AVVideoWidthKey,
											  [NSNumber numberWithInteger:dimensions.height], AVVideoHeightKey,
											  [NSDictionary dictionaryWithObjectsAndKeys:
											   [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
											   [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
											   nil], AVVideoCompressionPropertiesKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
		assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
		assetWriterVideoIn.expectsMediaDataInRealTime = YES;
		assetWriterVideoIn.transform = [self transformFromCurrentVideoOrientationToOrientation:self.referenceOrientation];
		if ([assetWriter canAddInput:assetWriterVideoIn])
			[assetWriter addInput:assetWriterVideoIn];
		else {
			NSLog(@"Couldn't add asset writer video input.");
            return NO;
		}
	}
	else {
		NSLog(@"Couldn't apply video output settings.");
        return NO;
	}
    
    return YES;
}

- (void) startRecording
{
	dispatch_async(movieWritingQueue, ^{
        
		if ( recordingWillBeStarted || self.recording )
			return;
        
		recordingWillBeStarted = YES;
        
		// recordingDidStart is called from captureOutput:didOutputSampleBuffer:fromConnection: once the asset writer is setup
		[self.delegate recordingWillStart];
        
		// Remove the file if one with the same name already exists
		[self removeFile:movieURL];
        
		// Create an asset writer
		NSError *error;
		assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:AVFileTypeQuickTimeMovie error:&error];
		if (error)
			[self showError:error];
	});
}

- (void) stopRecording
{
	dispatch_async(movieWritingQueue, ^{
		
//		if ( recordingWillBeStopped || (self.recording == NO) )
//			return;
		
		recordingWillBeStopped = YES;
		
		// recordingDidStop is called from saveMovieToCameraRoll
		[self.delegate recordingWillStop];
        if ([assetWriter finishWriting]) {
            assetWriter = nil;
			
			readyToRecordVideo = NO;
			readyToRecordAudio = NO;
			
			[self saveMovieToCameraRoll];
        }
	});
}

#pragma mark Capture

- (void)snapStillImage {
    [self.delegate willTakeStillImage];
    [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        if (error) {
            NSLog(@"%@", error);
        }
        if (imageDataSampleBuffer) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [[UIImage alloc] initWithData:imageData];
            [self.delegate didTakeStillImage:[UIImage imageWithCGImage:image.CGImage scale:1.0 orientation:[self imageOrientationForAVOrientation:self.referenceOrientation]]];
            [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation) [self imageOrientationForAVOrientation:self.referenceOrientation] completionBlock:^(NSURL *assetURL, NSError *error){
                [self.delegate didFinishSavingStillImage];
            }];
        } else {
            NSLog(@"error taking photo!");
        }
    }];
}

-(void)toggleActionShot {
    if (self.actionShooting) {
        NSLog(@"stop action shot");
        [self.delegate actionShotDidStop];
        self.actionShooting = NO;
    } else {
        NSLog(@"start action shot");
        actionShotsTaken = 0;
        [self.delegate actionShotDidStart];
        self.actionShooting = YES;
    }
}

-(void)toggleRecordVideo {
    if (recording) {
		// The recordingWill/DidStop delegate methods will fire asynchronously in response to this call
		[self stopRecording];
        NSLog(@"stop video recording");
	}
	else {
		// The recordingWill/DidStart delegate methods will fire asynchronously in response to this call
        [self startRecording];
        NSLog(@"start video recording");
	}
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.actionShooting && connection == videoConnection) {
        NSDate *now = [NSDate date];
        NSTimeInterval secs = [now timeIntervalSinceDate:lastActionShotDate];
        if (secs > 0.25) {
            UIImage *image = [self imageFromSampleBuffer:sampleBuffer withOrientation:self.referenceOrientation];
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            lastActionShotDate = now;
            actionShotsTaken++;
            [self.delegate didTakeActionShot:image number:actionShotsTaken];
        }
    } else if (self.willSwitchCamera && connection == videoConnection) {
        UIImage *frame = [self imageFromSampleBuffer:sampleBuffer withOrientation:AVCaptureVideoOrientationPortrait];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate willSwitchCamera:frame];
            [self switchCamera];
        });
        self.willSwitchCamera = NO;
    } else {
        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);

        CFRetain(sampleBuffer);
        CFRetain(formatDescription);
        dispatch_async(movieWritingQueue, ^{
            
            if ( assetWriter ) {
                
                BOOL wasReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
                
                if (connection == videoConnection) {
                    
                    // Initialize the video input if this is not done yet
                    if (!readyToRecordVideo)
                        readyToRecordVideo = [self setupAssetWriterVideoInput:formatDescription];
                    
                    // Write video data to file
                    if (readyToRecordVideo && readyToRecordAudio) {
                        if (!self.firstVideoFrame) {
                            self.firstVideoFrame = [self imageFromSampleBuffer:sampleBuffer withOrientation:self.referenceOrientation];
                        }
                        [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
                    }
                }
                else if (connection == audioConnection) {
                    
                    // Initialize the audio input if this is not done yet
                    if (!readyToRecordAudio)
                        readyToRecordAudio = [self setupAssetWriterAudioInput:formatDescription];
                    
                    // Write audio data to file
                    if (readyToRecordAudio && readyToRecordVideo)
                        [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
                }
                
                BOOL isReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
                if ( !wasReadyToRecord && isReadyToRecord ) {
                    recordingWillBeStarted = NO;
                    self.recording = YES;
                    [self.delegate recordingDidStart];
                }
            }
            CFRelease(sampleBuffer);
            CFRelease(formatDescription);
        });
    }
}

- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer withOrientation:(AVCaptureVideoOrientation)orientation {
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CFRetain(sampleBuffer);

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:1.0
                                   orientation: [self imageOrientationForAVOrientation:orientation]];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    CFRelease(sampleBuffer);

    return (image);
}

-(UIImageOrientation)imageOrientationForAVOrientation:(AVCaptureVideoOrientation)orientation {
    BOOL frontCam = ([self.captureDevice position] == AVCaptureDevicePositionFront);
    switch (orientation) {
        case AVCaptureVideoOrientationPortrait:
            return UIImageOrientationRight;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            return UIImageOrientationLeft;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            if (frontCam) {
                return UIImageOrientationDown;
            } else {
                return UIImageOrientationUp;
            }
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            if (frontCam) {
                return UIImageOrientationUp;
            } else {
                return UIImageOrientationDown;
            }
            break;
    }
}

- (AVCaptureDevice *)videoDeviceWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
        if ([device position] == position) {
            self.captureDevice = device;
            NSError *error = nil;
            if ([self.captureDevice lockForConfiguration:&error]) {
                if ([self.captureDevice isLowLightBoostSupported]) [self.captureDevice setAutomaticallyEnablesLowLightBoostWhenAvailable: YES];
                [self.captureDevice unlockForConfiguration];
            }
            return self.captureDevice;
        }
    
    return nil;
}

- (AVCaptureDevice *)audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices objectAtIndex:0];
    
    return nil;
}

- (BOOL) setupCaptureSession
{
	/*
     Overview: RosyWriter uses separate GCD queues for audio and video capture.  If a single GCD queue
     is used to deliver both audio and video buffers, and our video processing consistently takes
     too long, the delivery queue can back up, resulting in audio being dropped.
     
     When recording, RosyWriter creates a third GCD queue for calls to AVAssetWriter.  This ensures
     that AVAssetWriter is not called to start or finish writing from multiple threads simultaneously.
     
     RosyWriter uses AVCaptureSession's default preset, AVCaptureSessionPresetHigh.
	 */
    
    /*
	 * Create capture session
	 */
    captureSession = [[AVCaptureSession alloc] init];
    
    /*
	 * Create audio connection
	 */
    AVCaptureDeviceInput *audioIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    if ([captureSession canAddInput:audioIn])
        [captureSession addInput:audioIn];
	
	AVCaptureAudioDataOutput *audioOut = [[AVCaptureAudioDataOutput alloc] init];
	dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
	[audioOut setSampleBufferDelegate:self queue:audioCaptureQueue];
	if ([captureSession canAddOutput:audioOut])
		[captureSession addOutput:audioOut];
	audioConnection = [audioOut connectionWithMediaType:AVMediaTypeAudio];
    
	/*
	 * Create video connection
	 */
    AVCaptureDeviceInput *videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:AVCaptureDevicePositionBack] error:nil];
    if ([captureSession canAddInput:videoIn])
        [captureSession addInput:videoIn];
    
    self.videoDeviceInput = videoIn;
    
	AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
	/*
     RosyWriter prefers to discard late video frames early in the capture pipeline, since its
     processing can take longer than real-time on some platforms (such as iPhone 3GS).
     Clients whose image processing is faster than real-time should consider setting AVCaptureVideoDataOutput's
     alwaysDiscardsLateVideoFrames property to NO.
	 */
	[videoOut setAlwaysDiscardsLateVideoFrames:YES];
	[videoOut setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
	dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
	[videoOut setSampleBufferDelegate:self queue:videoCaptureQueue];
	if ([captureSession canAddOutput:videoOut])
		[captureSession addOutput:videoOut];
	videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
	self.videoOrientation = [videoConnection videoOrientation];
    self.videoDataOutput = videoOut;
    
    
    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    if ([captureSession canAddOutput:stillImageOutput])
    {
        [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
        [captureSession addOutput:stillImageOutput];
        self.stillImageOutput = stillImageOutput;
        self.stillImageConnection = [stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    }

    lastActionShotDate = [NSDate date];
    
    if (self.previewView) [self.previewView setSession:captureSession];
    
	return YES;
}

- (void) setupAndStartCaptureSession
{
	// Create serial queue for movie writing
	movieWritingQueue = dispatch_queue_create("Movie Writing Queue", DISPATCH_QUEUE_SERIAL);
	
    if ( !captureSession )
		[self setupCaptureSession];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionStoppedRunningNotification:) name:AVCaptureSessionDidStopRunningNotification object:captureSession];
	
	if ( !captureSession.isRunning )
		[captureSession startRunning];
}

- (void) pauseCaptureSession
{
	if ( captureSession.isRunning )
		[captureSession stopRunning];
}

- (void) resumeCaptureSession
{
    if (!captureSession) {
        [self setupAndStartCaptureSession];
    } else if ( !captureSession.isRunning ) {
        [captureSession startRunning];
    }
}

- (void)captureSessionStoppedRunningNotification:(NSNotification *)notification
{
	dispatch_async(movieWritingQueue, ^{
		if ( [self isRecording] ) {
			[self stopRecording];
		}
	});
}

- (void) stopAndTearDownCaptureSession
{
    [captureSession stopRunning];
	if (captureSession)
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:captureSession];
	captureSession = nil;
    
	if (movieWritingQueue) {
		movieWritingQueue = NULL;
	}
}

#pragma mark Camera Device Settings

-(void)beginSwitchingCamera {
    self.willSwitchCamera = YES;
}

- (void)switchCamera {
    AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
    AVCaptureDevicePosition currentPosition = [self.captureDevice position];
    
    switch (currentPosition)
    {
        case AVCaptureDevicePositionUnspecified:
            preferredPosition = AVCaptureDevicePositionBack;
            break;
        case AVCaptureDevicePositionBack:
            preferredPosition = AVCaptureDevicePositionFront;
            break;
        case AVCaptureDevicePositionFront:
            preferredPosition = AVCaptureDevicePositionBack;
            break;
    }
    AVCaptureDevice *videoDevice = [self videoDeviceWithPosition:preferredPosition];
    AVCaptureDeviceInput *newVideoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [captureSession beginConfiguration];
        
        [captureSession removeInput:self.videoDeviceInput];
        if ([captureSession canAddInput:newVideoDeviceInput]) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.captureDevice];
            
            CameraViewController *cameraViewController = (CameraViewController *)self.delegate;
            //			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];
            
            [captureSession addInput:newVideoDeviceInput];
            self.videoDeviceInput = newVideoDeviceInput;
            [self setFlashMode:[cameraViewController currentAVFlashMode]];
            [self setTorchMode:[cameraViewController currentAVTorchMode]];
            
            videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
            
        } else {
            [captureSession addInput:[self videoDeviceInput]];
        }
        
        [captureSession commitConfiguration];
    });
}


- (void)setFlashMode:(AVCaptureFlashMode)flashMode
{
    
	if ([self.captureDevice hasFlash] && [self.captureDevice isFlashModeSupported:flashMode])
	{
		NSError *error = nil;
		if ([self.captureDevice lockForConfiguration:&error])
		{
			[self.captureDevice setFlashMode:flashMode];
			[self.captureDevice unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	}
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode
{
	if ([self.captureDevice hasTorch] && [self.captureDevice isTorchModeSupported:torchMode])
	{
		NSError *error = nil;
		if ([self.captureDevice lockForConfiguration:&error])
		{
			[self.captureDevice setTorchMode:torchMode];
			[self.captureDevice unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	}
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    AVCaptureDevice *device = [[self videoDeviceInput] device];
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) [device setFocusMode:AVCaptureFocusModeAutoFocus];
        if ([device isFocusPointOfInterestSupported] && point.x != -1) [device setFocusPointOfInterest:point];
        if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        if ([device isExposurePointOfInterestSupported] && point.x != -1) [device setExposurePointOfInterest:point];
        [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
        [device unlockForConfiguration];
    } else {
        NSLog(@"%@", error);
    }
    if (exposureMode == AVCaptureExposureModeLocked) [self performSelector:@selector(lockExposure) withObject:nil afterDelay:LOCK_EXPOSURE_DELAY];
}

-(CGPoint)startFocusMode:(AVCaptureFocusMode)focusMode {
    AVCaptureDevice *device = [[self videoDeviceInput] device];
    
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        if ([device isFocusModeSupported:focusMode]) [device setFocusMode:focusMode];
        [device unlockForConfiguration];
    } else {
        NSLog(@"%@", error);
    }
    return device.focusPointOfInterest;
}

- (void)focusAtPoint:(CGPoint)devicePoint {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
		AVCaptureDevice *device = [[self videoDeviceInput] device];
		NSError *error = nil;
		if ([device lockForConfiguration:&error]) {
            if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) [device setFocusMode:AVCaptureFocusModeAutoFocus];
            if ([device isFocusPointOfInterestSupported]) [device setFocusPointOfInterest:devicePoint];
			[device unlockForConfiguration];
		} else {
			NSLog(@"%@", error);
		}
	});
}


- (CGPoint)startExposeMode:(AVCaptureExposureMode)exposureMode
{
    AVCaptureDevice *device = [[self videoDeviceInput] device];
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        if ([device isExposureModeSupported:exposureMode]) [device setExposureMode:exposureMode];
        [device unlockForConfiguration];
    } else {
        NSLog(@"%@", error);
    }
    return device.exposurePointOfInterest;
}

- (void)exposeAtPoint:(CGPoint)devicePoint {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
		AVCaptureDevice *device = [[self videoDeviceInput] device];
		NSError *error = nil;
		if ([device lockForConfiguration:&error]) {
            if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            if ([device isExposurePointOfInterestSupported]) [device setExposurePointOfInterest:devicePoint];
			[device unlockForConfiguration];
		} else {
			NSLog(@"%@", error);
		}
	});
    [self performSelector:@selector(lockExposure) withObject:nil afterDelay:LOCK_EXPOSURE_DELAY];
}

-(void) lockExposure {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
		AVCaptureDevice *device = [[self videoDeviceInput] device];
		NSError *error = nil;
		if ([device lockForConfiguration:&error]) {
            if ([device isExposureModeSupported:AVCaptureExposureModeLocked]) [device setExposureMode:AVCaptureExposureModeLocked];
			[device unlockForConfiguration];
		} else {
			NSLog(@"%@", error);
		}
        
	});
}


#pragma mark - Error Handling

- (void)showError:(NSError *)error
{
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    });
}


@end
