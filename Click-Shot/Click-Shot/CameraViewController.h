//
//  CameraViewController.h
//  Remote Shot
//
//  Created by Luke Wilson on 3/18/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import <UIKit/UIKit.h>
@import CoreBluetooth;
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "VideoProcessor.h"

@interface CameraViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

-(void)pressedCameraButton;
-(void)setCameraButtonText:(NSString *)text withOffset:(CGPoint)offset fontSize:(float)fontSize;
-(UIImage *) currentCameraButtonImage;
-(UIImage *) currentHighlightedCameraButtonImage;
-(AVCaptureTorchMode) currentAVTorchMode;
-(AVCaptureFlashMode) currentAVFlashMode;
-(CGPoint) devicePointForScreenPoint:(CGPoint)screenPoint;

-(void)resumeSessions;
-(void)pauseSessions;

@property (nonatomic) BOOL autoFocusMode;
@property (nonatomic) BOOL autoExposureMode;
@property (nonatomic) BOOL gestureIsBlocked;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (nonatomic) NSInteger cameraMode;
@property (nonatomic, strong) NSString *cameraButtonString;

@property (nonatomic, weak) IBOutlet UIButton *pictureModeButton;
@property (nonatomic, weak) IBOutlet UIButton *rapidShotModeButton;
@property (nonatomic, weak) IBOutlet UIButton *videoModeButton;

@property (nonatomic) BOOL settingsMenuIsOpen;
@property (nonatomic) BOOL soundsMenuIsOpen;

@property (nonatomic) VideoProcessor *videoProcessor;

@end
