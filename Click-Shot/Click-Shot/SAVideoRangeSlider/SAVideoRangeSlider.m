//
//  SAVideoRangeSlider.m
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Copyright (c) 2013 Andrei Solovjev - http://solovjev.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SAVideoRangeSlider.h"

@interface SAVideoRangeSlider ()

@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIView *centerView;
@property (nonatomic, strong) NSURL *videoUrl;
@property (nonatomic, strong) SASliderLeft *leftThumb;
@property (nonatomic, strong) SASliderRight *rightThumb;
@property (nonatomic, strong) SAScrubber *scrubber;

@property (nonatomic) CGFloat frame_width;
@property (nonatomic, strong) SAResizibleBubble *popoverBubble;
@property (nonatomic, strong) SAResizibleBubble *scrubberPopoverBubble;
@property (nonatomic, strong) NSMutableArray *timelineImageViews;

@end

@implementation SAVideoRangeSlider


#define SLIDER_BORDERS_SIZE 3.0f
#define BG_VIEW_BORDERS_SIZE 3.0f


- (id)initWithFrame:(CGRect)frame videoUrl:(NSURL *)videoUrl{
    
    self = [super initWithFrame:frame];
    if (self) {
        
        _frame_width = frame.size.width;
        
        int thumbWidth = ceil(frame.size.width*0.05);
        
        _bgView = [[UIControl alloc] initWithFrame:CGRectMake(thumbWidth-BG_VIEW_BORDERS_SIZE, 0, frame.size.width-(thumbWidth*2)+BG_VIEW_BORDERS_SIZE*2, frame.size.height)];
        _bgView.layer.borderColor = [UIColor grayColor].CGColor;
        _bgView.backgroundColor = [UIColor colorWithWhite:0.158 alpha:1.000];
        _bgView.layer.borderWidth = BG_VIEW_BORDERS_SIZE;
        [self addSubview:_bgView];
        
        _videoUrl = videoUrl;
        
        
        _topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, SLIDER_BORDERS_SIZE)];
        _topBorder.backgroundColor = [UIColor colorWithRed:0.560 green:0.895 blue:0.984 alpha:1.000];
        [self addSubview:_topBorder];
        
        
        _bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height-SLIDER_BORDERS_SIZE, frame.size.width, SLIDER_BORDERS_SIZE)];
        _bottomBorder.backgroundColor = [UIColor colorWithRed:0.239 green: 0.835 blue: 0.984 alpha:1.000];
        [self addSubview:_bottomBorder];
        
        
        _leftThumb = [[SASliderLeft alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];
        _leftThumb.contentMode = UIViewContentModeLeft;
        _leftThumb.userInteractionEnabled = YES;
        _leftThumb.clipsToBounds = YES;
        _leftThumb.backgroundColor = [UIColor clearColor];
        _leftThumb.layer.borderWidth = 0;
        [self addSubview:_leftThumb];
        
        
        UIPanGestureRecognizer *leftPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftPan:)];
        [_leftThumb addGestureRecognizer:leftPan];
        
        
        _rightThumb = [[SASliderRight alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];
        
        _rightThumb.contentMode = UIViewContentModeRight;
        _rightThumb.userInteractionEnabled = YES;
        _rightThumb.clipsToBounds = YES;
        _rightThumb.backgroundColor = [UIColor clearColor];
        [self addSubview:_rightThumb];
        
        UIPanGestureRecognizer *rightPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightPan:)];
        [_rightThumb addGestureRecognizer:rightPan];
        
        _rightPosition = frame.size.width;
        _leftPosition = 0;
        
        
        
        
        _centerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _centerView.backgroundColor = [UIColor clearColor];
        [self addSubview:_centerView];
        
        UIPanGestureRecognizer *centerPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCenterPan:)];
        [_centerView addGestureRecognizer:centerPan];
        
        
        _popoverBubble = [[SAResizibleBubble alloc] initWithFrame:CGRectMake(0, -50, 100, 50)];
        _popoverBubble.alpha = 0;
        _popoverBubble.backgroundColor = [UIColor clearColor];
        [self addSubview:_popoverBubble];
        
        
        _bubleText = [[UILabel alloc] initWithFrame:_popoverBubble.frame];
        _bubleText.font = [UIFont boldSystemFontOfSize:20];
        _bubleText.backgroundColor = [UIColor clearColor];
        _bubleText.textColor = [UIColor blackColor];
        _bubleText.textAlignment = NSTextAlignmentCenter; // was UITextAlignmentCenter
        
        [_popoverBubble addSubview:_bubleText];
        
        _scrubber = [[SAScrubber alloc] initWithFrame:CGRectMake(0, 0, 15*2, self.frame.size.height)];
        _scrubber.center = CGPointMake(_leftThumb.frame.size.width, _scrubber.center.y);
        [self addSubview:_scrubber];
        UIPanGestureRecognizer *scrubberPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleScrubberPan:)];
        [_scrubber addGestureRecognizer:scrubberPan];
        
        _scrubberPopoverBubble = [[SAResizibleBubble alloc] initWithFrame:CGRectMake(0, -50, 100, 50)];
        _scrubberPopoverBubble.alpha = 0;
        _scrubberPopoverBubble.backgroundColor = [UIColor clearColor];
        [self addSubview:_scrubberPopoverBubble];
        
        _scrubberBubleText = [[UILabel alloc] initWithFrame:_popoverBubble.frame];
        _scrubberBubleText.font = [UIFont boldSystemFontOfSize:20];
        _scrubberBubleText.backgroundColor = [UIColor clearColor];
        _scrubberBubleText.textColor = [UIColor blackColor];
        _scrubberBubleText.textAlignment = NSTextAlignmentCenter;
        
        [_scrubberPopoverBubble addSubview:_scrubberBubleText];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_scrubber setNeedsDisplay];
            [_leftThumb setNeedsDisplay];
            [_rightThumb setNeedsDisplay];
            [_popoverBubble setNeedsDisplay];
            [_scrubberPopoverBubble setNeedsDisplay];
        });
        [self setUpTimelineImages];
        [self getMovieFrame];
        [self layoutSubviews];
    }
    
    return self;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


-(void)setPopoverBubbleSize: (CGFloat)width height:(CGFloat)height {
    
    CGRect currentFrame = _popoverBubble.frame;
    currentFrame.size.width = width;
    currentFrame.size.height = height;
    currentFrame.origin.y = -height;
    _popoverBubble.frame = currentFrame;
    
    currentFrame.origin.x = 0;
    currentFrame.origin.y = 0;
    _bubleText.frame = currentFrame;
    
}

-(void)setPopoverBubbleFrame:(CGRect)newFrame{
    _popoverBubble.frame = newFrame;
    _bubleText.frame = CGRectMake(0, 0, newFrame.size.width, newFrame.size.height);
}

-(void)setScrubberPopoverBubbleFrame:(CGRect)newFrame{
    _scrubberPopoverBubble.frame = newFrame;
    _scrubberBubleText.frame = CGRectMake(0, 0, newFrame.size.width, newFrame.size.height);
    
}


-(void)setMaxGap:(NSInteger)maxGap{
//    _leftPosition = 0;
//    _rightPosition = _frame_width*maxGap/_durationSeconds;
    _maxGap = maxGap;
}

-(void)setMinGap:(NSInteger)minGap{
//    _leftPosition = 0;
//    _rightPosition = _frame_width*minGap/_durationSeconds;
    _minGap = minGap;
}



#pragma mark - Gestures

- (void)handleLeftPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _leftPosition += translation.x;
        if (_leftPosition < 0) {
            _leftPosition = 0;
        }
        
        if (_rightPosition-_leftPosition <= _minGap){
            _leftPosition -= translation.x;
        }
        if (
            (_rightPosition-_leftPosition <= _leftThumb.frame.size.width+_rightThumb.frame.size.width) ||
            ((self.maxGap > 0) && (self.rightPosition-self.leftPosition > self.maxGap)) ||
            ((self.minGap > 0) && (self.rightPosition-self.leftPosition < self.minGap))
            ){
            _leftPosition -= translation.x;
        }
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self layoutSubviews];
        
        _scrubberPosition = _leftPosition+_leftThumb.frame.size.width;
        [_delegate videoRange:self didChangeStartTime:[self leftTimePosition]];
        [_delegate videoRange:self didChangeScrubberTimePosition:[self scrubberTimePosition]];
        
    }
    
    _popoverBubble.alpha = 1;
    
    [self setTimeLabel];
    
    if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_popoverBubble];
    }
}


- (void)handleRightPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        
        CGPoint translation = [gesture translationInView:self];
        _rightPosition += translation.x;
        if (_rightPosition > _frame_width){
            _rightPosition = _frame_width;
        }
        
        if (_rightPosition-_leftPosition <= _minGap){
            _rightPosition -= translation.x;
        }
        
        if ((_rightPosition-_leftPosition <= _leftThumb.frame.size.width+_rightThumb.frame.size.width) ||
            ((self.maxGap > 0) && (self.rightPosition-self.leftPosition > self.maxGap)) ||
            ((self.minGap > 0) && (self.rightPosition-self.leftPosition < self.minGap))){
            _rightPosition -= translation.x;
        }
        
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self layoutSubviews];
        
        [_delegate videoRange:self didChangeEndTime:[self rightTimePosition]];
        
    }
    
    _popoverBubble.alpha = 1;
    
    [self setTimeLabel];
    
    
    if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_popoverBubble];
    }
}


- (void)handleCenterPan:(UIPanGestureRecognizer *)gesture
{
    
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _leftPosition += translation.x;
        _rightPosition += translation.x;
        
        if (_rightPosition > _frame_width || _leftPosition < 0){
            _leftPosition -= translation.x;
            _rightPosition -= translation.x;
        } else {
            [_delegate videoRange:self didChangeStartTime:[self leftTimePosition] endTime:[self rightTimePosition]];
            _scrubberPosition = _leftPosition+_leftThumb.frame.size.width;
            [self layoutSubviews];
        }
        
        
        [gesture setTranslation:CGPointZero inView:self];
        
    }
    
    _popoverBubble.alpha = 1;
    
    [self setTimeLabel];
    
    if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_popoverBubble];
    }
    
}

- (void)handleScrubberPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _scrubberPosition += translation.x;
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self layoutSubviews];
        [self.delegate videoRange:self didChangeScrubberTimePosition:[self scrubberTimePosition]];
        
        _scrubberPopoverBubble.alpha = 1;
        [self setScrubberTimeLabel:[self scrubberTimePosition]];
        
    } else if (gesture.state == UIGestureRecognizerStateEnded){
        [self layoutSubviews];
        [self hideBubble:_scrubberPopoverBubble];
    }
}

- (void)layoutSubviews
{
    CGFloat inset = _leftThumb.frame.size.width / 2;
    
    if (_scrubberPosition < _leftPosition+_leftThumb.frame.size.width) {
        _scrubberPosition = _leftPosition+_leftThumb.frame.size.width;
    } else if (_scrubberPosition > _rightPosition-_leftThumb.frame.size.width) {
        _scrubberPosition = _rightPosition-_leftThumb.frame.size.width;
    }
    
    _leftThumb.center = CGPointMake(_leftPosition+inset, _leftThumb.frame.size.height/2);
    
    _rightThumb.center = CGPointMake(_rightPosition-inset, _rightThumb.frame.size.height/2);
    
    _scrubber.center = CGPointMake(_scrubberPosition, _scrubber.center.y);
    
    _topBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, 0, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);
    
    _bottomBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _bgView.frame.size.height-SLIDER_BORDERS_SIZE, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);
    
    
    _centerView.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _centerView.frame.origin.y, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width, _centerView.frame.size.height);
    
    CGRect frame = _popoverBubble.frame;
    frame.origin.x = _centerView.frame.origin.x+_centerView.frame.size.width/2-frame.size.width/2;
    _popoverBubble.frame = frame;
    
    _scrubberPopoverBubble.center = CGPointMake(_scrubberPosition, _scrubberPopoverBubble.center.y);
    
    [self fixOffscreenPopoverBubble:_scrubberPopoverBubble];
    [self fixOffscreenPopoverBubble:_popoverBubble];
//    NSLog(@"LEFT SLIDER: %f", [self leftTimePosition]);
//    NSLog(@"Right SLIDER: %f", [self rightTimePosition]);
//    NSLog(@"scrubber: %f", [self scrubberTimePosition]);
}

-(void)fixOffscreenPopoverBubble:(UIView *)popover {
    if (popover.frame.origin.x < 0) {
        CGRect frame = popover.frame;
        frame.origin = CGPointMake(0, frame.origin.y);
        popover.frame = frame;
    } else if (popover.frame.origin.x + popover.frame.size.width > _frame_width) {
        CGRect frame = popover.frame;
        frame.origin = CGPointMake(_frame_width - popover.frame.size.width, frame.origin.y);
        popover.frame = frame;
    }
}

-(void)updateScrubberWithCurrentPlayTime:(NSTimeInterval)time {
    if (!isnan(time) && !isnan(self.durationSeconds)) {
        if (time < 0) time = 0;
        CGFloat ratio = time/(CGFloat)_durationSeconds;
        CGFloat position = (ratio * (_frame_width-( _leftThumb.frame.size.width*2)) ) + _leftThumb.frame.size.width;
        _scrubberPosition = position;
//    NSLog(@"time = %f", time);
        _scrubber.center = CGPointMake(_scrubberPosition, _scrubber.center.y);
    }
}


#pragma mark - Video

-(void)setUpTimelineImages {
    int picWidth = 20;
    int picsCnt = ceil(_bgView.frame.size.width / picWidth);
    self.timelineImageViews = [NSMutableArray array];
    for (int i = 0; i < picsCnt; i++) {
        UIImageView *tmp = [[UIImageView alloc] initWithFrame:CGRectMake(i*picWidth, 0, picWidth, _bgView.frame.size.height)];
        tmp.clipsToBounds = YES;
        tmp.contentMode = UIViewContentModeScaleAspectFill;
        [_bgView addSubview:tmp];
        [self.timelineImageViews addObject:tmp];
    }
}

-(void)getMovieFrame{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0){
        // Bug iOS7 - generateCGImagesAsynchronouslyForTimes
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            AVAsset *myAsset = [[AVURLAsset alloc] initWithURL:_videoUrl options:nil];
            self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:myAsset];
            self.imageGenerator.appliesPreferredTrackTransform = YES;
            if ([self isRetina]){
                self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width*2, _bgView.frame.size.height*2);
            } else {
                self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width, _bgView.frame.size.height);
            }
            
            int picWidth = 20;
            
            // First image
            NSError *error;
            CMTime actualTime;
            CGImageRef halfWayImage = [self.imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:&actualTime error:&error];
            if (halfWayImage != NULL) {
                UIImage *videoScreen;
                if ([self isRetina]){
                    videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage scale:2.0 orientation:UIImageOrientationUp];
                } else {
                    videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage];
                }
                UIImageView *tmp = [self.timelineImageViews firstObject];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView transitionWithView:tmp
                                      duration:0.2
                                       options:UIViewAnimationOptionTransitionCrossDissolve
                                    animations:^{
                                        tmp.image = videoScreen;
                                    } completion:nil];
                });
                CGImageRelease(halfWayImage);
            }
            
            
            _durationSeconds = CMTimeGetSeconds([myAsset duration]);
            
            
            NSMutableArray *allTimes = [[NSMutableArray alloc] init];
            int time4Pic = 0;
            //        int prefreWidth=0;
            
            
            for (int i=1, ii=1; i<[self.timelineImageViews count]; i++){
                time4Pic = i*picWidth;
                
                CMTime timeFrame = CMTimeMakeWithSeconds(_durationSeconds*time4Pic/_bgView.frame.size.width, 600);
                
                [allTimes addObject:[NSValue valueWithCMTime:timeFrame]];
                
                
                CGImageRef halfWayImage = [self.imageGenerator copyCGImageAtTime:timeFrame actualTime:&actualTime error:&error];
                
                UIImage *videoScreen;
                if ([self isRetina]){
                    videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage scale:2.0 orientation:UIImageOrientationUp];
                } else {
                    videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage];
                }
                
                
                
                UIImageView *tmp = [self.timelineImageViews objectAtIndex:i];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView transitionWithView:tmp
                                      duration:0.2
                                       options:UIViewAnimationOptionTransitionCrossDissolve
                                    animations:^{
                                        tmp.image = videoScreen;
                                    } completion:nil];
                });
                
                CGRect currentFrame = tmp.frame;
                //            currentFrame.origin.x = ii*picWidth;
                
                //            currentFrame.size.width=picWidth;
                //            prefreWidth+=currentFrame.size.width;
            
                int all = (ii+1)*tmp.frame.size.width;
                
                if (all > _bgView.frame.size.width){
                    int delta = all - _bgView.frame.size.width;
                    currentFrame.size.width -= delta;
                }
                tmp.frame = currentFrame;

                ii++;
                
                //            dispatch_async(dispatch_get_main_queue(), ^{
                //                [_bgView addSubview:tmp];
                //            });
                //
                
                
                
                CGImageRelease(halfWayImage);
                
            }
        });
        
        
        return;
    }
    
    AVAsset *myAsset = [[AVURLAsset alloc] initWithURL:_videoUrl options:nil];
    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:myAsset];
    
    if ([self isRetina]){
        self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width*2, _bgView.frame.size.height*2);
    } else {
        self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width, _bgView.frame.size.height);
    }
    
    int picWidth = 20;
    
    // First image
    NSError *error;
    CMTime actualTime;
    CGImageRef halfWayImage = [self.imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:&actualTime error:&error];
    if (halfWayImage != NULL) {
        UIImage *videoScreen;
        if ([self isRetina]){
            videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage scale:2.0 orientation:UIImageOrientationUp];
        } else {
            videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage];
        }
        UIImageView *tmp = [[UIImageView alloc] initWithImage:videoScreen];
        CGRect rect=tmp.frame;
        rect.size.width=picWidth;
        tmp.frame=rect;
        [_bgView addSubview:tmp];
        picWidth = tmp.frame.size.width;
        CGImageRelease(halfWayImage);
    }
    
    
    _durationSeconds = CMTimeGetSeconds([myAsset duration]);
    
    int picsCnt = ceil(_bgView.frame.size.width / picWidth);
    
    NSMutableArray *allTimes = [[NSMutableArray alloc] init];
    int time4Pic = 0;
    
    for (int i=1; i<picsCnt; i++){
        time4Pic = i*picWidth;
        
        CMTime timeFrame = CMTimeMakeWithSeconds(_durationSeconds*time4Pic/_bgView.frame.size.width, 600);
        
        [allTimes addObject:[NSValue valueWithCMTime:timeFrame]];
    }
    
    NSArray *times = allTimes;
    
    __block int i = 1;
    
    [self.imageGenerator generateCGImagesAsynchronouslyForTimes:times
                                              completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime,
                                                                  AVAssetImageGeneratorResult result, NSError *error) {
                                                  
                                                  if (result == AVAssetImageGeneratorSucceeded) {
                                                      
                                                      
                                                      UIImage *videoScreen;
                                                      if ([self isRetina]){
                                                          videoScreen = [[UIImage alloc] initWithCGImage:image scale:2.0 orientation:UIImageOrientationUp];
                                                      } else {
                                                          videoScreen = [[UIImage alloc] initWithCGImage:image];
                                                      }
                                                      
                                                      
                                                      UIImageView *tmp = [[UIImageView alloc] initWithImage:videoScreen];
                                                      
                                                      int all = (i+1)*tmp.frame.size.width;
                                                      
                                                      
                                                      CGRect currentFrame = tmp.frame;
                                                      currentFrame.origin.x = i*currentFrame.size.width;
                                                      if (all > _bgView.frame.size.width){
                                                          int delta = all - _bgView.frame.size.width;
                                                          currentFrame.size.width -= delta;
                                                      }
                                                      tmp.frame = currentFrame;
                                                      i++;
                                                      
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [_bgView addSubview:tmp];
                                                      });
                                                      
                                                  }
                                                  
                                                  if (result == AVAssetImageGeneratorFailed) {
                                                      NSLog(@"Failed with error: %@", [error localizedDescription]);
                                                  }
                                                  if (result == AVAssetImageGeneratorCancelled) {
                                                      NSLog(@"Canceled");
                                                  }
                                              }];
}




#pragma mark - Properties

- (CGFloat)leftTimePosition {
    return (_leftPosition / (_frame_width-(_leftThumb.frame.size.width*2))) * _durationSeconds;
}


- (CGFloat)rightTimePosition {
    return ((_rightPosition-_leftThumb.frame.size.width*2) / (_frame_width-(_leftThumb.frame.size.width*2))) *_durationSeconds;
}

-(CGFloat)scrubberTimePosition {
    return ((_scrubberPosition-_leftThumb.frame.size.width) / (_frame_width-(_leftThumb.frame.size.width*2))) * _durationSeconds;
}




#pragma mark - Bubble

- (void)hideBubble:(UIView *)popover
{
    [UIView animateWithDuration:0.4
                          delay:0
                        options:UIViewAnimationCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         
                         popover.alpha = 0;
                     }
                     completion:nil];
    
    if ([_delegate respondsToSelector:@selector(videoRange:didGestureStateEndedLeftPosition:rightPosition:)]){
        [_delegate videoRange:self didGestureStateEndedLeftPosition:self.leftPosition rightPosition:self.rightPosition];
        
    }
}

-(void)setScrubberTimeLabel:(CGFloat)seconds {
    self.scrubberBubleText.text = [self timeToStr:seconds];
}

-(void) setTimeLabel{
    self.bubleText.text = [self trimIntervalStr];
    //NSLog([self timeDuration1]);
    //NSLog([self timeDuration]);
}


-(NSString *)trimDurationStr{
    int delta = floor(self.rightPosition - self.leftPosition);
    return [NSString stringWithFormat:@"%d", delta];
}


-(NSString *)trimIntervalStr{
    
    NSString *from = [self timeToStr:[self leftTimePosition]];
    NSString *to = [self timeToStr:[self rightTimePosition]];
    return [NSString stringWithFormat:@"%@ - %@", from, to];
}




#pragma mark - Helpers

- (NSString *)timeToStr:(CGFloat)time
{
    // time - seconds
    NSInteger min = floor(time / 60);
    NSInteger sec = floor(time - min * 60);
    NSString *minStr = [NSString stringWithFormat:min >= 10 ? @"%i" : @"0%i", min];
    NSString *secStr = [NSString stringWithFormat:sec >= 10 ? @"%i" : @"0%i", sec];
    return [NSString stringWithFormat:@"%@:%@", minStr, secStr];
}


-(BOOL)isRetina{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
            
            ([UIScreen mainScreen].scale == 2.0));
}


@end
