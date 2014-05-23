//
//  CameraViewController.m
//  Remote Shot
//
//  Created by Luke Wilson on 3/18/14.
//  Copyright (c) 2014 Luke Wilson. All rights reserved.
//

#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>
#import "CameraPreviewView.h"
#import "MoveableImageView.h"
#import "CameraButton.h"
#import "GPUImage.h"
#import "MHGallery.h"


#define kCameraModePicture 0
#define kCameraModeRapidShot 1
#define kCameraModeVideo 2

#define kFlashModeAuto 0
#define kFlashModeOn 1
#define kFlashModeOff 2

#define kDefaultAlpha 1

#define kFocusViewTag 1
#define kExposeViewTag 2

#define BTTN_SERVICE_UUID           @"fffffff0-00f7-4000-b000-000000000000"
#define BTTN_DETECTION_CHARACTERISTIC_UUID    @"fffffff2-00f7-4000-b000-000000000000"
#define BTTN_NOTIFICATION_CHARACTERISTIC_UUID    @"fffffff4-00f7-4000-b000-000000000000"
#define BTTN_VERIFICATION_CHARACTERISTIC_UUID    @"fffffff5-00f7-4000-b000-000000000000"
#define BTTN_VERIFICATION_KEY    @"BC:F5:AC:48:40"

#define kSwipeVelocityUntilGuarenteedSwitch 800
#define kLargeFontSize 140
#define kMediumFontSize 120
#define kSmallFontSize 95



// Interface here for private properties
@interface CameraViewController () <VideoProcessorDelegate, UIPickerViewDataSource, UIPickerViewDelegate, AVAudioPlayerDelegate>

@property (nonatomic, weak) IBOutlet CameraPreviewView *previewView;

@property (nonatomic, weak) IBOutlet UIButton *flashModeAutoButton;
@property (nonatomic, weak) IBOutlet UIButton *flashModeOnButton;
@property (nonatomic, weak) IBOutlet UIButton *flashModeOffButton;

@property (nonatomic, weak) IBOutlet UIButton *swithCameraButton;
@property (nonatomic, weak) IBOutlet UIButton *cameraRollButton;
@property (nonatomic, weak) IBOutlet UIButton *settingsButton;
@property (nonatomic) UIImageView *cameraRollImage; //child of cameraRollButton (stacks on top just taken picture)
@property (nonatomic, weak) IBOutlet MoveableImageView *focusPointView;
@property (nonatomic, weak) IBOutlet MoveableImageView *exposePointView;
@property (nonatomic, weak) IBOutlet CameraButton *cameraButton;
@property (nonatomic, weak) IBOutlet UIImageView *blurredImagePlaceholder;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *previewViewDistanceFromBottom;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *previewViewDistanceFromTop;

@property (nonatomic, strong) UIButton *currentFlashButton;
@property (nonatomic, strong) UIView *modeSelectorBar;


- (IBAction)pressedVideoMode:(id)sender;
- (IBAction)pressedRapidShotMode:(id)sender;
- (IBAction)pressedPictureMode:(id)sender;
- (IBAction)pressedCameraRoll:(id)sender;
- (IBAction)pressedSettings:(id)sender;
- (IBAction)pressedFlashButton:(id)sender;
- (IBAction)switchCamera:(id)sender;
- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer;

// Settings Menu
@property (nonatomic, weak) IBOutlet UIView *settingsView;
@property (nonatomic, weak) IBOutlet UIButton *focusButton;
@property (nonatomic, weak) IBOutlet UIButton *exposureButton;
@property (nonatomic, weak) IBOutlet UIButton *soundsButton;
@property (nonatomic, weak) IBOutlet UIPickerView *soundPicker;
- (IBAction)toggleFocusButton:(id)sender;
- (IBAction)toggleExposureButton:(id)sender;
- (IBAction)pressedSounds:(id)sender;

// Utilities.
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;
@property (nonatomic) NSInteger flashMode;
@property (nonatomic) BOOL flashModeMenuIsOpen;
@property (nonatomic) AVAudioPlayer *soundPlayer;
@property (nonatomic) BOOL shouldPlaySound;
@property (nonatomic) BOOL takePictureAfterSound;

// Swipe Mode Control
@property (nonatomic) UITouch *primaryTouch;

@property (nonatomic) CGFloat startXTouch;
@property (nonatomic) CGFloat previousXTouch;
@property (nonatomic) CFTimeInterval lastMoveTime;
@property (nonatomic) BOOL hasMoved;
@property (nonatomic) CGFloat velocity;
@property (nonatomic) CGFloat selectorBarStartCenterX;
@property (nonatomic, strong) UIImage *pictureCameraButtonImage;
@property (nonatomic, strong) UIImage *rapidCameraButtonImage;
@property (nonatomic, strong) UIImage *videoCameraButtonImage;
@property (nonatomic, strong) UIImage *pictureCameraButtonImageHighlighted;
@property (nonatomic, strong) UIImage *rapidCameraButtonImageHighlighted;
@property (nonatomic, strong) UIImage *videoCameraButtonImageHighlighted;
@property (nonatomic, strong) UIImage *darkCameraButtonBG;

@property (nonatomic) NSDate *recordingStart;
@property (nonatomic) NSTimer *recordingTimer;
@property (nonatomic) UIDeviceOrientation lockedOrientation;

@property (nonatomic) GPUImageGaussianBlurFilter *blurFilter;
@property (nonatomic) NSMutableArray *galleryItems;

@end

@implementation CameraViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    __weak CameraViewController *weakSelf = self;
    
    self.cameraMode = kCameraModePicture;
    [self updateModeButtons];
    self.flashMode = kFlashModeAuto;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger soundNumber = [[defaults objectForKey:@"sound"] integerValue];
    [self updateSoundPlayerWithSoundNumber:soundNumber];
    [self.soundPicker selectRow:soundNumber inComponent:0 animated:NO];
    
    self.currentFlashButton = self.flashModeAutoButton;
    self.autoExposureMode = ![[defaults objectForKey:@"noAutoExposureMode"] boolValue];
    [self.exposureButton setSelected:self.autoExposureMode];
    self.autoFocusMode = ![[defaults objectForKey:@"noAutoFocusMode"] boolValue];
    [self.focusButton setSelected:self.autoFocusMode];
    self.gestureIsBlocked = NO;
    
    self.focusPointView.parentViewController = weakSelf;
    self.exposePointView.parentViewController = weakSelf;
    self.cameraButton.parentViewController = weakSelf;
    [self.cameraButton initialize];
	
	// Check for device authorization
	[self checkDeviceAuthorizationStatus];


    self.currentFlashButton.alpha = kDefaultAlpha;
    self.focusButton.alpha = kDefaultAlpha;
    self.exposureButton.alpha = kDefaultAlpha;
    self.swithCameraButton.alpha = kDefaultAlpha;
    
    self.modeSelectorBar = [[UIView alloc] initWithFrame:CGRectMake(self.pictureModeButton.frame.origin.x, self.pictureModeButton.frame.origin.y+self.pictureModeButton.frame.size.height+3, self.pictureModeButton.frame.size.width, 7)];
    self.modeSelectorBar.backgroundColor = [UIColor whiteColor];
    [self.previewView addSubview:self.modeSelectorBar];
    self.pictureCameraButtonImage = [UIImage imageNamed:@"inner.png"];
    self.rapidCameraButtonImage = [UIImage imageNamed:@"rapidInner.png"];
    self.videoCameraButtonImage = [UIImage imageNamed:@"redInner.png"];
    self.pictureCameraButtonImageHighlighted = [UIImage imageNamed:@"innerHighlighted.png"];
    self.rapidCameraButtonImageHighlighted = [UIImage imageNamed:@"rapidInnerHighlighted.png"];
    self.videoCameraButtonImageHighlighted = [UIImage imageNamed:@"redInnerHighlighted.png"];
    self.darkCameraButtonBG = [UIImage imageNamed:@"cameraButtonDarkBG"];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    if (_centralManager.state == CBCentralManagerStatePoweredOn) [self startScanningForButton];

    
    self.videoProcessor = [[VideoProcessor alloc] init];
    self.videoProcessor.delegate = self;
    self.videoProcessor.previewView = self.previewView;
    [self.videoProcessor setupAndStartCaptureSession];

    self.cameraRollImage = [[UIImageView alloc] initWithFrame:CGRectMake(3, 3, self.cameraRollButton.frame.size.width-6, self.cameraRollButton.frame.size.height-6)];
    self.cameraRollImage.contentMode = UIViewContentModeScaleAspectFill;
    self.cameraRollImage.clipsToBounds = YES;
    [self.cameraRollButton addSubview:self.cameraRollImage];
    
    self.blurFilter = [[GPUImageGaussianBlurFilter alloc] init];
    self.blurFilter.blurRadiusInPixels = 28.0f;
}

-(void)resumeSessions {
    [self.videoProcessor resumeCaptureSession];
    [self startScanningForButton];
}

-(void)pauseSessions {
    [self.videoProcessor pauseCaptureSession];
    [_centralManager stopScan];
    if (_discoveredPeripheral)[self cleanupBluetooth];
}

- (void)viewWillAppear:(BOOL)animated {
    [self updateGalleryItems];
}

//-(void)viewWillDisappear:(BOOL)animated {
//    [_centralManager stopScan];
//    if (_discoveredPeripheral) [self cleanupBluetooth];
//}

#pragma mark -
#pragma mark IBActions

- (IBAction)pressedPictureMode:(id)sender {
    [self switchToPictureMode];
    [self swipeToSelectedButtonCameraMode];
}

- (IBAction)pressedRapidShotMode:(id)sender {
    [self switchToRapidShotMode];
    [self swipeToSelectedButtonCameraMode];
}

- (IBAction)pressedVideoMode:(id)sender {
    [self switchToVideoMode];
    [self swipeToSelectedButtonCameraMode];
}

- (IBAction)pressedCameraRoll:(id)sender {
    MHGalleryController *gallery = [[MHGalleryController alloc]initWithPresentationStyle:MHGalleryViewModeOverView];
    __weak MHGalleryController *blockGallery = gallery;
    gallery.galleryItems = self.galleryItems;
    MHUICustomization *customize = [[MHUICustomization alloc] init];
    customize.barStyle = UIBarStyleBlackTranslucent;
    customize.barTintColor = [UIColor blackColor];
    customize.barButtonsTintColor = [UIColor colorWithRed:0.242 green:0.804 blue:0.974 alpha:1.000];
    [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeOverView];
    [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeImageViewerNavigationBarShown];
    [customize setMHGalleryBackgroundColor:[UIColor colorWithWhite:0.131 alpha:1.000] forViewMode:MHGalleryViewModeImageViewerNavigationBarHidden];

    gallery.UICustomization = customize;
    gallery.finishedCallback = ^(NSUInteger currentIndex,UIImage *image,MHTransitionDismissMHGallery *interactiveTransition,MHGalleryViewMode viewMode){
        [blockGallery dismissViewControllerAnimated:YES dismissImageView:nil completion:nil];
    };
    [self presentMHGalleryController:gallery animated:YES completion:nil];
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//        self.imagePickerPopover = [[UIPopoverController alloc] initWithContentViewController:self.imagePicker];
//        [self.imagePickerPopover presentPopoverFromRect:self.cameraRollButton.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
//        
//    } else {
//        [self presentViewController:self.imagePicker animated:YES completion:^{
//        }];
//    }
}


- (IBAction)switchCamera:(id)sender {
    [self.videoProcessor beginSwitchingCamera];
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    if (!self.gestureIsBlocked) {
        CGPoint touchPoint = [gestureRecognizer locationInView:[gestureRecognizer view]];
        self.exposePointView.center = touchPoint;
        self.focusPointView.center = touchPoint;
        [self.videoProcessor focusWithMode:[self currentAVFocusMode] exposeWithMode:[self currentAVExposureMode] atDevicePoint:[self devicePointForScreenPoint:touchPoint] monitorSubjectAreaChange:NO];
        
        if (!self.autoFocusMode) {
            [UIView animateWithDuration:0.4 animations:^{
                self.focusPointView.alpha = kDefaultAlpha;
            }];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                self.focusPointView.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.7 animations:^{
                    self.focusPointView.alpha = 0;
                }];
            }];
        }
        if (!self.autoExposureMode) {
            [UIView animateWithDuration:0.4 animations:^{
                self.exposePointView.alpha = kDefaultAlpha;
            }];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                self.exposePointView.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.7 animations:^{
                    self.exposePointView.alpha = 0;
                }];
            }];
        }
    }
}


- (IBAction)pressedSettings:(id)sender {
    if (self.settingsMenuIsOpen) {
        [self closeSettingsMenu];
    } else {
        [self openSettingsMenu];
    }
}

-(CGPoint)devicePointForScreenPoint:(CGPoint)screenPoint {
    return [(AVCaptureVideoPreviewLayer *)[[self previewView] layer] captureDevicePointOfInterestForPoint:screenPoint];

}

#pragma mark Settings Menu IBActions

- (IBAction)toggleFocusButton:(id)sender {
    self.autoFocusMode = !self.autoFocusMode;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:!self.autoFocusMode] forKey:@"noAutoFocusMode"];
    [self.focusButton setSelected:self.autoFocusMode];
    CGPoint focusPoint = [self.videoProcessor startFocusMode:[self currentAVFocusMode]];
    self.focusPointView.userInteractionEnabled = !self.autoFocusMode;
    if (!self.autoFocusMode) {
        self.focusPointView.center = CGPointMake(focusPoint.x*[UIScreen mainScreen].bounds.size.width, focusPoint.y*[UIScreen mainScreen].bounds.size.height);
        [self.focusPointView fixIfOffscreen];
        [UIView animateWithDuration:0.4 animations:^{
            self.focusPointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.4 animations:^{
            self.focusPointView.alpha = 0;
        }];
    }
}

- (IBAction)toggleExposureButton:(id)sender {
    self.autoExposureMode = !self.autoExposureMode;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:!self.autoExposureMode] forKey:@"noAutoExposeMode"];
    [self.exposureButton setSelected:self.autoExposureMode];
    CGPoint exposurePoint = [self.videoProcessor startExposeMode:[self currentAVExposureMode]];
    self.exposePointView.userInteractionEnabled = !self.autoExposureMode;
    if (!self.autoExposureMode) {
        self.exposePointView.center = CGPointMake(exposurePoint.x*[UIScreen mainScreen].bounds.size.width, exposurePoint.y*[UIScreen mainScreen].bounds.size.height);
        [self.exposePointView fixIfOffscreen];
        [UIView animateWithDuration:0.4 animations:^{
            self.exposePointView.alpha = kDefaultAlpha;
        }];
    } else {
        [UIView animateWithDuration:0.4 animations:^{
            self.exposePointView.alpha = 0;
        }];

    }
}

-(IBAction)pressedSounds:(id)sender {
    if (self.soundsMenuIsOpen) {
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.previewViewDistanceFromBottom.constant = 100;
            self.previewViewDistanceFromTop.constant = -100;
            [self.view layoutIfNeeded];
        } completion:nil];
    } else {
        float yPosition = 100+self.soundPicker.frame.size.height;
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.previewViewDistanceFromBottom.constant = yPosition;
            self.previewViewDistanceFromTop.constant = -yPosition;
            [self.view layoutIfNeeded];
        } completion:nil];
    }
    self.soundsMenuIsOpen = !self.soundsMenuIsOpen;
}

#pragma mark -
#pragma mark Settings Menu

-(void)closeSettingsMenu {
    self.settingsMenuIsOpen = NO;
    self.soundsMenuIsOpen = NO;
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.previewViewDistanceFromBottom.constant = 0;
        self.previewViewDistanceFromTop.constant = 0;
        [self.view layoutIfNeeded];
    }completion:^(BOOL finished){
        self.settingsView.hidden = YES;
    }];
}

-(void)openSettingsMenu {
    self.settingsMenuIsOpen = YES;
    self.settingsView.hidden = NO;
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.previewViewDistanceFromBottom.constant = 100;
        self.previewViewDistanceFromTop.constant = -100;
        [self.view layoutIfNeeded];
    }completion:nil];
}

#pragma mark -
#pragma mark Camera Functions

-(void)setCameraButtonText:(NSString *)text withOffset:(CGPoint)offset fontSize:(float)fontSize{
    self.cameraButtonString = text;
    if ([text isEqualToString:@""]) {
        self.cameraButton.buttonImage.image = [self currentCameraButtonImage];
    } else if (self.videoProcessor.actionShooting) {
        self.cameraButton.buttonImage.image = [self maskImage:self.pictureCameraButtonImage withMaskText:text offsetFromCenter:offset fontSize:fontSize];
    } else {
        self.cameraButton.buttonImage.image = [self maskImage:[self currentCameraButtonImage] withMaskText:text offsetFromCenter:offset fontSize:fontSize];
    }
}

- (UIImage*) maskImage:(UIImage *)image withMaskText:(NSString *)maskText offsetFromCenter:(CGPoint)offset fontSize:(float)fontSize{
    
    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    
    // Create a context for our text mask
    UIGraphicsBeginImageContextWithOptions(image.size, YES, 1);
    CGContextRef textMaskContext = UIGraphicsGetCurrentContext();
    
	// Draw a white background
	[[UIColor whiteColor] setFill];
	CGContextFillRect(textMaskContext, imageRect);
    // Draw black text
    [[UIColor blackColor] setFill];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attr = @{NSParagraphStyleAttributeName: paragraphStyle,
                           NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize],
                           NSStrokeColorAttributeName: [UIColor blackColor],
                           NSStrokeWidthAttributeName: [NSNumber numberWithFloat:5.0]};
    
    CGSize textSize = [maskText sizeWithAttributes:attr];
	[maskText drawAtPoint:CGPointMake((imageRect.size.width-textSize.width)/2+offset.x, (imageRect.size.height-textSize.height)/2+offset.y) withAttributes:attr];
    
	// Create an image from what we've drawn
	CGImageRef textAlphaMask = CGBitmapContextCreateImage(textMaskContext);
    CGContextRelease(textMaskContext);
    
    // create a bitmap graphics context the size of the image
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef mainImageContext = CGBitmapContextCreate (NULL, image.size.width, image.size.height, CGImageGetBitsPerComponent(image.CGImage), 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(mainImageContext, imageRect, self.darkCameraButtonBG.CGImage); // for semi-transparent dark number
    CGContextClipToMask(mainImageContext, imageRect, textAlphaMask);
    CGContextDrawImage(mainImageContext, imageRect, image.CGImage);
    
    CGImageRef finishedImage =CGBitmapContextCreateImage(mainImageContext);
    UIImage *finalMaskedImage = [UIImage imageWithCGImage: finishedImage];
    
    CGImageRelease(finishedImage);
    CGContextRelease(mainImageContext);
    CGImageRelease(textAlphaMask);
    CGColorSpaceRelease(colorSpace);
    
    // return the image
    return finalMaskedImage;
    
}


- (void)pressedCameraButton {
    if (self.shouldPlaySound && self.cameraMode != kCameraModeRapidShot && !self.videoProcessor.recording) {
        [self.soundPlayer play];
        self.takePictureAfterSound = YES;
    } else {
        switch (self.cameraMode) {
            case kCameraModePicture:
                [self.videoProcessor snapStillImage];
                break;
            case kCameraModeRapidShot:
                [self.videoProcessor toggleActionShot];
                if (!self.videoProcessor.actionShooting)[self setCameraButtonText:@"" withOffset:CGPointZero fontSize:kMediumFontSize];
                break;
            case kCameraModeVideo:
                [self.videoProcessor toggleRecordVideo];
                break;
            default:
                break;
        }
    }
}

-(void)countRecordingTime:(NSTimer *)timer {
    NSTimeInterval secs = [[NSDate date] timeIntervalSinceDate:self.recordingStart];
    int minute = (int)secs/60;
    int second = (int)secs%60;
    if (self.lockedOrientation == UIDeviceOrientationLandscapeLeft) {
        [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointMake(-15, 0) fontSize:kSmallFontSize];
    } else if (self.lockedOrientation == UIDeviceOrientationLandscapeRight) {
        [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointMake(15, 0) fontSize:kSmallFontSize];
    } else {
        [self setCameraButtonText:[NSString stringWithFormat:@"%i:%02i", minute, second] withOffset:CGPointZero fontSize:kSmallFontSize];
    }
}

-(void) updateCameraRollButtonWithImage:(UIImage *)image duration:(float)duration {
    [UIView transitionWithView:self.cameraRollButton
                      duration:duration
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.cameraRollImage.image = image;
                    } completion:nil];
}

#pragma mark -
#pragma mark Flash Button

- (IBAction)pressedFlashButton:(id)sender {
    if (self.flashModeMenuIsOpen) {
        [UIView animateWithDuration:0.5 animations:^{
            self.flashModeOnButton.frame = self.currentFlashButton.frame;
            self.flashModeOffButton.frame = self.currentFlashButton.frame;
            self.flashModeAutoButton.frame = self.currentFlashButton.frame;
            if ([sender isEqual:self.flashModeAutoButton]) {
                self.flashModeAutoButton.alpha = kDefaultAlpha;
                self.flashModeOffButton.alpha = 0;
                self.flashModeOnButton.alpha = 0;
            } else if ([sender isEqual:self.flashModeOnButton]) {
                self.flashModeOnButton.alpha = kDefaultAlpha;
                self.flashModeOffButton.alpha = 0;
                self.flashModeAutoButton.alpha = 0;
            } else if ([sender isEqual:self.flashModeOffButton]) {
                self.flashModeOffButton.alpha = kDefaultAlpha;
                self.flashModeAutoButton.alpha = 0;
                self.flashModeOnButton.alpha = 0;
            }
        } completion:^(BOOL finished) {
            if ([sender isEqual:self.flashModeAutoButton]) {
                self.currentFlashButton = self.flashModeAutoButton;
                self.flashMode = kFlashModeAuto;
            } else if ([sender isEqual:self.flashModeOnButton]) {
                self.currentFlashButton = self.flashModeOnButton;
                self.flashMode = kFlashModeOn;
            } else if ([sender isEqual:self.flashModeOffButton]) {
                self.currentFlashButton = self.flashModeOffButton;
                self.flashMode = kFlashModeOff;
            }
            if (self.cameraMode == kCameraModeVideo || self.cameraMode == kCameraModeRapidShot) {
                [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
                [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
            } else {
                [self.videoProcessor setTorchMode:AVCaptureTorchModeOff];
                [self.videoProcessor setFlashMode:[self currentAVFlashMode]];
            }
        }];
        self.flashModeMenuIsOpen = NO;
    } else {
        [self openFlashModeMenu];
    }
}

-(void)openFlashModeMenu {
    self.flashModeMenuIsOpen = YES;
    switch (self.flashMode) {
        case kFlashModeAuto: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashModeOnButton.frame = CGRectMake(self.currentFlashButton.frame.origin.x, self.currentFlashButton.frame.origin.y+45, self.currentFlashButton.frame.size.width, self.currentFlashButton.frame.size.height);
                self.flashModeOnButton.alpha = kDefaultAlpha;
                
                self.flashModeOffButton.frame = CGRectMake(self.currentFlashButton.frame.origin.x, self.currentFlashButton.frame.origin.y+45*2, self.currentFlashButton.frame.size.width, self.currentFlashButton.frame.size.height);
                self.flashModeOffButton.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
            }];
            break;
        }
        case kFlashModeOn: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashModeAutoButton.frame = CGRectMake(self.currentFlashButton.frame.origin.x, self.currentFlashButton.frame.origin.y+45, self.currentFlashButton.frame.size.width, self.currentFlashButton.frame.size.height);
                self.flashModeAutoButton.alpha = kDefaultAlpha;
                
                self.flashModeOffButton.frame = CGRectMake(self.currentFlashButton.frame.origin.x, self.currentFlashButton.frame.origin.y+45*2, self.currentFlashButton.frame.size.width, self.currentFlashButton.frame.size.height);
                self.flashModeOffButton.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
            }];
            break;
        }
        case kFlashModeOff: {
            [UIView animateWithDuration:0.5 animations:^{
                self.flashModeAutoButton.frame = CGRectMake(self.currentFlashButton.frame.origin.x, self.currentFlashButton.frame.origin.y+45, self.currentFlashButton.frame.size.width, self.currentFlashButton.frame.size.height);
                self.flashModeAutoButton.alpha = kDefaultAlpha;
                
                self.flashModeOnButton.frame = CGRectMake(self.currentFlashButton.frame.origin.x, self.currentFlashButton.frame.origin.y+45*2, self.currentFlashButton.frame.size.width, self.currentFlashButton.frame.size.height);
                self.flashModeOnButton.alpha = kDefaultAlpha;
            } completion:^(BOOL finished) {
            }];
            break;
        }
        default:
            break;
    }
}

#pragma mark -
#pragma mark Camera Modes

-(void) updateModeButtons {
    switch (self.cameraMode) {
        case kCameraModePicture:
            [self.pictureModeButton setSelected:YES];
            [self.rapidShotModeButton setSelected:NO];
            [self.videoModeButton setSelected:NO];

            break;
        case kCameraModeRapidShot:
            [self.pictureModeButton setSelected:NO];
            [self.rapidShotModeButton setSelected:YES];
            [self.videoModeButton setSelected:NO];

            break;
        case kCameraModeVideo:
            [self.pictureModeButton setSelected:NO];
            [self.rapidShotModeButton setSelected:NO];
            [self.videoModeButton setSelected:YES];

            break;
        default:
            break;
    }
}

-(void)switchToPictureMode {
    self.cameraMode = kCameraModePicture;
    [self.videoProcessor setTorchMode:AVCaptureTorchModeOff];
    [self.videoProcessor setFlashMode:[self currentAVFlashMode]];
    [self updateModeButtons];
    [self switchCameraButtonImageTo:[self currentCameraButtonImage]];
}

- (void)switchToRapidShotMode {
    self.cameraMode = kCameraModeRapidShot;
    [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
    [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
    [self updateModeButtons];
    [self switchCameraButtonImageTo:[self currentCameraButtonImage]];
}

- (void)switchToVideoMode {
    self.cameraMode = kCameraModeVideo;
    [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
    [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
    [self updateModeButtons];
    [self switchCameraButtonImageTo:[self currentCameraButtonImage]];
}


-(AVCaptureFlashMode) currentAVFlashMode {
    switch (self.flashMode) {
        case kFlashModeAuto:
            return AVCaptureFlashModeAuto;
            break;
        case kFlashModeOn:
            return AVCaptureFlashModeOn;
            break;
        case kFlashModeOff:
            return AVCaptureFlashModeOff;
            break;
        default:
            return AVCaptureFlashModeAuto;
            break;
    }
}

-(AVCaptureTorchMode) currentAVTorchMode {
    switch (self.flashMode) {
        case kFlashModeAuto:
            return AVCaptureTorchModeAuto;
            break;
        case kFlashModeOn:
            return AVCaptureTorchModeOn;
            break;
        case kFlashModeOff:
            return AVCaptureTorchModeOff;
            break;
        default:
            return AVCaptureTorchModeAuto;
            break;
    }
}

-(AVCaptureFocusMode) currentAVFocusMode {
    if (self.autoFocusMode) {
        return AVCaptureFocusModeContinuousAutoFocus;
    } else {
        return AVCaptureFocusModeLocked;
    }
}

-(AVCaptureExposureMode) currentAVExposureMode {
    if (self.autoExposureMode) {
        return AVCaptureExposureModeContinuousAutoExposure;
    } else {
        return AVCaptureExposureModeLocked;
    }
}

-(UIImage *)currentCameraButtonImage {
    switch (self.cameraMode) {
        case kCameraModePicture:
            return self.pictureCameraButtonImage;
            break;
        case kCameraModeRapidShot:
            return self.rapidCameraButtonImage;
        case kCameraModeVideo:
            return self.videoCameraButtonImage;
        default:
            return self.pictureCameraButtonImage;
            break;
    }
}

-(UIImage *)currentHighlightedCameraButtonImage {
    switch (self.cameraMode) {
        case kCameraModePicture:
            return self.pictureCameraButtonImageHighlighted;
            break;
        case kCameraModeRapidShot:
            return self.rapidCameraButtonImageHighlighted;
        case kCameraModeVideo:
            return [self maskImage:self.videoCameraButtonImageHighlighted withMaskText:self.cameraButtonString offsetFromCenter:CGPointZero fontSize:kSmallFontSize];
        default:
            return self.pictureCameraButtonImageHighlighted;
            break;
    }
}


-(void)switchCameraButtonImageTo:(UIImage *)newImage {
    [UIView transitionWithView:self.cameraButton
                      duration:0.35f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.cameraButton.buttonImage.image = newImage;
                    } completion:nil];
}

#pragma mark -
#pragma mark UI

- (void)runStillImageCaptureAnimation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view.layer setOpacity:0.01];
        [UIView animateWithDuration:.2 animations:^{
            [self.view.layer setOpacity:1.0];
        }];
    });
}

- (void)checkDeviceAuthorizationStatus
{
	NSString *mediaType = AVMediaTypeVideo;
	
	[AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
		if (granted)
		{
			//Granted access to mediaType
			[self setDeviceAuthorized:YES];
		}
		else
		{
			//Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"Remote Shot!"
											message:@"Remote Shot doesn't have permission to use Camera, please change privacy settings"
										   delegate:self
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil] show];
				[self setDeviceAuthorized:NO];
			});
		}
	}];
}


#pragma mark -
#pragma mark Manage Rotations

- (void)deviceDidRotate:(NSNotification *)notification {
    [self updateRotations];
}

-(void) updateRotations {
    UIDeviceOrientation currentOrientation = [[UIDevice currentDevice] orientation];
	// Don't update the reference orientation when the device orientation is face up/down or unknown.
    
    double rotation = 0;
    switch (currentOrientation) {
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationUnknown:
            return;
        case UIDeviceOrientationPortrait:
            rotation = 0;
            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationPortrait];
            
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            rotation = -M_PI;
            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            
            break;
        case UIDeviceOrientationLandscapeLeft:
            rotation = M_PI_2;
            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationLandscapeRight];
            
            break;
        case UIDeviceOrientationLandscapeRight:
            rotation = -M_PI_2;
            [self.videoProcessor setReferenceOrientation:AVCaptureVideoOrientationLandscapeLeft];
            
            break;
    }
    
    CGAffineTransform transform = CGAffineTransformMakeRotation(rotation);
    [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        
        if (!self.videoProcessor.isRecording) [self.cameraButton.buttonImage setTransform:transform];
        [self.cameraRollButton setTransform:transform];
        [self.flashModeAutoButton setTransform:transform];
        [self.flashModeOffButton setTransform:transform];
        [self.flashModeOnButton setTransform:transform];
        [self.focusButton setTransform:transform];
        [self.exposureButton setTransform:transform];
        [self.swithCameraButton setTransform:transform];
        [self.settingsButton setTransform:transform];
        [self.soundsButton setTransform:transform];

    } completion:nil];
    if (self.flashModeMenuIsOpen) {
        [self pressedFlashButton:self.currentFlashButton];
    }
}

#pragma mark -
#pragma mark Bluetooth Central Delegates

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // Determine the state of the central manager
    if ([central state] == CBCentralManagerStatePoweredOff) {
        NSLog(@"CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBCentralManagerStatePoweredOn) {
        NSLog(@"CoreBluetooth BLE hardware is powered on and ready");
        // Scan for devices
        [self startScanningForButton];
    }
    else if ([central state] == CBCentralManagerStateUnauthorized) {
        NSLog(@"CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBCentralManagerStateUnknown) {
        NSLog(@"CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBCentralManagerStateUnsupported) {
        NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
//    NSString *deviceName = [peripheral.name substringToIndex:6]; // Get just the V.ALRT or V.BTTN piece of name to make sure the peripheral is the kind we want
    
//    if (!_discoveredPeripheral && ([deviceName isEqualToString:@"V.ALRT"] || [deviceName isEqualToString:@"V.BTTN"])) {
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        _discoveredPeripheral = peripheral;
        
        // And connect
        NSLog(@"Connecting to peripheral %@", peripheral);
        [_centralManager connectPeripheral:peripheral options:nil];
//    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect");
    [self cleanupBluetooth];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected");
    
    [_centralManager stopScan];
    NSLog(@"Scanning stopped");
        
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:BTTN_SERVICE_UUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self cleanupBluetooth];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        NSLog(@"found service: %@", service);
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID], [CBUUID UUIDWithString:BTTN_VERIFICATION_CHARACTERISTIC_UUID], [CBUUID UUIDWithString:BTTN_DETECTION_CHARACTERISTIC_UUID]] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanupBluetooth];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID]]) { // Set up to receive notifications when button is pressed or released
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            NSLog(@"NOTIFY characteristic: %@", characteristic);
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_VERIFICATION_CHARACTERISTIC_UUID]]) { // Create long lasting connection
            const Byte identifierBytes[5] = { 0xBC, 0xF5, 0xAC, 0x48, 0x40 };
            NSMutableData *data = [[NSMutableData alloc] initWithBytes:identifierBytes length:5];
            [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            NSLog(@"Created long lasting communication with button by sending verification key");
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_DETECTION_CHARACTERISTIC_UUID]]) { // Set peripheral up to detect button pressed
            const Byte identifierByte[1] = { 0x01 };
            NSMutableData *data = [[NSMutableData alloc] initWithBytes:identifierByte length:1];
            [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error");
        return;
    }
    
    const Byte identifierByte[1] = { 0x01 };
    NSMutableData *buttonDownData = [[NSMutableData alloc] initWithBytes:identifierByte length:1];
    if ([characteristic.value isEqualToData:buttonDownData]) {
        [self pressedCameraButton];
    }
    
    NSLog(@"%@", characteristic.value);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID]]) return; // only care about button stuff
    
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    } else {
        // Notification has stopped
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    _discoveredPeripheral = nil;
    
    [self startScanningForButton];
}

-(void)startScanningForButton {
    [_centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO }];
    NSLog(@"started scanning");
}

- (void)cleanupBluetooth {
    // See if we are subscribed to a characteristic on the peripheral
    if (_discoveredPeripheral.services != nil) {
        for (CBService *service in _discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BTTN_NOTIFICATION_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [_discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
}

#pragma mark -
#pragma mark Manage Touches

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.gestureIsBlocked && !self.settingsMenuIsOpen) { // make sure we can switch modes
        _primaryTouch = [touches anyObject];
        _startXTouch = [_primaryTouch locationInView:self.view].x;
        _hasMoved = NO;
        _lastMoveTime = CACurrentMediaTime();
        _selectorBarStartCenterX = self.modeSelectorBar.center.x;
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.gestureIsBlocked && !self.settingsMenuIsOpen) { // make sure we can switch modes
        CGFloat currentXPos = [_primaryTouch locationInView:self.view].x;
        CGFloat diffFromBeginning = currentXPos - _startXTouch;
        if (diffFromBeginning < 0 ) { //swiping  to rapid shot or video shot
            if (self.modeSelectorBar.frame.origin.x < self.videoModeButton.frame.origin.x) {
                self.modeSelectorBar.center = CGPointMake(_selectorBarStartCenterX-(diffFromBeginning/(320/55)), self.modeSelectorBar.center.y);
            }
        } else  { // swiping  to rapid shot or picture shot
            if (self.modeSelectorBar.frame.origin.x > self.pictureModeButton.frame.origin.x) {
                self.modeSelectorBar.center = CGPointMake(_selectorBarStartCenterX-(diffFromBeginning/(320/55)), self.modeSelectorBar.center.y);
            }
        }
        [self highlightSelectorMode];
        CGFloat diffFromLastPos = currentXPos - _previousXTouch;
        CFTimeInterval now = CACurrentMediaTime();
        CFTimeInterval elapsedTime = now - _lastMoveTime;
        _velocity = diffFromLastPos/elapsedTime;
        
        
        _previousXTouch = currentXPos;
        _lastMoveTime = now;
        _hasMoved = YES;
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.pictureModeButton.enabled && !self.gestureIsBlocked && !self.settingsMenuIsOpen) { // make sure we can switch modes
        CGFloat currentXPos = [_primaryTouch locationInView:self.view].x;
        CGFloat diffFromBeginning = currentXPos - _startXTouch;
        if (_hasMoved) {
            if (_velocity >= kSwipeVelocityUntilGuarenteedSwitch) {
                if (self.cameraMode == kCameraModeVideo) {
                    [self swipeToMode:kCameraModeRapidShot withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else if (self.cameraMode == kCameraModeRapidShot) {
                    [self swipeToMode:kCameraModePicture withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else {
                    [self swipeToSelectedButtonCameraMode];
                }
            } else if (_velocity <= -kSwipeVelocityUntilGuarenteedSwitch) {
                if (self.cameraMode == kCameraModePicture) {
                    [self swipeToMode:kCameraModeRapidShot withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else if (self.cameraMode == kCameraModeRapidShot) {
                    [self swipeToMode:kCameraModeVideo withVelocity:_velocity andDistanceMoved:diffFromBeginning];
                } else {
                    [self swipeToSelectedButtonCameraMode];
                }
            } else {
                [self swipeToSelectedButtonCameraMode];
            }
        }
        _primaryTouch = nil;
        _hasMoved = NO;
    } else if (self.settingsMenuIsOpen && CGRectContainsPoint(self.previewView.frame, [[touches anyObject] locationInView:self.view])) {
        [self closeSettingsMenu];
    }
}


-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

-(void)swipeToMode:(NSInteger)newMode withVelocity:(CGFloat)velocity andDistanceMoved:(CGFloat)distanceMoved {
    distanceMoved = fabsf(distanceMoved);
    velocity = fabsf(velocity);
    CGFloat distanceToMove = self.pictureModeButton.frame.size.width+1-distanceMoved;
    NSTimeInterval lengthOfAnimation = distanceToMove/velocity;
    lengthOfAnimation *= 2;
    
    if (newMode == kCameraModePicture) {
        [self switchToPictureMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.pictureModeButton.center.x, self.modeSelectorBar.center.y);
        } completion:^(BOOL finished) {
        }];
    } else if (newMode == kCameraModeRapidShot) {
        [self switchToRapidShotMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.rapidShotModeButton.center.x, self.modeSelectorBar.center.y);
        } completion:^(BOOL finished) {
        }];
    } else if (newMode == kCameraModeVideo) {
        [self switchToVideoMode];
        [UIView animateWithDuration:lengthOfAnimation delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.videoModeButton.center.x, self.modeSelectorBar.center.y);
        } completion:^(BOOL finished) {
        }];
    }
}

-(void)swipeToSelectedButtonCameraMode {
    if (self.pictureModeButton.selected) {
        [self switchToPictureMode];
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.pictureModeButton.center.x, self.modeSelectorBar.center.y);
        } completion:^(BOOL finished) {
        }];
    } else if (self.rapidShotModeButton.selected) {
        [self switchToRapidShotMode];
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.rapidShotModeButton.center.x, self.modeSelectorBar.center.y);
        } completion:^(BOOL finished) {
        }];
    } else if (self.videoModeButton.selected) {
        [self switchToVideoMode];
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.modeSelectorBar.center = CGPointMake(self.videoModeButton.center.x, self.modeSelectorBar.center.y);
        } completion:^(BOOL finished) {
        }];
    }
}

-(void)highlightSelectorMode {
    if (fabsf(self.pictureModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = YES;
        self.rapidShotModeButton.selected = NO;
        self.videoModeButton.selected = NO;
    } else if (fabsf(self.rapidShotModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = NO;
        self.rapidShotModeButton.selected = YES;
        self.videoModeButton.selected = NO;
    } else if (fabsf(self.videoModeButton.center.x-self.modeSelectorBar.center.x) < (self.pictureModeButton.frame.size.width/2)) {
        self.pictureModeButton.selected = NO;
        self.rapidShotModeButton.selected = NO;
        self.videoModeButton.selected = YES;
    }
}

#pragma mark Video Processor Delegate

-(void)recordingWillStop {
    [self.pictureModeButton setEnabled:YES];
    [self.rapidShotModeButton setEnabled:YES];
    [self.swithCameraButton setEnabled:YES];
    [self.cameraRollButton setEnabled:YES];
    [self.settingsButton setEnabled:YES];
    self.gestureIsBlocked = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.recordingTimer invalidate];
        [self setCameraButtonText:@"" withOffset:CGPointZero fontSize:kMediumFontSize];
    });
}

-(void)recordingDidStop:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateRotations];
        [self updateCameraRollButtonWithImage:image duration:0.25];
        [self updateGalleryItems];
    });
}

-(void)recordingWillStart {
    [self.pictureModeButton setEnabled:NO];
    [self.rapidShotModeButton setEnabled:NO];
    [self.swithCameraButton setEnabled:NO];
    [self.cameraRollButton setEnabled:NO];
    [self.settingsButton setEnabled:NO];
    self.gestureIsBlocked = YES;
    self.lockedOrientation = [[UIDevice currentDevice] orientation];
    [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
    [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
}

-(void)recordingDidStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recordingStart = [NSDate date];
        [self countRecordingTime:nil];
        self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(countRecordingTime:) userInfo:nil repeats:YES];
    });
}

- (void)willTakeStillImage {
    
}


- (void)didTakeStillImage:(UIImage *)image {
    [self runStillImageCaptureAnimation];
    [self updateCameraRollButtonWithImage:image duration:0.35];
}

-(void)didFinishSavingStillImage {
    [self updateGalleryItems];
}

- (void)didTakeActionShot:(UIImage *)image number:(int)seriesNumber {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.videoProcessor.actionShooting) [self setCameraButtonText:@"" withOffset:CGPointZero fontSize:kMediumFontSize];
        else {
            [self updateCameraRollButtonWithImage:image duration:0.2];
            [self setCameraButtonText:[NSString stringWithFormat:@"%i", seriesNumber] withOffset:CGPointZero fontSize:kMediumFontSize];
        }
    });
}

-(void)actionShotDidStart {
    [self.pictureModeButton setEnabled:NO];
    [self.videoModeButton setEnabled:NO];
    [self.swithCameraButton setEnabled:NO];
    [self.cameraRollButton setEnabled:NO];
    [self.settingsButton setEnabled:NO];
    self.gestureIsBlocked = YES;
    [self.videoProcessor setTorchMode:[self currentAVTorchMode]];
    [self.videoProcessor setFlashMode:AVCaptureFlashModeOff];
}

-(void)actionShotDidStop {
    [self.pictureModeButton setEnabled:YES];
    [self.videoModeButton setEnabled:YES];
    [self.swithCameraButton setEnabled:YES];
    [self.cameraRollButton setEnabled:YES];
    [self.settingsButton setEnabled:YES];
    self.gestureIsBlocked = NO;
    [self updateGalleryItems];
}

-(void) willSwitchCamera:(UIImage *)image {
    [UIView transitionWithView:self.previewView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromLeft animations:nil completion:^(BOOL finished){
        [UIView animateWithDuration:0.5 delay:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.blurredImagePlaceholder.alpha = 0;
        } completion:nil];
    }];
    UIImage *blurredImage = [self.blurFilter imageByFilteringImage:image];
    if (self.videoProcessor.captureDevice.position == AVCaptureDevicePositionFront) _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(-1, 1);
    else _blurredImagePlaceholder.transform = CGAffineTransformMakeScale(1, 1);
    NSLog(@"%i", blurredImage.imageOrientation);
    self.blurredImagePlaceholder.image = blurredImage;
    self.blurredImagePlaceholder.alpha = 1;
}

-(void)updateGalleryItems {
    self.galleryItems = [NSMutableArray new];
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        [group setAssetsFilter:[ALAssetsFilter allAssets]];
        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *alAsset, NSUInteger index, BOOL *innerStop) {
            if (alAsset) {
                if ([[alAsset valueForProperty:@"ALAssetPropertyType"] isEqualToString:@"ALAssetTypePhoto"]) {
                    MHGalleryItem *item = [[MHGalleryItem alloc]initWithURL:[alAsset.defaultRepresentation.url absoluteString]
                                                                galleryType:MHGalleryTypeImage];
                    [self.galleryItems addObject:item];
                } else {
                    MHGalleryItem *item = [[MHGalleryItem alloc]initWithURL:[alAsset.defaultRepresentation.url absoluteString]
                                                                galleryType:MHGalleryTypeVideo];
                    [self.galleryItems addObject:item];
                }
            }
        }];
    } failureBlock: ^(NSError *error) {
        
    }];
}

#pragma mark - Sound Picker Methods

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 6;
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    switch (row) {
        case 0:
            return @"No Sound";
            break;
        case 1:
            return @"Bomb Countdown";
            break;
        case 2:
            return @"Alien Ramp Up";
            break;
        case 3:
            return @"Cat Meow";
            break;
        case 4:
            return @"Bird Chirp";
            break;
        case 5:
            return @"Dog Bark";
            break;
        default:
            return @"No Sound";
            break;
    }
}

-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return 35;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    
    [self updateSoundPlayerWithSoundNumber:row];
    if (self.shouldPlaySound) {
        self.takePictureAfterSound = NO;
        [self.soundPlayer play];
    }
}

-(void)updateSoundPlayerWithSoundNumber:(NSInteger)number {
    self.shouldPlaySound = YES;
    NSError *error;
    switch (number) {
        case 0:
            self.shouldPlaySound = NO;
            [self.soundPlayer stop];
            
            break;
        case 1:
            self.soundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"bombCountdown" ofType:@"wav"]] error:&error];
            break;
        case 2:
            self.soundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"alienRampUp" ofType:@"wav"]] error:&error];
            break;
        case 3:
            self.soundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"catMeow" ofType:@"wav"]] error:&error];
            break;
        case 4:
            self.soundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"birdChirp" ofType:@"wav"]] error:&error];
            break;
        case 5:
            self.soundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"dogBark" ofType:@"wav"]] error:&error];
            break;
        default:
            self.shouldPlaySound = NO;
            [self.soundPlayer stop];
            break;
    }
    if (number == 0)
        [self.soundsButton setSelected:NO];
    else
        [self.soundsButton setSelected:YES];
    self.soundPlayer.delegate = self;
    [self.soundPlayer prepareToPlay];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:number] forKey:@"sound"];
}

#pragma  mark - Audio Player Delegate

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (self.takePictureAfterSound) {
        switch (self.cameraMode) {
            case kCameraModePicture:
                [self.videoProcessor snapStillImage];
                break;
            case kCameraModeRapidShot:
                [self.videoProcessor toggleActionShot];
                if (!self.videoProcessor.actionShooting)[self setCameraButtonText:@"" withOffset:CGPointZero fontSize:kMediumFontSize];
                break;
            case kCameraModeVideo:
                [self.videoProcessor toggleRecordVideo];
                break;
            default:
                break;
        }
    }
}

@end
