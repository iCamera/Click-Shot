//
//  MHGalleryImageViewerViewController.m
//  MHVideoPhotoGallery
//
//  Created by Mario Hahn on 27.12.13.
//  Copyright (c) 2013 Mario Hahn. All rights reserved.
//

#import "MHGalleryImageViewerViewController.h"
#import "MHOverviewController.h"
#import "MHTransitionShowShareView.h"
#import "MHTransitionShowOverView.h"
#import "MHGallerySharedManagerPrivate.h"
#import "SAVideoRangeSlider.h"

@implementation MHPinchGestureRecognizer
@end

@interface MHGalleryImageViewerViewController()
@property (nonatomic, strong) UIActivityViewController *activityViewController;
@property (nonatomic, strong) UIBarButtonItem          *shareBarButton;
@property (nonatomic, strong) UIBarButtonItem          *leftBarButton;
@property (nonatomic, strong) UIBarButtonItem          *rightBarButton;
@property (nonatomic, strong) UIBarButtonItem          *playStopBarButton;
@property (nonatomic, strong) UIBarButtonItem          *trimBarButton;

@property (nonatomic, strong) NSMutableArray *videoGalleryItems;

@end

@implementation MHGalleryImageViewerViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.navigationController.delegate = self;
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    [self setNeedsStatusBarAppearanceUpdate];
    
    
    [UIApplication.sharedApplication setStatusBarStyle:self.galleryViewController.preferredStatusBarStyleMH
                                              animated:YES];
    
    if (![self.descriptionViewBackground isDescendantOfView:self.view]) {
        [self.view addSubview:self.descriptionViewBackground];
    }
    if (![self.descriptionView isDescendantOfView:self.view]) {
        [self.view addSubview:self.descriptionView];
    }
    if (![self.toolbar isDescendantOfView:self.view]) {
        [self.view addSubview:self.toolbar];
    }
    [self.pageViewController.view.subviews.firstObject setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    
}

- (UIStatusBarStyle)preferredStatusBarStyle{
    return  self.galleryViewController.preferredStatusBarStyleMH;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.navigationController.delegate == self) {
        self.navigationController.delegate = nil;
    }
}

-(void)donePressed{
    MHImageViewController *imageViewer = self.pageViewController.viewControllers.firstObject;
    if (imageViewer.moviePlayer) {
        [imageViewer removeAllMoviePlayerViewsAndNotifications];
    }
    MHTransitionDismissMHGallery *dismissTransiton = [MHTransitionDismissMHGallery new];
    dismissTransiton.orientationTransformBeforeDismiss = [(NSNumber *)[self.navigationController.view valueForKeyPath:@"layer.transform.rotation.z"] floatValue];
    imageViewer.interactiveTransition = dismissTransiton;
    
    if (self.galleryViewController && self.galleryViewController.finishedCallback) {
        self.galleryViewController.finishedCallback(self.pageIndex,imageViewer.imageView.image,dismissTransiton,self.viewModeForBarStyle);
    }
}

-(MHGalleryViewMode)viewModeForBarStyle{
    if (self.isHiddingToolBarAndNavigationBar) {
        return MHGalleryViewModeImageViewerNavigationBarHidden;
    }
    return MHGalleryViewModeImageViewerNavigationBarShown;
}

-(void)viewDidLoad{
    [super viewDidLoad];
    
    self.videoGalleryItems = [NSMutableArray new];
    for (int i = 0; i < [self.galleryItems count]; i++) {
        MHGalleryItem *item = [self.galleryItems objectAtIndex:i];
        if (item.galleryType == MHGalleryTypeVideo) [self.videoGalleryItems addObject:item];
    }

    self.UICustomization          = self.galleryViewController.UICustomization;
    self.transitionCustomization  = self.galleryViewController.transitionCustomization;
    
    if (!self.UICustomization.showOverView) {
        self.navigationItem.hidesBackButton = YES;
    }else{
        if (self.galleryViewController.UICustomization.backButtonState == MHBackButtonStateWithoutBackArrow) {
            UIBarButtonItem *backBarButton = [UIBarButtonItem.alloc initWithImage:MHTemplateImage(@"ic_square")
                                                                            style:UIBarButtonItemStyleBordered
                                                                           target:self
                                                                           action:@selector(backButtonAction)];
            self.navigationItem.hidesBackButton = YES;
            self.navigationItem.leftBarButtonItem = backBarButton;
        }
    }
    
    UIBarButtonItem *doneBarButton =  [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                  target:self
                                                                                  action:@selector(donePressed)];
    
    self.navigationItem.rightBarButtonItem = doneBarButton;
    
    self.view.backgroundColor = [self.UICustomization MHGalleryBackgroundColorForViewMode:MHGalleryViewModeImageViewerNavigationBarShown];
    
    
    self.pageViewController = [UIPageViewController.alloc initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                            navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                          options:@{ UIPageViewControllerOptionInterPageSpacingKey : @30.f }];
    self.pageViewController.delegate = self;
    self.pageViewController.dataSource = self;
    self.pageViewController.automaticallyAdjustsScrollViewInsets =NO;
    
    MHGalleryItem *item = [self itemForIndex:self.pageIndex];
    
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:item viewController:self];
    imageViewController.pageIndex = self.pageIndex;
    [self.pageViewController setViewControllers:@[imageViewController]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:NO
                                     completion:nil];
    
    
    [self addChildViewController:self.pageViewController];
    [self.pageViewController didMoveToParentViewController:self];
    [self.view addSubview:self.pageViewController.view];
    
    self.toolbar = [UIToolbar.alloc initWithFrame:CGRectMake(0, self.view.frame.size.height-44, self.view.frame.size.width, 44)];
    if(self.currentOrientation == UIInterfaceOrientationLandscapeLeft || self.currentOrientation == UIInterfaceOrientationLandscapeRight){
        if (self.view.bounds.size.height > self.view.bounds.size.width) {
            self.toolbar.frame = CGRectMake(0, self.view.frame.size.width-44, self.view.frame.size.height, 44);
        }
    }
    
    self.toolbar.tintColor = self.UICustomization.barButtonsTintColor;
    self.toolbar.tag = 307;
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
    
    self.playStopBarButton = [UIBarButtonItem.alloc initWithImage:MHGalleryImage(@"play")
                                                            style:UIBarButtonItemStyleBordered
                                                           target:self
                                                           action:@selector(playStopButtonPressed)];
    
    self.leftBarButton = [UIBarButtonItem.alloc initWithImage:MHGalleryImage(@"left_arrow")
                                                        style:UIBarButtonItemStyleBordered
                                                       target:self
                                                       action:@selector(leftPressed:)];
    
    self.rightBarButton = [UIBarButtonItem.alloc initWithImage:MHGalleryImage(@"right_arrow")
                                                         style:UIBarButtonItemStyleBordered
                                                        target:self
                                                        action:@selector(rightPressed:)];
    
    self.shareBarButton = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                      target:self
                                                                      action:@selector(sharePressed)];
    
    
    self.trimBarButton = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                      target:self
                                                                      action:@selector(trimPressed)];
    self.trimBarButton.enabled = NO;
    
    if (self.UICustomization.hideShare) {
        self.shareBarButton = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                          target:self
                                                                          action:nil];
    }
    
    [self updateToolBarForItem:item];
    
    if (self.pageIndex == 0) {
        self.leftBarButton.enabled =NO;
    }
    if(self.pageIndex == self.numberOfGalleryItems-1){
        self.rightBarButton.enabled =NO;
    }
    
    self.descriptionViewBackground = [UIToolbar.alloc initWithFrame:CGRectZero];
    self.descriptionView = [UITextView.alloc initWithFrame:CGRectZero];
    self.descriptionView.backgroundColor = [UIColor clearColor];
    self.descriptionView.font = [UIFont systemFontOfSize:15];
    self.descriptionView.text = item.description;
    self.descriptionView.textColor = [UIColor blackColor];
    self.descriptionView.scrollEnabled = NO;
    self.descriptionView.userInteractionEnabled = NO;
    
    
    self.toolbar.barTintColor = self.UICustomization.barTintColor;
    self.toolbar.barStyle = self.UICustomization.barStyle;
    self.descriptionViewBackground.barTintColor = self.UICustomization.barTintColor;
    self.descriptionViewBackground.barStyle = self.UICustomization.barStyle;
    
    CGSize size = [self.descriptionView sizeThatFits:CGSizeMake(self.view.frame.size.width-20, MAXFLOAT)];
    
    self.descriptionView.frame = CGRectMake(10, self.view.frame.size.height -size.height-44, self.view.frame.size.width-20, size.height);
    if (self.descriptionView.text.length >0) {
        self.descriptionViewBackground.frame = CGRectMake(0, self.view.frame.size.height -size.height-44, self.view.frame.size.width, size.height);
    }else{
        self.descriptionViewBackground.hidden =YES;
    }
    
    [(UIScrollView*)self.pageViewController.view.subviews[0] setDelegate:self];
    [(UIGestureRecognizer*)[[self.pageViewController.view.subviews[0] gestureRecognizers] firstObject] setDelegate:self];
    
    [self updateTitleForIndex:self.pageIndex];
}
-(void)backButtonAction{
    [self.navigationController popToRootViewControllerAnimated:YES];
    
}


-(UIInterfaceOrientation)currentOrientation{
    return UIApplication.sharedApplication.statusBarOrientation;
}

-(NSInteger)numberOfGalleryItems{
    return [self.galleryViewController.dataSource numberOfItemsInGallery:self.galleryViewController];
}

-(MHGalleryItem*)itemForIndex:(NSInteger)index{
    if (index < 0) index = 0;
    return [self.galleryViewController.dataSource itemForIndex:index];
}

-(MHGalleryController*)galleryViewController{
    if ([self.navigationController isKindOfClass:MHGalleryController.class]) {
        return (MHGalleryController*)self.navigationController;
    }
    return nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:UIButton.class]) {
        if (touch.view.tag != 508) {
            return YES;
        }
    }
    return ([touch.view isKindOfClass:UIControl.class] == NO);
}

-(void)changeToPlayButton{
    self.playStopBarButton.image = MHGalleryImage(@"play");
}

-(void)changeToPauseButton{
    self.playStopBarButton.image = MHGalleryImage(@"pause");
}

-(void)playStopButtonPressed{
    for (MHImageViewController *imageViewController in self.pageViewController.viewControllers) {
        if (imageViewController.pageIndex == self.pageIndex) {
            if (imageViewController.isPlayingVideo) {
                [imageViewController stopMovie];
                [self changeToPlayButton];
            }else{
                [imageViewController playButtonPressed];
            }
        }
    }
}

-(void)sharePressed{
    if (self.UICustomization.showMHShareViewInsteadOfActivityViewController) {
        MHShareViewController *share = [MHShareViewController new];
        
        MHGalleryItem *selectedVideo = [self.galleryItems objectAtIndex:self.pageIndex];
        
        share.pageIndex = [self.videoGalleryItems indexOfObject:selectedVideo];
        if (share.pageIndex == NSNotFound) return;
        share.galleryItems = self.videoGalleryItems;
        [self.navigationController pushViewController:share
                                             animated:YES];
    }else{
        UIActivityViewController *act = [UIActivityViewController.alloc initWithActivityItems:@[[(MHImageViewController*)self.pageViewController.viewControllers.firstObject imageView].image] applicationActivities:nil];
        [self presentViewController:act animated:YES completion:nil];
        
    }
}

-(void)updateDescriptionLabelForIndex:(NSInteger)index{
    if (index < self.numberOfGalleryItems) {
        MHGalleryItem *item = [self itemForIndex:index];
        self.descriptionView.text = item.description;
        
        if (item.attributedString) {
            self.descriptionView.attributedText = item.attributedString;
        }
        CGSize size = [self.descriptionView sizeThatFits:CGSizeMake(self.view.frame.size.width-20, MAXFLOAT)];
        
        self.descriptionView.frame = CGRectMake(10, self.view.frame.size.height -size.height-44, self.view.frame.size.width-20, size.height);
        if (self.descriptionView.text.length >0) {
            self.descriptionViewBackground.hidden =NO;
            self.descriptionViewBackground.frame = CGRectMake(0, self.view.frame.size.height -size.height-44, self.view.frame.size.width, size.height);
        }else{
            self.descriptionViewBackground.hidden =YES;
        }
    }
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    self.userScrolls = NO;
    [self updateTitleAndDescriptionForScrollView:scrollView];
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    self.userScrolls = YES;
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [self updateTitleAndDescriptionForScrollView:scrollView];
}

-(void)updateTitleAndDescriptionForScrollView:(UIScrollView*)scrollView{
    NSInteger pageIndex = self.pageIndex;
    if (scrollView.contentOffset.x > (self.view.frame.size.width+self.view.frame.size.width/2)) {
        pageIndex++;
    }
    if (scrollView.contentOffset.x < self.view.frame.size.width/2) {
        pageIndex--;
    }
    [self updateDescriptionLabelForIndex:pageIndex];
    [self updateTitleForIndex:pageIndex];
}

-(void)updateTitleForIndex:(NSInteger)pageIndex{
    NSString *localizedString  = MHGalleryLocalizedString(@"imagedetail.title.current");
    self.navigationItem.title = [NSString stringWithFormat:localizedString,@(pageIndex+1),@(self.numberOfGalleryItems)];
}


-(void)pageViewController:(UIPageViewController *)pageViewController
       didFinishAnimating:(BOOL)finished
  previousViewControllers:(NSArray *)previousViewControllers
      transitionCompleted:(BOOL)completed{
    
    self.pageIndex = [pageViewController.viewControllers.firstObject pageIndex];
    [self showCurrentIndex:self.pageIndex];
    
    if (finished) {
        for (MHImageViewController *imageViewController in previousViewControllers) {
            [self removeVideoPlayerForVC:imageViewController];
        }
    }
    if (completed) {
        [self updateToolBarForItem:[self itemForIndex:self.pageIndex]];
    }
}



-(void)removeVideoPlayerForVC:(MHImageViewController*)vc{
    if (vc.pageIndex != self.pageIndex) {
        if (vc.videoPlayer) {
            if (vc.item.galleryType == MHGalleryTypeVideo) {
                if (vc.isPlayingVideo) {
                    [vc stopMovie];
                }
//                vc.currentTimeMovie =0;
            }
        }
    }
}

-(void)updateToolBarForItem:(MHGalleryItem*)item{
    
    UIBarButtonItem *flex = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                        target:self
                                                                        action:nil];
    
    UIBarButtonItem *fixed = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                         target:self
                                                                         action:nil];
    fixed.width = 30;
    
    if (item.galleryType == MHGalleryTypeVideo) {
        [self changeToPlayButton];
        self.toolbar.items = @[self.shareBarButton,flex,self.leftBarButton,flex,self.playStopBarButton,flex,self.rightBarButton,flex,self.trimBarButton];
    } else{
        self.toolbar.items =@[fixed,flex,self.leftBarButton,flex,self.rightBarButton,flex,fixed];
    }
}



- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    if ([animationController isKindOfClass:MHTransitionShowOverView.class]) {
        MHImageViewController *imageViewController = self.pageViewController.viewControllers.firstObject;
        return imageViewController.interactiveOverView;
    } else {
        return nil;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    
    MHImageViewController *theCurrentViewController = self.pageViewController.viewControllers.firstObject;
    if (theCurrentViewController.moviePlayer) {
        [theCurrentViewController removeAllMoviePlayerViewsAndNotifications];
    }
    
    if ([toVC isKindOfClass:MHShareViewController.class]) {
        MHTransitionShowShareView *present = MHTransitionShowShareView.new;
        present.present = YES;
        return present;
    }
    if ([toVC isKindOfClass:MHOverviewController.class]) {
        return MHTransitionShowOverView.new;
    }
    return nil;
}

-(void)leftPressed:(id)sender{
    self.rightBarButton.enabled = YES;
    
    MHImageViewController *theCurrentViewController = self.pageViewController.viewControllers.firstObject;
    NSUInteger indexPage = theCurrentViewController.pageIndex;
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:indexPage-1] viewController:self];
    imageViewController.pageIndex = indexPage-1;
    
    if (indexPage-1 == 0) {
        self.leftBarButton.enabled = NO;
    }
    
    __weak typeof(self) weakSelf = self;
    
    [self.pageViewController setViewControllers:@[imageViewController] direction:UIPageViewControllerNavigationDirectionReverse animated:YES completion:^(BOOL finished) {
        weakSelf.pageIndex = imageViewController.pageIndex;
        [weakSelf updateToolBarForItem:[weakSelf itemForIndex:weakSelf.pageIndex]];
        [weakSelf showCurrentIndex:weakSelf.pageIndex];
    }];
}

-(void)rightPressed:(id)sender{
    self.leftBarButton.enabled =YES;
    
    MHImageViewController *theCurrentViewController = self.pageViewController.viewControllers.firstObject;
    NSUInteger indexPage = theCurrentViewController.pageIndex;
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:indexPage+1] viewController:self];
    imageViewController.pageIndex = indexPage+1;
    
    if (indexPage+1 == self.numberOfGalleryItems-1) {
        self.rightBarButton.enabled = NO;
    }
    __weak typeof(self) weakSelf = self;
    
    [self.pageViewController setViewControllers:@[imageViewController] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:^(BOOL finished) {
        weakSelf.pageIndex = imageViewController.pageIndex;
        [weakSelf updateToolBarForItem:[weakSelf itemForIndex:weakSelf.pageIndex]];
        [weakSelf showCurrentIndex:weakSelf.pageIndex];
    }];
}

-(void)trimPressed {
    MHImageViewController *currentViewController = self.pageViewController.viewControllers.firstObject;
//    NSLog(@"start %f - end %f", imageViewController.startTime, imageViewController.endTime);


    [self trimVideo:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"remoteShotEdited.MOV"]] assetObject:currentViewController.videoPlayerAsset startTime:currentViewController.startTime endTime:currentViewController.endTime];

}

- (void)trimVideo:(NSURL *)outputURL assetObject:(AVAsset *)asset startTime:(CGFloat)startTime endTime:(CGFloat)endTime
{
    
    
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    if ([compatiblePresets containsObject:AVAssetExportPresetHighestQuality]) {
        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]
                              initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
        // Implementation continues.
        
        
        exportSession.outputURL = outputURL;
        //provide outputFileType acording to video format extension
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        
        CMTime start = CMTimeMakeWithSeconds(startTime, asset.duration.timescale);
        CMTime duration = CMTimeMakeWithSeconds(endTime-startTime, asset.duration.timescale);
        CMTimeRange range = CMTimeRangeMake(start, duration);
        exportSession.timeRange = range;
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            
            switch ([exportSession status]) {
                case AVAssetExportSessionStatusFailed: {
                    NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
                    NSError *removeError =nil;
                    [NSFileManager.defaultManager removeItemAtURL:[exportSession outputURL] error:&removeError];

                    break;
                }
                case AVAssetExportSessionStatusCancelled: {
                    NSLog(@"Export canceled");

                    break;
                }
                default:
                    NSLog(@"Triming Completed");
                    ALAssetsLibrary* library = ALAssetsLibrary.new;
                    [library writeVideoAtPathToSavedPhotosAlbum:[exportSession outputURL]
                                                completionBlock:^(NSURL *assetURL, NSError *error){
                                                    NSError *removeError =nil;
                                                    [NSFileManager.defaultManager removeItemAtURL:[exportSession outputURL] error:&removeError];
                                                    [[self galleryViewController].galleryDelegate didFinishTrimmingVideo];
                                                    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                                        [group setAssetsFilter:[ALAssetsFilter allAssets]];
                                                        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *alAsset, NSUInteger index, BOOL *innerStop) {
                                                            if (alAsset) {
                                                                if ([[alAsset valueForProperty:@"ALAssetPropertyType"] isEqualToString:@"ALAssetTypePhoto"]) {
                                                                    MHGalleryItem *item = [[MHGalleryItem alloc]initWithURL:[alAsset.defaultRepresentation.url absoluteString]
                                                                                                                galleryType:MHGalleryTypeImage];
                                                                    NSMutableArray *temp = [NSMutableArray arrayWithArray:self.galleryItems];
                                                                    [temp insertObject:item atIndex:0];
                                                                    self.galleryItems = [NSArray arrayWithArray:temp];
                                                                    [self galleryViewController].galleryItems = self.galleryItems;
                                                                } else {
                                                                    MHGalleryItem *item = [[MHGalleryItem alloc]initWithURL:[alAsset.defaultRepresentation.url absoluteString]
                                                                                                                galleryType:MHGalleryTypeVideo];
                                                                    NSMutableArray *temp = [NSMutableArray arrayWithArray:self.galleryItems];
                                                                    [temp insertObject:item atIndex:0];
                                                                    self.galleryItems = [NSArray arrayWithArray:temp];
                                                                    [self galleryViewController].galleryItems = self.galleryItems;
                                                                }
                                                                *innerStop = YES;

                                                                [self jumpToFront];
                                                                
                                                            }
                                                        }];
                                                    } failureBlock: ^(NSError *error) {
                                                        
                                                    }];
                                                }];

                    break;
            }
        }];
        
    }
}

-(void)jumpToFront {
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:0] viewController:self];
    imageViewController.pageIndex = 0;
    
    self.leftBarButton.enabled = NO;
    
    __weak typeof(self) weakSelf = self;
    weakSelf.pageIndex = imageViewController.pageIndex;
    [weakSelf updateToolBarForItem:[weakSelf itemForIndex:weakSelf.pageIndex]];
    [weakSelf showCurrentIndex:weakSelf.pageIndex];
    [self.pageViewController setViewControllers:@[imageViewController] direction:UIPageViewControllerNavigationDirectionReverse animated:YES completion:^(BOOL finished) {

    }];
}

-(void)showCurrentIndex:(NSInteger)currentIndex{
    if ([self.galleryViewController.galleryDelegate respondsToSelector:@selector(galleryController:didShowIndex:)]) {
        [self.galleryViewController.galleryDelegate galleryController:self.galleryViewController
                                                         didShowIndex:currentIndex];
    }
    
}

- (UIViewController *)pageViewController:(UIPageViewController *)pvc viewControllerBeforeViewController:(MHImageViewController *)vc{
    
    NSInteger indexPage = vc.pageIndex;
    
    if (self.numberOfGalleryItems !=1 && self.numberOfGalleryItems-1 != indexPage) {
        self.leftBarButton.enabled =YES;
        self.rightBarButton.enabled =YES;
    }
    
    [self removeVideoPlayerForVC:vc];
    
    if (indexPage ==0) {
        self.leftBarButton.enabled = NO;
        MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:nil viewController:self];
        imageViewController.pageIndex = 0;
        return imageViewController;
    }
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:indexPage-1] viewController:self];
    imageViewController.pageIndex = indexPage-1;
    
    return imageViewController;
}

-(MHImageViewController*)imageViewControllerWithItem:(MHGalleryItem*)item pageIndex:(NSInteger)pageIndex{
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:pageIndex] viewController:self];
    imageViewController.pageIndex  = pageIndex;
    return imageViewController;
}
- (UIViewController *)pageViewController:(UIPageViewController *)pvc viewControllerAfterViewController:(MHImageViewController *)vc{
    
    
    NSInteger indexPage = vc.pageIndex;
    
    if (self.numberOfGalleryItems !=1 && indexPage !=0) {
        self.leftBarButton.enabled = YES;
        self.rightBarButton.enabled = YES;
    }
    [self removeVideoPlayerForVC:vc];
    
    if (indexPage ==self.numberOfGalleryItems-1) {
        self.rightBarButton.enabled = NO;
        MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:nil viewController:self];
        imageViewController.pageIndex = self.numberOfGalleryItems-1;
        return imageViewController;
    }
    MHImageViewController *imageViewController =[MHImageViewController imageViewControllerForMHMediaItem:[self itemForIndex:indexPage+1] viewController:self];
    imageViewController.pageIndex  = indexPage+1;
    return imageViewController;
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    self.toolbar.frame = CGRectMake(0, self.view.frame.size.height-44, self.view.frame.size.width, 44);
    self.pageViewController.view.bounds = self.view.bounds;
    [self.pageViewController.view.subviews.firstObject setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) ];
    
}

@end

@interface MHImageViewController () <SAVideoRangeSliderDelegate>
@property (nonatomic, strong) UIButton                 *moviewPlayerButtonBehinde;
@property (nonatomic, strong) NSTimer                  *movieTimer;
@property (nonatomic, strong) NSTimer                  *movieDownloadedTimer;
@property (nonatomic, strong) UIPanGestureRecognizer   *pan;
@property (nonatomic, strong) MHPinchGestureRecognizer *pinch;

@property (nonatomic, strong) SAVideoRangeSlider *videoRangeSlider;
@property (nonatomic) CGFloat videoDuration;


//@property (nonatomic)         NSInteger                wholeTimeMovie;
@property (nonatomic)         CGPoint                  pointToCenterAfterResize;
@property (nonatomic)         CGFloat                  scaleToRestoreAfterResize;
@property (nonatomic)         CGPoint                  startPoint;
@property (nonatomic)         CGPoint                  lastPoint;
@property (nonatomic)         CGPoint                  lastPointPop;
@property (nonatomic)         BOOL                     shouldPlayVideo;

@end

@implementation MHImageViewController


+(MHImageViewController *)imageViewControllerForMHMediaItem:(MHGalleryItem*)item
                                             viewController:(MHGalleryImageViewerViewController*)viewController{
    if (item) {
        return [self.alloc initWithMHMediaItem:item
                                viewController:viewController];
    }
    return nil;
}
-(CGFloat)checkProgressValue:(CGFloat)progress{
    CGFloat progressChecked =progress;
    if (progressChecked <0) {
        progressChecked = -progressChecked;
    }
    if (progressChecked >=1) {
        progressChecked =0.99;
    }
    return progressChecked;
}

-(void)userDidPinch:(UIPinchGestureRecognizer*)recognizer{
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (recognizer.scale <1) {
            self.imageView.frame = self.scrollView.frame;
            
            self.lastPointPop = [recognizer locationInView:self.view];
            self.interactiveOverView = [MHTransitionShowOverView new];
            [self.navigationController popViewControllerAnimated:YES];
        }else{
            recognizer.cancelsTouchesInView = YES;
        }
        
    }else if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        if (recognizer.numberOfTouches <2) {
            recognizer.enabled =NO;
            recognizer.enabled =YES;
        }
        
        CGPoint point = [recognizer locationInView:self.view];
        self.interactiveOverView.scale = recognizer.scale;
        self.interactiveOverView.changedPoint = CGPointMake(self.lastPointPop.x - point.x, self.lastPointPop.y - point.y) ;
        [self.interactiveOverView updateInteractiveTransition:1-recognizer.scale];
        self.lastPointPop = point;
    }else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        if (recognizer.scale < 0.65) {
            [self.interactiveOverView finishInteractiveTransition];
        }else{
            [self.interactiveOverView cancelInteractiveTransition];
        }
        self.interactiveOverView = nil;
    }
}

-(void)userDidPan:(UIPanGestureRecognizer*)recognizer{
    
    BOOL userScrolls = self.viewController.userScrolls;
    if (self.viewController.transitionCustomization.dismissWithScrollGestureOnFirstAndLastImage) {
        if (!self.interactiveTransition) {
            if (self.viewController.numberOfGalleryItems ==1) {
                userScrolls = NO;
                self.viewController.userScrolls = NO;
            }else{
                if (self.pageIndex ==0) {
                    if ([recognizer translationInView:self.view].x >=0) {
                        userScrolls =NO;
                        self.viewController.userScrolls = NO;
                    }else{
                        recognizer.cancelsTouchesInView = YES;
                        recognizer.enabled =NO;
                        recognizer.enabled =YES;
                    }
                }
                if ((self.pageIndex == self.viewController.numberOfGalleryItems-1)) {
                    if ([recognizer translationInView:self.view].x <=0) {
                        userScrolls =NO;
                        self.viewController.userScrolls = NO;
                    }else{
                        recognizer.cancelsTouchesInView = YES;
                        recognizer.enabled =NO;
                        recognizer.enabled =YES;
                    }
                }
            }
        }else{
            userScrolls = NO;
        }
    }
    
    if (!userScrolls || recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        CGFloat progressY = (self.startPoint.y - [recognizer translationInView:self.view].y)/(self.view.frame.size.height/2);
        progressY = [self checkProgressValue:progressY];
        CGFloat progressX = (self.startPoint.x - [recognizer translationInView:self.view].x)/(self.view.frame.size.width/2);
        progressX = [self checkProgressValue:progressX];
        
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            self.startPoint = [recognizer translationInView:self.view];
        }else if (recognizer.state == UIGestureRecognizerStateChanged) {
            if (!self.interactiveTransition ) {
                self.startPoint = [recognizer translationInView:self.view];
                self.lastPoint = [recognizer translationInView:self.view];
                self.interactiveTransition = [MHTransitionDismissMHGallery new];
                self.interactiveTransition.orientationTransformBeforeDismiss = [(NSNumber *)[self.navigationController.view valueForKeyPath:@"layer.transform.rotation.z"] floatValue];
                self.interactiveTransition.interactive = YES;
                
                if (self.viewController.galleryViewController && self.viewController.galleryViewController.finishedCallback) {
                    self.viewController.galleryViewController.finishedCallback(self.pageIndex,self.imageView.image,self.interactiveTransition,self.viewController.viewModeForBarStyle);
                }
                
            }else{
                CGPoint currentPoint = [recognizer translationInView:self.view];
                
                if (self.viewController.transitionCustomization.fixXValueForDismiss) {
                    self.interactiveTransition.changedPoint = CGPointMake(self.startPoint.x, self.lastPoint.y-currentPoint.y);
                }else{
                    self.interactiveTransition.changedPoint = CGPointMake(self.lastPoint.x-currentPoint.x, self.lastPoint.y-currentPoint.y);
                }
                progressY = [self checkProgressValue:progressY];
                progressX = [self checkProgressValue:progressX];
                
                if (!self.viewController.transitionCustomization.fixXValueForDismiss) {
                    if (progressX> progressY) {
                        progressY = progressX;
                    }
                }
                
                [self.interactiveTransition updateInteractiveTransition:progressY];
                self.lastPoint = [recognizer translationInView:self.view];
            }
            
        }else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
            if (self.interactiveTransition) {
                CGFloat velocityY = [recognizer velocityInView:self.view].y;
                if (velocityY <0) {
                    velocityY = -velocityY;
                }
                if (!self.viewController.transitionCustomization.fixXValueForDismiss) {
                    if (progressX> progressY) {
                        progressY = progressX;
                    }
                }
                
                if (progressY > 0.35 || velocityY >700) {
                    MHStatusBar().alpha =1;
                    [self.interactiveTransition finishInteractiveTransition];
                }else {
                    [self setNeedsStatusBarAppearanceUpdate];
                    [self.interactiveTransition cancelInteractiveTransition];
                }
                self.interactiveTransition = nil;
            }
        }
    }
}


- (id)initWithMHMediaItem:(MHGalleryItem*)mediaItem
           viewController:(MHGalleryImageViewerViewController*)viewController{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        
        __weak typeof(self) weakSelf = self;
        
        
        self.viewController = viewController;
        
        self.view.backgroundColor = [UIColor blackColor];
        
        self.shouldPlayVideo = NO;
        
        self.item = mediaItem;
        
        self.scrollView = [UIScrollView.alloc initWithFrame:self.view.bounds];
        self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin;
        self.scrollView.delegate = self;
        self.scrollView.tag = 406;
        self.scrollView.maximumZoomScale =3;
        self.scrollView.minimumZoomScale= 1;
        self.scrollView.userInteractionEnabled = YES;
        [self.view addSubview:self.scrollView];
        
        
        self.imageView = [UIImageView.alloc initWithFrame:self.view.bounds];
        self.imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.clipsToBounds = YES;
        self.imageView.tag = 506;
        [self.scrollView addSubview:self.imageView];
        
        self.pinch = [MHPinchGestureRecognizer.alloc initWithTarget:self action:@selector(userDidPinch:)];
        self.pinch.delegate = self;
        
        self.pan = [UIPanGestureRecognizer.alloc initWithTarget:self action:@selector(userDidPan:)];
        UITapGestureRecognizer *doubleTap = [UITapGestureRecognizer.alloc initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired =2;
        
        UITapGestureRecognizer *imageTap =[UITapGestureRecognizer.alloc initWithTarget:self action:@selector(handelImageTap:)];
        imageTap.numberOfTapsRequired =1;
        
        [self.imageView addGestureRecognizer:doubleTap];
        
        self.pan.delegate = self;
        
        if(self.viewController.transitionCustomization.interactiveDismiss){
            [self.imageView addGestureRecognizer:self.pan];
            self.pan.maximumNumberOfTouches =1;
            self.pan.delaysTouchesBegan = YES;
        }
        if (self.viewController.UICustomization.showOverView) {
            [self.scrollView addGestureRecognizer:self.pinch];
        }
        
        [self.view addGestureRecognizer:imageTap];
        
        self.act = [UIActivityIndicatorView.alloc initWithFrame:self.view.bounds];
        [self.act startAnimating];
        self.act.hidesWhenStopped =YES;
        self.act.tag = 507;
        self.act.autoresizingMask =UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        [self.scrollView addSubview:self.act];
        if (self.item.galleryType != MHGalleryTypeImage) {
            [self addPlayButtonToView];
            
            self.videoRangeSlider = [[SAVideoRangeSlider alloc] initWithFrame:CGRectMake(0, 44, self.view.frame.size.width, 44) videoUrl:[NSURL URLWithString:self.item.URLString]];
            self.videoRangeSlider.bubleText.font = [UIFont systemFontOfSize:12];
            self.videoRangeSlider.scrubberBubleText.font = [UIFont systemFontOfSize:12];
            [self.videoRangeSlider setPopoverBubbleFrame:CGRectMake(0, self.videoRangeSlider.frame.size.height, 120, 60)];
            [self.videoRangeSlider setScrubberPopoverBubbleFrame:CGRectMake(0, self.videoRangeSlider.frame.size.height, 100, 55)];
            self.videoRangeSlider.delegate = self;
            self.videoRangeSlider.alpha = 0;
            self.videoRangeSlider.minGap = 50;
            
            [self.view addSubview:self.videoRangeSlider];

            self.currentTimeMovie =0;
            self.startTime = 0;
            self.endTime = 0;
//            self.wholeTimeMovie =0;

            
            self.scrollView.maximumZoomScale = 1;
            self.scrollView.minimumZoomScale =1;
        }
        
        self.imageView.userInteractionEnabled = YES;
        
        [imageTap requireGestureRecognizerToFail: doubleTap];
        
        
        
        if (self.item.galleryType == MHGalleryTypeImage) {
            
            
            [self.imageView setImageForMHGalleryItem:self.item imageType:MHImageTypeFull successBlock:^(UIImage *image, NSError *error) {
                if (!image) {
                    weakSelf.scrollView.maximumZoomScale  =1;
                    [weakSelf changeToErrorImage];
                }
                [weakSelf.act stopAnimating];
            }];
            
        }else{
            [MHGallerySharedManager.sharedManager startDownloadingThumbImage:self.item.URLString
                                                                successBlock:^(UIImage *image,NSUInteger videoDuration,NSError *error) {
                                                                    if (!error) {
                                                                        [weakSelf handleGeneratedThumb:image
                                                                                         videoDuration:videoDuration
                                                                                             urlString:self.item.URLString];
                                                                    }else{
                                                                        [weakSelf changeToErrorImage];
                                                                    }
                                                                    [weakSelf.act stopAnimating];
                                                                }];
        }
    }
    
    return self;
}

-(void)setImageForImageViewWithImage:(UIImage*)image error:(NSError*)error{
    if (!image) {
        self.scrollView.maximumZoomScale  =1;
        [self changeToErrorImage];
    }else{
        self.imageView.image = image;
    }
    [self.act stopAnimating];
}

-(void)changeToErrorImage{
    self.imageView.image = MHGalleryImage(@"error");
}

-(void)changePlayButtonToUnPlay{
    [self.playButton setImage:MHGalleryImage(@"unplay")
                     forState:UIControlStateNormal];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    __weak typeof(self) weakSelf = self;
    
    if (!self.videoPlayer && self.item.galleryType == MHGalleryTypeVideo) {
        [[MHGallerySharedManager sharedManager] getURLForMediaPlayer:self.item.URLString successBlock:^(NSURL *URL, NSError *error) {
            if (error) {
                [weakSelf changePlayButtonToUnPlay];
            }else{
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,
                                                         (unsigned long)NULL), ^(void) {
                    [weakSelf addMoviePlayerToViewWithURL:URL];
                });
            }
        }];
    }
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopMovie];
}

-(void)handleGeneratedThumb:(UIImage*)image
              videoDuration:(NSInteger)videoDuration
                  urlString:(NSString*)urlString{
    
//    self.wholeTimeMovie = videoDuration;

    [self.view viewWithTag:508].hidden =NO;
    self.imageView.image = image;
    
    self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
    self.playButton.hidden = NO;
    [self.act stopAnimating];
}
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    if (self.interactiveOverView) {
        if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class]) {
            return YES;
        }
        return NO;
    }
    if (self.interactiveTransition) {
        if ([gestureRecognizer isEqual:self.pan]) {
            return YES;
        }
        return NO;
    }
    if (self.viewController.transitionCustomization.dismissWithScrollGestureOnFirstAndLastImage) {
        if ((self.pageIndex ==0 || self.pageIndex == self.viewController.numberOfGalleryItems -1)) {
            if ([gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]|| [otherGestureRecognizer isKindOfClass:NSClassFromString(@"UIScrollViewDelayedTouchesBeganGestureRecognizer")] ) {
                return YES;
            }
        }
    }
    return NO;
}
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    
    if (self.interactiveOverView) {
        if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class]) {
            return YES;
        }else{
            return NO;
        }
    }else{
        if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class]) {
            if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class] && self.scrollView.zoomScale ==1) {
                return YES;
            }else{
                return NO;
            }
        }
    }
    if (self.viewController.isUserScrolling) {
        if ([gestureRecognizer isEqual:self.pan]) {
            return NO;
        }
    }
    if ([gestureRecognizer isEqual:self.pan] && self.scrollView.zoomScale !=1) {
        return NO;
    }
    if (self.interactiveTransition) {
        if ([gestureRecognizer isEqual:self.pan]) {
            return YES;
        }
        return NO;
    }
    if (self.viewController.transitionCustomization.dismissWithScrollGestureOnFirstAndLastImage) {
        if ((self.pageIndex ==0 || self.pageIndex == self.viewController.numberOfGalleryItems -1) && [gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) {
            return YES;
        }
    }
    
    return YES;
}


-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    
    if (self.interactiveOverView || self.interactiveTransition) {
        return NO;
    }
    if ([otherGestureRecognizer isKindOfClass:NSClassFromString(@"UIScrollViewDelayedTouchesBeganGestureRecognizer")]|| [otherGestureRecognizer isKindOfClass:NSClassFromString(@"UIScrollViewPanGestureRecognizer")] ) {
        return YES;
    }
    if ([gestureRecognizer isKindOfClass:MHPinchGestureRecognizer.class]) {
        return YES;
    }
    if (self.viewController.transitionCustomization.dismissWithScrollGestureOnFirstAndLastImage) {
        if ((self.pageIndex ==0 || self.pageIndex == self.viewController.numberOfGalleryItems -1) && [gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) {
            return YES;
        }
    }
    return NO;
}

-(void)stopMovie{
    
    self.shouldPlayVideo = NO;
    
    [self stopTimer];
    
    self.playingVideo = NO;
    [self.videoPlayer pause];
    
    [self.view bringSubviewToFront:self.playButton];
    [self.view bringSubviewToFront:self.videoRangeSlider];
    [self.viewController changeToPlayButton];
}

-(void)changeToPlayable{
    self.videoWasPlayable = YES;
    if(!self.viewController.isHiddingToolBarAndNavigationBar){
        self.videoRangeSlider.alpha = 1;
    }
    
    self.videoPlayerLayer.hidden = NO;
    
    self.moviewPlayerButtonBehinde = [UIButton.alloc initWithFrame:self.view.bounds];
    [self.moviewPlayerButtonBehinde addTarget:self action:@selector(handelImageTap:) forControlEvents:UIControlEventTouchUpInside];
    self.moviewPlayerButtonBehinde.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    [self.view bringSubviewToFront:self.scrollView];
    [self bringSublayerToFront:self.videoPlayerLayer];
    [self.view addSubview:self.moviewPlayerButtonBehinde];
    [self.view bringSubviewToFront:self.videoRangeSlider];
    [self.view bringSubviewToFront:self.playButton];
    
    if(self.viewController.transitionCustomization.interactiveDismiss){
        [self.moviewPlayerButtonBehinde addGestureRecognizer:self.pan];
    }
    
    if (self.playingVideo){
        [self bringMoviePlayerToFront];
    }
    if (self.shouldPlayVideo) {
        self.shouldPlayVideo = NO;
        if (self.pageIndex == self.viewController.pageIndex) {
            [self playButtonPressed];
        }
    }
}

-(void)setupPlayer {
    
    self.videoWasPlayable = NO;
    self.videoPlayerAsset = [AVAsset assetWithURL:self.assetURL];
    self.videoDuration = CMTimeGetSeconds(self.videoPlayerAsset.duration);
    self.videoRangeSlider.durationSeconds = self.videoDuration;
    if (self.endTime == 0) self.endTime = self.videoDuration;
    self.playingVideo = NO;
    self.videoPlayerItem = [[AVPlayerItem alloc] initWithAsset:self.videoPlayerAsset];
    self.videoPlayer = [[AVPlayer alloc] initWithPlayerItem:self.videoPlayerItem];
    self.videoPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];
    [self.videoPlayerLayer setFrame:[UIScreen mainScreen].bounds];
    [self.videoPlayer seekToTime:CMTimeMakeWithSeconds(self.startTime, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    [self.view.layer addSublayer:self.videoPlayerLayer];
    

}

-(void)movieTimerChanged:(NSTimer*)timer {
    Float64 currentTime = CMTimeGetSeconds(self.videoPlayer.currentTime);
    if (currentTime >= self.endTime) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stopTimer];
            [self stopMovie];
            
            self.playingVideo = NO;
            [self.viewController changeToPlayButton];
            self.playButton.hidden = NO;
            [self.view bringSubviewToFront:self.playButton];
            
            [self.videoPlayer seekToTime:CMTimeMakeWithSeconds(self.startTime, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
            [self.videoRangeSlider updateScrubberWithCurrentPlayTime:0];
            [self movieTimerChanged:nil];
        });
    } else {
        [self.videoRangeSlider updateScrubberWithCurrentPlayTime:currentTime];
    }

}

-(void)addPlayButtonToView{
    if (self.playButton) {
        [self.playButton removeFromSuperview];
    }
    self.playButton = [UIButton.alloc initWithFrame:self.viewController.view.bounds];
    self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
    [self.playButton setImage:MHGalleryImage(@"playButton") forState:UIControlStateNormal];
    self.playButton.tag =508;
    self.playButton.hidden =YES;
    [self.playButton addTarget:self action:@selector(playButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playButton];
    
}


-(void)removeAllMoviePlayerViewsAndNotifications{
    
    self.videoDownloaded = NO;
    self.currentTimeMovie = 0;
    [self stopTimer];
    
    
    self.playingVideo = NO;
    
    [self.videoPlayer pause];
    [self stopMovie];
    [self.videoPlayerLayer removeFromSuperlayer];
    self.videoPlayer = nil;
    self.videoPlayerItem = nil;
    self.videoPlayerLayer = nil;
    self.videoPlayerAsset = nil;
    
    [self addPlayButtonToView];
    self.playButton.hidden = NO;
    self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
    [self.moviewPlayerButtonBehinde removeFromSuperview];
    [self.viewController changeToPlayButton];
}


-(void)stopTimer{
    [self.movieTimer invalidate];
    self.movieTimer = nil;
}

-(void)addMoviePlayerToViewWithURL:(NSURL*)URL{
    self.videoWasPlayable = NO;
    self.assetURL = URL;
}

-(void)bringMoviePlayerToFront {
    [self bringSublayerToFront:self.videoPlayerLayer];
    [self.view bringSubviewToFront:self.moviewPlayerButtonBehinde];
    [self.view bringSubviewToFront:self.videoRangeSlider];
}

- (void) bringSublayerToFront:(CALayer *)layer
{
    [layer removeFromSuperlayer];
    [self.view.layer insertSublayer:layer atIndex:[self.view.layer.sublayers count] - 1];
}


-(void)playButtonPressed{
    if (!self.playingVideo) {
        if (!self.videoPlayer) [self setupPlayer];
        [self changeToPlayable];
        [self bringMoviePlayerToFront];
        [self stopMovie];
        
        self.playButton.hidden = YES;
        self.playingVideo = YES;
        
        if (self.videoPlayer) {
            [self.videoPlayer play];
            [self.viewController changeToPauseButton];
            
        }else{
            UIActivityIndicatorView *act = [UIActivityIndicatorView.alloc initWithFrame:self.view.bounds];
            act.tag = 304;
            [self.view addSubview:act];
            [act startAnimating];
            self.shouldPlayVideo = YES;
        }
        if (!self.movieTimer) {
            self.movieTimer = [NSTimer timerWithTimeInterval:0.03f
                                                      target:self
                                                    selector:@selector(movieTimerChanged:)
                                                    userInfo:nil
                                                     repeats:YES];
            [NSRunLoop.currentRunLoop addTimer:self.movieTimer forMode:NSRunLoopCommonModes];
        }
        
    }else{
        [self stopMovie];
    }
}

-(MHGalleryViewMode)currentViewMode{
    if (self.viewController.isHiddingToolBarAndNavigationBar) {
        return MHGalleryViewModeImageViewerNavigationBarHidden;
    }
    return MHGalleryViewModeImageViewerNavigationBarShown;
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
//    self.moviePlayer.backgroundView.backgroundColor = [self.viewController.UICustomization MHGalleryBackgroundColorForViewMode:[self currentViewMode]];
    self.scrollView.backgroundColor = [self.viewController.UICustomization MHGalleryBackgroundColorForViewMode:[self currentViewMode]];
    
    if (self.viewController.isHiddingToolBarAndNavigationBar) {
        self.act.color = [UIColor whiteColor];
        self.videoRangeSlider.alpha = 0;
    }else{
        if (self.videoRangeSlider) {
            if (self.item.galleryType == MHGalleryTypeVideo) {
                if (self.videoWasPlayable && self.videoDuration >0) {
                    self.videoRangeSlider.alpha = 1;
                }
            }
        }
        self.act.color = [UIColor whiteColor];
    }
    if (self.item.galleryType == MHGalleryTypeVideo) {
        
//        if (self.moviePlayer) {
//            [self.videoRangeSlider updateScrubberWithCurrentPlayTime:self.moviePlayer.currentPlaybackTime];
//        }
        if (self.videoPlayer) {
            [self.videoRangeSlider updateScrubberWithCurrentPlayTime:CMTimeGetSeconds(self.videoPlayer.currentTime)];
        }
        
        
        if (self.imageView.image) {
            self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
        }
        
        if(UIApplication.sharedApplication.statusBarOrientation != UIInterfaceOrientationPortrait){
            if (self.view.bounds.size.width < self.view.bounds.size.height) {
                if (self.imageView.image) {
                    self.playButton.frame = CGRectMake(self.view.bounds.size.height/2-36, self.view.bounds.size.width/2-36, 72, 72);
                }
            }
        }
        
        //        self.moviePlayerToolBarTop.frame =CGRectMake(0,64, self.view.frame.size.width, 44);
        //        if (!MHISIPAD) {
        //            if (UIApplication.sharedApplication.statusBarOrientation != UIInterfaceOrientationPortrait) {
        //                self.moviePlayerToolBarTop.frame =CGRectMake(0,52, self.view.frame.size.width, 44);
        //            }
        //        }
    }
}

-(void)changeUIForViewMode:(MHGalleryViewMode)viewMode{
    float alpha =0;
    if (viewMode == MHGalleryViewModeImageViewerNavigationBarShown) {
        alpha =1;
    }
//    self.moviePlayer.backgroundView.backgroundColor = [self.viewController.UICustomization MHGalleryBackgroundColorForViewMode:viewMode];
    self.scrollView.backgroundColor = [self.viewController.UICustomization MHGalleryBackgroundColorForViewMode:viewMode];
    self.viewController.pageViewController.view.backgroundColor = [self.viewController.UICustomization MHGalleryBackgroundColorForViewMode:viewMode];
    
    self.navigationController.navigationBar.alpha =alpha;
    self.viewController.toolbar.alpha =alpha;
    
    self.viewController.descriptionView.alpha =alpha;
    self.viewController.descriptionViewBackground.alpha =alpha;
    MHStatusBar().alpha =alpha;
    self.videoRangeSlider.alpha = alpha;
    
}

-(void)handelImageTap:(UIGestureRecognizer *)gestureRecognizer{
    if (!self.viewController.isHiddingToolBarAndNavigationBar) {
        [UIView animateWithDuration:0.3 animations:^{
            
            if (self.videoRangeSlider) {
                self.videoRangeSlider.alpha =0;
            }
            [self changeUIForViewMode:MHGalleryViewModeImageViewerNavigationBarHidden];
        } completion:^(BOOL finished) {
            
            self.viewController.hiddingToolBarAndNavigationBar = YES;
            self.navigationController.navigationBar.hidden  =YES;
            self.viewController.toolbar.hidden =YES;
        }];
    }else{
        self.navigationController.navigationBar.hidden = NO;
        self.viewController.toolbar.hidden = NO;
        
        [UIView animateWithDuration:0.3 animations:^{
            [self changeUIForViewMode:MHGalleryViewModeImageViewerNavigationBarShown];
            if (self.videoRangeSlider) {
                if (self.item.galleryType == MHGalleryTypeVideo) {
                    self.videoRangeSlider.alpha =1;
                }
            }
        } completion:^(BOOL finished) {
            self.viewController.hiddingToolBarAndNavigationBar = NO;
        }];
        
    }
}

- (void)handleDoubleTap:(UIGestureRecognizer *)gestureRecognizer {
    if (([self.imageView.image isEqual:MHGalleryImage(@"error")]) || (self.item.galleryType == MHGalleryTypeVideo)) {
        return;
    }
    
    if (self.scrollView.zoomScale >1) {
        [self.scrollView setZoomScale:1 animated:YES];
        return;
    }
    [self centerImageView];
    
    CGRect zoomRect;
    CGFloat newZoomScale = (self.scrollView.maximumZoomScale);
    CGPoint touchPoint = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    zoomRect.size.height = [self.imageView frame].size.height / newZoomScale;
    zoomRect.size.width  = [self.imageView frame].size.width  / newZoomScale;
    
    touchPoint = [self.scrollView convertPoint:touchPoint fromView:self.imageView];
    
    zoomRect.origin.x    = touchPoint.x - ((zoomRect.size.width / 2.0));
    zoomRect.origin.y    = touchPoint.y - ((zoomRect.size.height / 2.0));
    
    [self.scrollView zoomToRect:zoomRect animated:YES];
}


-(UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView{
    return [scrollView.subviews firstObject];
}

- (void)prepareToResize{
    CGPoint boundsCenter = CGPointMake(CGRectGetMidX(self.scrollView.bounds), CGRectGetMidY(self.scrollView.bounds));
    self.pointToCenterAfterResize = [self.scrollView convertPoint:boundsCenter toView:self.imageView];
    self.scaleToRestoreAfterResize = self.scrollView.zoomScale;
}
- (void)recoverFromResizing{
    self.scrollView.zoomScale = MIN(self.scrollView.maximumZoomScale, MAX(self.scrollView.minimumZoomScale, _scaleToRestoreAfterResize));
    CGPoint boundsCenter = [self.scrollView convertPoint:self.pointToCenterAfterResize fromView:self.imageView];
    CGPoint offset = CGPointMake(boundsCenter.x - self.scrollView.bounds.size.width / 2.0,
                                 boundsCenter.y - self.scrollView.bounds.size.height / 2.0);
    CGPoint maxOffset = [self maximumContentOffset];
    CGPoint minOffset = [self minimumContentOffset];
    offset.x = MAX(minOffset.x, MIN(maxOffset.x, offset.x));
    offset.y = MAX(minOffset.y, MIN(maxOffset.y, offset.y));
    self.scrollView.contentOffset = offset;
}



- (CGPoint)maximumContentOffset{
    CGSize contentSize = self.scrollView.contentSize;
    CGSize boundsSize = self.scrollView.bounds.size;
    return CGPointMake(contentSize.width - boundsSize.width, contentSize.height - boundsSize.height);
}

- (CGPoint)minimumContentOffset{
    return CGPointZero;
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                        duration:(NSTimeInterval)duration{
    self.playButton.frame = CGRectMake(self.viewController.view.frame.size.width/2-36, self.viewController.view.frame.size.height/2-36, 72, 72);
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width*self.scrollView.zoomScale, self.view.bounds.size.height*self.scrollView.zoomScale);
    self.imageView.frame =CGRectMake(0,0 , self.scrollView.contentSize.width,self.scrollView.contentSize.height);
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    [self prepareToResize];
    [self recoverFromResizing];
    [self centerImageView];
}

-(void)centerImageView{
    if(self.imageView.image){
        CGRect frame  = AVMakeRectWithAspectRatioInsideRect(self.imageView.image.size,CGRectMake(0, 0, self.scrollView.contentSize.width, self.scrollView.contentSize.height));
        
        if (self.scrollView.contentSize.width==0 && self.scrollView.contentSize.height==0) {
            frame = AVMakeRectWithAspectRatioInsideRect(self.imageView.image.size,self.scrollView.bounds);
        }
        
        CGSize boundsSize = self.scrollView.bounds.size;
        
        CGRect frameToCenter = CGRectMake(0,0 , frame.size.width, frame.size.height);
        
        if (frameToCenter.size.width < boundsSize.width){
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2;
        }else{
            frameToCenter.origin.x = 0;
        }if (frameToCenter.size.height < boundsSize.height){
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2;
        }else{
            frameToCenter.origin.y = 0;
        }
        self.imageView.frame = frameToCenter;
    }
}
-(void)scrollViewDidZoom:(UIScrollView *)scrollView{
    [self centerImageView];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
}

#pragma mark - SAVideoRangeSliderDelegate

-(void)videoRange:(SAVideoRangeSlider *)videoRange didChangeStartTime:(CGFloat)startTime endTime:(CGFloat)endTime {
    self.startTime = startTime;
    self.endTime = endTime;
    [self seekToTime:startTime];
    [self updateTrimButton];
}

-(void)videoRange:(SAVideoRangeSlider *)videoRange didChangeStartTime:(CGFloat)startTime  {
    self.startTime = startTime;
    [self seekToTime:startTime];
    [self updateTrimButton];
}

-(void)videoRange:(SAVideoRangeSlider *)videoRange didChangeEndTime:(CGFloat)endTime {
    self.endTime = endTime;
    [self updateTrimButton];
}

-(void)updateTrimButton {
    if (self.startTime != 0 || self.endTime != self.videoDuration) {
        self.viewController.trimBarButton.enabled = YES;
    } else {
        self.viewController.trimBarButton.enabled = NO;
    }
}

-(void)videoRange:(SAVideoRangeSlider *)videoRange didChangeScrubberTimePosition:(CGFloat)scrubberTimePostion {
    [self seekToTime:scrubberTimePostion];
}

-(void)seekToTime:(CGFloat)time {
    if (self.videoPlayer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stopMovie];
            [self.videoPlayer seekToTime:CMTimeMakeWithSeconds(time, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        });
    }
}
@end

