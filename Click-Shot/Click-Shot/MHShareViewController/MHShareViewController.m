//
//  MHShareViewController.m
//  MHVideoPhotoGallery
//
//  Created by Mario Hahn on 10.01.14.
//  Copyright (c) 2014 Mario Hahn. All rights reserved.
//

#import "MHShareViewController.h"
#import "MHMediaPreviewCollectionViewCell.h"
#import "MHGallery.h"
#import "UIImageView+WebCache.h"
#import "MHTransitionShowShareView.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "MHGallerySharedManagerPrivate.h"
#import "SDImageCache.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "MHGallery.h"
#import "MBProgressHUD.h"


@implementation MHImageURL

- (id)initWithURL:(NSString*)URL
            image:(UIImage*)image{
    self = [super init];
    if (!self)
        return nil;
    self.URL = URL;
    self.image = image;
    return self;
}

@end

@implementation MHDownloadView

-(id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;
    
    self.backgroundColor = UIColor.clearColor;
    self.blurBackgroundToolbar = [UIToolbar.alloc initWithFrame:self.bounds];
    self.blurBackgroundToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.blurBackgroundToolbar];
    
    self.activityIndicatorView = [UIActivityIndicatorView.alloc initWithFrame:CGRectMake(0, -35, self.blurBackgroundToolbar.frame.size.width, self.blurBackgroundToolbar.frame.size.height-35)];
    self.activityIndicatorView.color = UIColor.blackColor;
    self.activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.activityIndicatorView startAnimating];
    [self.blurBackgroundToolbar addSubview:self.activityIndicatorView];
    
    self.downloadDataLabel = [UILabel.alloc initWithFrame:self.blurBackgroundToolbar.bounds];
    self.downloadDataLabel.textAlignment = NSTextAlignmentCenter;
    self.downloadDataLabel.numberOfLines = MAXFLOAT;
    self.downloadDataLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.blurBackgroundToolbar addSubview:self.downloadDataLabel];
    
    self.cancelDownloadButton = [UIButton.alloc initWithFrame:CGRectMake(0, self.blurBackgroundToolbar.frame.size.height-50, self.frame.size.width, 44)];
    
    self.cancelDownloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleLeftMargin;
    [self.cancelDownloadButton setTitle:MHGalleryLocalizedString(@"shareview.download.cancel") forState:UIControlStateNormal];
    [self.cancelDownloadButton setTitleColor:[UIColor colorWithRed:1 green:0.18 blue:0.33 alpha:1] forState:UIControlStateNormal];
    self.cancelDownloadButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:20];
    [self.cancelDownloadButton addTarget:self action:@selector(cancelDownload) forControlEvents:UIControlEventTouchUpInside];
    [self.blurBackgroundToolbar addSubview:self.cancelDownloadButton];
    self.cancelDownloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:self.cancelDownloadButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.blurBackgroundToolbar
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1
                                                               constant:-5];
    
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:self.cancelDownloadButton
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.blurBackgroundToolbar
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1.f
                                                                constant:0.f];
    
    [self.blurBackgroundToolbar addConstraint:bottom];
    [self.blurBackgroundToolbar addConstraint:centerX];
    
    return self;
}

-(void)cancelDownload{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cancelCallbackDownloadData(YES);
    });
}

-(void)attributedStringForDownloadLabelWithDownloadedDataNumber:(NSNumber*)downloaded maxNumber:(NSNumber*)maxNumber{
    
    NSString *downloadDataString = MHGalleryLocalizedString(@"shareview.download");
    NSString *numberTitle = [NSString stringWithFormat:MHGalleryLocalizedString(@"imagedetail.title.current"),downloaded,maxNumber];
    
    NSMutableAttributedString *attributedString = [NSMutableAttributedString.alloc initWithString:[NSString stringWithFormat:@"%@%@",downloadDataString,numberTitle]];
    [attributedString setAttributes:@{NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:30]}
                              range:NSMakeRange(0, downloadDataString.length)];
    
    [attributedString setAttributes:@{NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Bold" size:20]}
                              range:NSMakeRange(downloadDataString.length, numberTitle.length)];
    
    self.downloadDataLabel.attributedText = attributedString;
}


@end


@implementation MHShareItem

- (id)initWithImageName:(NSString*)imageName
                  title:(NSString*)title
   withMaxNumberOfItems:(NSInteger)maxNumberOfItems
           withSelector:(NSString*)selectorName
       onViewController:(id)onViewController{
    self = [super init];
    if (!self)
        return nil;
    self.imageName = imageName;
    self.title = title;
    self.maxNumberOfItems = maxNumberOfItems;
    self.selectorName = selectorName;
    self.onViewController = onViewController;
    return self;
}
@end

@implementation MHCollectionViewTableViewCell

-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) return nil;
    
    UICollectionViewFlowLayout *layout = UICollectionViewFlowLayout.new;
    layout.sectionInset = UIEdgeInsetsMake(0, 25, 0, 25);
    layout.itemSize = CGSizeMake(270, 210);
    layout.minimumLineSpacing = 15;
    layout.minimumInteritemSpacing = 15;
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    
    
    _collectionView = [[UICollectionView alloc] initWithFrame:self.bounds
                                         collectionViewLayout:layout];
    
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerClass:MHMediaPreviewCollectionViewCell.class
            forCellWithReuseIdentifier:NSStringFromClass(MHMediaPreviewCollectionViewCell.class)];
    
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:self.collectionView];
    return self;
}

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        _collectionView = [UICollectionView.alloc initWithFrame:self.bounds];
        self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:self.collectionView];
    }
    return self;
}
-(void)prepareForReuse{
    
}

@end


@implementation MHShareCell

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        _thumbnailImageView = [UIImageView.alloc initWithFrame:CGRectMake(self.bounds.size.width/2-30, 1, 60, 60)];
        self.thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.thumbnailImageView.clipsToBounds = YES;
        [self.contentView addSubview:self.thumbnailImageView];
        
        _descriptionLabel = [UILabel.alloc initWithFrame:CGRectMake(0, self.bounds.size.height-40, self.bounds.size.width, 40)];
        self.descriptionLabel.backgroundColor = UIColor.clearColor;
        self.descriptionLabel.textColor = UIColor.blackColor;
        self.descriptionLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:13];
        self.descriptionLabel.numberOfLines = 2;
        [self.contentView addSubview:self.descriptionLabel];
    }
    return self;
}
@end


@interface MHShareViewController ()
//@property (nonatomic,strong) MHDownloadView *downloadView;
//@property (nonatomic,strong) NSMutableArray *shareDataSource;
//@property (nonatomic,strong) NSArray *shareDataSourceStart;
@property (nonatomic,strong) NSMutableArray *selectedRows;
@property (nonatomic)        CGFloat startPointScroll;
//@property (nonatomic,strong) MHShareItem *saveObject;
//@property (nonatomic,strong) MHShareItem *mailObject;
//@property (nonatomic,strong) MHShareItem *messageObject;
//@property (nonatomic,strong) MHShareItem *twitterObject;
//@property (nonatomic,strong) MHShareItem *faceBookObject;
@property (nonatomic,getter = isShowingShareViewInLandscapeMode) BOOL showingShareViewInLandscapeMode;
@property (nonatomic)        NSInteger saveCounter;
@property (nonatomic,strong) NSMutableArray *dataDownload;
@property (nonatomic,strong) NSMutableArray *sessions;
@property (nonatomic,strong) UICollectionView *selectedRowsCollectionView;

@end

@implementation MHShareViewController

-(void)initShareObjects{
    
    
//    self.saveObject = [MHShareItem.alloc initWithImageName:@"activtyMH"
//                                                     title:MHGalleryLocalizedString(@"shareview.save.cameraRoll")
//                                      withMaxNumberOfItems:MAXFLOAT
//                                              withSelector:@"saveImages:"
//                                          onViewController:self];
//    
//    self.mailObject = [MHShareItem.alloc initWithImageName:@"mailMH"
//                                                     title:MHGalleryLocalizedString(@"shareview.mail")
//                                      withMaxNumberOfItems:10
//                                              withSelector:@"mailImages:"
//                                          onViewController:self];
//    
//    self.messageObject = [MHShareItem.alloc initWithImageName:@"messageMH"
//                                                        title:MHGalleryLocalizedString(@"shareview.message")
//                                         withMaxNumberOfItems:15
//                                                 withSelector:@"smsImages:"
//                                             onViewController:self];
//    
//    self.twitterObject = [MHShareItem.alloc initWithImageName:@"twitterMH"
//                                                        title:@"Twitter"
//                                         withMaxNumberOfItems:2
//                                                 withSelector:@"twShareImages:"
//                                             onViewController:self] ;
//    
//    self.faceBookObject = [MHShareItem.alloc initWithImageName:@"facebookMH"
//                                                         title:@"Facebook"
//                                          withMaxNumberOfItems:10
//                                                  withSelector:@"fbShareImages:"
//                                              onViewController:self];
}

-(void)cancelPressed{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.delegate = self;
    [self.collectionView.delegate scrollViewDidScroll:self.collectionView];
    
}

-(void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView{
    self.startPointScroll = scrollView.contentOffset.x;
}

-(void) scrollViewWillEndDragging:(UIScrollView*)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint*)targetContentOffset {
    
    NSArray *visibleCells = [self sortObjectsWithFrame:self.collectionView.visibleCells];
    MHMediaPreviewCollectionViewCell *cell;
    if ((self.startPointScroll <  targetContentOffset->x) && (visibleCells.count >1)) {
        cell = visibleCells[1];
    }else{
        cell = visibleCells.firstObject;
    }
    if (MHISIPAD) {
        *targetContentOffset = CGPointMake((cell.tag * 330+20), targetContentOffset->y);
    }else{
        *targetContentOffset = CGPointMake((cell.tag * 250+20), targetContentOffset->y);
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.navigationController.delegate == self) {
        self.navigationController.delegate = nil;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    return MHTransitionShowShareView.new;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.selectedRows = NSMutableArray.new;
    self.view.backgroundColor = UIColor.whiteColor;
    self.navigationItem.hidesBackButton =YES;
    
    UIBarButtonItem *cancelBarButton = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                   target:self
                                                                                   action:@selector(cancelPressed)];
    
    self.navigationItem.leftBarButtonItem = cancelBarButton;
    
    UICollectionViewFlowLayout *flowLayout = UICollectionViewFlowLayout.new;
    flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    if (MHISIPAD) {
        flowLayout.itemSize = CGSizeMake(320, self.view.frame.size.height-330);
    }else{
        flowLayout.itemSize = CGSizeMake(240, self.view.frame.size.height-330);
    }
    flowLayout.minimumInteritemSpacing =20;
    flowLayout.sectionInset = UIEdgeInsetsMake(0, 60, 0, 0);
    self.collectionView = [UICollectionView.alloc initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-240)
                                           collectionViewLayout:flowLayout];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.allowsMultipleSelection=YES;
    self.collectionView.contentInset = UIEdgeInsetsZero;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.backgroundColor = UIColor.whiteColor;
    [self.collectionView registerClass:MHMediaPreviewCollectionViewCell.class
            forCellWithReuseIdentifier:NSStringFromClass(MHMediaPreviewCollectionViewCell.class)];
    
    self.collectionView.decelerationRate = UIScrollViewDecelerationRateNormal;
    [self.view addSubview:self.collectionView];
    
    
    [self.selectedRows addObject:[NSIndexPath indexPathForRow:self.pageIndex inSection:0]];
    
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:self.pageIndex inSection:0]
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:NO];
    
    self.gradientView= [UIView.alloc initWithFrame:CGRectMake(0, self.view.frame.size.height-240, self.view.frame.size.width,240)];
    
    self.toolbar = [UIToolbar.alloc initWithFrame:self.gradientView.frame];
    [self.view addSubview:self.toolbar];
    
    CAGradientLayer *gradient = CAGradientLayer.layer;
    gradient.frame = self.gradientView.bounds;
    gradient.colors = @[(id)[UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1].CGColor,
                        (id)[UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1].CGColor];
    
    [self.gradientView.layer insertSublayer:gradient atIndex:0];
    [self.view addSubview:self.gradientView];
    
    self.tableViewShare = [UITableView.alloc initWithFrame:CGRectMake(0, self.view.frame.size.height-230, self.view.frame.size.width, 240)];
    self.tableViewShare.delegate = self;
    self.tableViewShare.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableViewShare.dataSource = self;
    self.tableViewShare.backgroundColor = UIColor.clearColor;
    self.tableViewShare.scrollEnabled = NO;
    [self.tableViewShare registerClass:MHCollectionViewTableViewCell.class
                forCellReuseIdentifier:NSStringFromClass(MHCollectionViewTableViewCell.class)];
    [self.view addSubview:self.tableViewShare];
    
    UIView *sep = [UIView.alloc initWithFrame:CGRectMake(0,115, self.view.frame.size.width, 1)];
    sep.backgroundColor = [UIColor colorWithRed:0.63 green:0.63 blue:0.63 alpha:1];
    sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.tableViewShare addSubview:sep];
    
    [self initShareObjects];
    [self updateTitle];
    
//    NSMutableArray *shareObjectAvailable = [NSMutableArray arrayWithArray:@[self.messageObject,
//                                                                            self.mailObject,
//                                                                            self.twitterObject,
//                                                                            self.faceBookObject]];
//    
//    
//    if(![SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]){
//        [shareObjectAvailable removeObject:self.faceBookObject];
//    }
//    if(![SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]){
//        [shareObjectAvailable removeObject:self.twitterObject];
//    }
//    
//    self.shareDataSource = [NSMutableArray arrayWithArray:@[shareObjectAvailable,
//                                                            @[[self saveObject]]
//                                                            ]];
    
//    self.shareDataSourceStart = [NSArray arrayWithArray:self.shareDataSource];
    if(UIApplication.sharedApplication.statusBarOrientation != UIInterfaceOrientationPortrait){
        self.navigationItem.rightBarButtonItem = [self nextBarButtonItem];
    }
    self.startPointScroll = self.collectionView.contentOffset.x;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 119;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 1;
}
-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section == 0) {
        NSString *cellIdentifier = nil;
        cellIdentifier = @"MHCollectionViewTableViewCell";
        
        MHCollectionViewTableViewCell *cell = (MHCollectionViewTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        cell.backgroundColor = [UIColor clearColor];
        UICollectionViewFlowLayout *layout = UICollectionViewFlowLayout.new;
        layout.sectionInset = UIEdgeInsetsMake(0, 10, 0, 10);
        layout.itemSize = CGSizeMake(70, 100);
        layout.minimumLineSpacing = 10;
        layout.minimumInteritemSpacing = 10;
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        cell.collectionView.collectionViewLayout = layout;
        
        [cell.collectionView registerClass:MHShareCell.class
                forCellWithReuseIdentifier:NSStringFromClass(MHShareCell.class)];
        
        cell.collectionView.showsHorizontalScrollIndicator = NO;
        cell.collectionView.delegate = self;
        cell.collectionView.dataSource = self;
        cell.collectionView.backgroundColor = UIColor.clearColor;
        cell.collectionView.tag = indexPath.section;
        [cell.collectionView reloadData];
        self.selectedRowsCollectionView = cell.collectionView;
        return cell;
    } else {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"mergeVideos"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UIButton *mergeVideosButton = [UIButton buttonWithType:UIButtonTypeCustom];
        mergeVideosButton.frame = CGRectMake(0, 0, 200, 60);
        [mergeVideosButton setImage:[UIImage imageNamed:@"mergeVideos"] forState:UIControlStateNormal];
        mergeVideosButton.center = CGPointMake(cell.center.x, tableView.frame.size.height/4);
        [mergeVideosButton addTarget:self
                          action:@selector(mergeSelectedVideos)
                forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:mergeVideosButton];

        return cell;
    }
    
}

-(void)mergeSelectedVideos {
    if (self.selectedRows.count < 2) return;
//    NSLog(@"MERGE");
    AVMutableComposition *composition = [AVMutableComposition composition];
    CMTime insertAtTime = CMTimeMake(0, 600);
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                     preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                     preferredTrackID:kCMPersistentTrackID_Invalid];
    NSIndexPath *indexPath = [self.selectedRows objectAtIndex:0];
    MHGalleryItem *videoItem = [self itemForIndex:indexPath.row];
    AVURLAsset *firstAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:videoItem.URLString] options:nil];
    AVAssetTrack *firstVideoTrackSegment = [[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    CGAffineTransform firstVideoTransform = firstVideoTrackSegment.preferredTransform;
    CGSize renderSize = firstVideoTrackSegment.naturalSize;
    UIImageOrientation firstVideoOrientation = [self orientationForTransform:firstVideoTransform];
    BOOL renderInPortrait  = NO;
    if (firstVideoOrientation == UIImageOrientationLeft || firstVideoOrientation == UIImageOrientationRight) {
        renderInPortrait = YES;
        if (renderSize.width > renderSize.height) renderSize = CGSizeMake(fabsf(renderSize.height), fabsf(renderSize.width));
    }

    AVMutableVideoCompositionLayerInstruction *videoTrackInstruction = [AVMutableVideoCompositionLayerInstruction
                                                                        videoCompositionLayerInstructionWithAssetTrack:videoTrack];

    for (int i = 0; i < [self.selectedRows count]; i++) {
        NSIndexPath *indexPath = [self.selectedRows objectAtIndex:i];
        MHGalleryItem *videoItem = [self itemForIndex:indexPath.row];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:videoItem.URLString] options:nil];
        AVAssetTrack *videoTrackSegment = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        [videoTrack insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 600), asset.duration)
                            ofTrack:videoTrackSegment atTime:insertAtTime error:nil];
        [audioTrack insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 600), asset.duration)
                            ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:insertAtTime error:nil];
        CGAffineTransform trackPreferredTransform = videoTrackSegment.preferredTransform;
        UIImageOrientation trackOrientation = [self orientationForTransform:trackPreferredTransform];

        if (trackOrientation == UIImageOrientationRight) {  // Normal Portrait - 90 deg CW
            if (renderInPortrait) {
                [videoTrackInstruction setTransform:CGAffineTransformConcat(CGAffineTransformMakeRotation(M_PI_2), CGAffineTransformMakeTranslation(renderSize.width, 0)) atTime:insertAtTime];
            } else {
                //HERE
                CGSize videoSize = videoTrackSegment.naturalSize;
                if (videoSize.width > videoSize.height) videoSize = CGSizeMake(videoSize.height, videoSize.width);
                float scale = renderSize.height/videoSize.height;
                CGAffineTransform scaleTranslate = CGAffineTransformTranslate(CGAffineTransformMakeScale(scale, scale),2243,0);
                [videoTrackInstruction setTransform:CGAffineTransformConcat(CGAffineTransformMakeRotation(M_PI_2),scaleTranslate) atTime:insertAtTime];
            }
        } else if (trackOrientation == UIImageOrientationLeft) { // Upside Down Portrait - 90 deg CCW
            if (renderInPortrait) {
                [videoTrackInstruction setTransform:CGAffineTransformConcat(CGAffineTransformMakeRotation(-M_PI_2), CGAffineTransformMakeTranslation(0, renderSize.height)) atTime:insertAtTime];
            } else {
                // HERE
                CGSize videoSize = videoTrackSegment.naturalSize;
                if (videoSize.width > videoSize.height) videoSize = CGSizeMake(videoSize.height, videoSize.width);
                float scale = renderSize.height/videoSize.height;
                CGAffineTransform scaleTranslate = CGAffineTransformTranslate(CGAffineTransformMakeScale(scale, scale),1163,renderSize.width);
                [videoTrackInstruction setTransform:CGAffineTransformConcat(CGAffineTransformMakeRotation(-M_PI_2),scaleTranslate) atTime:insertAtTime];
            }
        } else if (trackOrientation == UIImageOrientationDown) { // upside down landscape - 180 deg rotation
            if (renderInPortrait) {
                CGSize videoSize = videoTrackSegment.naturalSize;
                if (videoSize.width < videoSize.height) videoSize = CGSizeMake(videoSize.height, videoSize.width);
                float scale = renderSize.width/videoSize.width;
                CGAffineTransform scaleTranslate = CGAffineTransformTranslate(CGAffineTransformMakeScale(scale, scale),renderSize.height,renderSize.width*2);
                
                [videoTrackInstruction setTransform:CGAffineTransformConcat(CGAffineTransformMakeRotation(-M_PI),scaleTranslate) atTime:insertAtTime];
            } else {
                //HERE
                [videoTrackInstruction setTransform:CGAffineTransformConcat(CGAffineTransformMakeRotation(M_PI), CGAffineTransformMakeTranslation(1920, 1080))  atTime:insertAtTime];
            }
        } else if (trackOrientation == UIImageOrientationUp) { // landscape - 90 deg CCW from portrait
            if (renderInPortrait) {
                CGSize videoSize = videoTrackSegment.naturalSize;
                if (videoSize.width < videoSize.height) videoSize = CGSizeMake(videoSize.height, videoSize.width);
                float scale = renderSize.width/videoSize.width;
                float move = (renderSize.height/2)-((videoSize.height*scale)/2);
                [videoTrackInstruction setTransform:CGAffineTransformConcat(CGAffineTransformMakeScale(scale, scale), CGAffineTransformMakeTranslation(0, move)) atTime:insertAtTime];
            } else {
                if (firstVideoOrientation == UIImageOrientationUp) {
                    // nothing needed
                } else {
                    [videoTrackInstruction setTransform:videoTrackSegment.preferredTransform atTime:insertAtTime];
                }
            }
        }
        
//        NSLog(@"%@ - %@", NSStringFromCGSize(videoTrackSegment.naturalSize), NSStringFromCGAffineTransform(trackPreferredTransform));
        insertAtTime = CMTimeAdd(insertAtTime, asset.duration);
    }

    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.layerInstructions = @[videoTrackInstruction];
    instruction.timeRange = videoTrack.timeRange;
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition  videoComposition];
    videoComposition.instructions = @[instruction];
    videoComposition.frameDuration = CMTimeMake(1, 30);
    videoComposition.renderScale = 1.0;
    videoComposition.renderSize = renderSize;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"mergeVideo-%d.mov",arc4random() % 1000]];
    NSURL *url = [NSURL fileURLWithPath:myPathDocs];
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition
                                                                      presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = url;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    exporter.videoComposition = videoComposition;
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"done exporting!");
            [self exportDidFinish:exporter];
        });
    }];
    
}

-(UIImageOrientation)orientationForTransform:(CGAffineTransform)transform {
    if (transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0)  {
        return UIImageOrientationRight;
    } else if (transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0)  {
        return UIImageOrientationLeft;
    } else if (transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0) {
        return  UIImageOrientationDown;
    } else  {
        return UIImageOrientationUp;
    }
}

-(void)exportDidFinish:(AVAssetExportSession *)exportSession {
    ALAssetsLibrary* library = [ALAssetsLibrary new];
    [library writeVideoAtPathToSavedPhotosAlbum:[exportSession outputURL]
                                completionBlock:^(NSURL *assetURL, NSError *error){
                                    if (error) NSLog(@"%@", error);
                                    NSError *removeError =nil;
                                    [NSFileManager.defaultManager removeItemAtURL:[exportSession outputURL] error:&removeError];
                                    if (removeError) NSLog(@"%@", removeError);
                                    NSLog(@"done saving to library!");
                                    [MBProgressHUD hideHUDForView:self.view animated:YES];
//                                    [self cancelPressed];
                                    [self.gallerViewController dismissViewControllerAnimated:YES dismissImageView:nil completion:nil];
                                }];
}

-(void)updateTitle{
    NSString *localizedTitle =  MHGalleryLocalizedString(@"shareview.title.select.singular");
    self.title = [NSString stringWithFormat:localizedTitle, @(self.selectedRows.count)];
    if (self.selectedRows.count >1) {
        NSString *localizedTitle =  MHGalleryLocalizedString(@"shareview.title.select.plural");
        self.title = [NSString stringWithFormat:localizedTitle, @(self.selectedRows.count)];
    }
}

-(MHGalleryController*)gallerViewController{
    if ([self.navigationController isKindOfClass:[MHGalleryController class]]) {
        return  (MHGalleryController*)self.navigationController;
    }
    return nil;
}


-(MHGalleryItem*)itemForIndex:(NSInteger)index{
    return  [self.galleryItems objectAtIndex:index];
    //    return [self.gallerViewController.dataSource itemForIndex:index];
}
-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if ([collectionView isEqual:self.collectionView]) {
        return [self.galleryItems count];
//        return [self.gallerViewController.dataSource numberOfItemsInGallery:self.gallerViewController];
    }
    return [self.selectedRows count];
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell =nil;
    if ([collectionView isEqual:self.collectionView]) {
        NSString *cellIdentifier = NSStringFromClass(MHMediaPreviewCollectionViewCell.class);
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
        [self makeOverViewDetailCell:(MHMediaPreviewCollectionViewCell*)cell atIndexPath:indexPath];
    }else{
        NSString *cellIdentifier = NSStringFromClass(MHMediaPreviewCollectionViewCell.class);
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
        [self makeSelectedCell:(MHMediaPreviewCollectionViewCell*)cell atIndexPath:indexPath];
    }
    return cell;
}
-(void)makeMHShareCell:(MHShareCell*)cell atIndexPath:(NSIndexPath*)indexPath{
    
//    MHShareItem *shareItem = self.shareDataSource[indexPath.section][indexPath.row];
//    
//    cell.thumbnailImageView.image = [UIImage imageNamed:shareItem.imageName];
//    cell.thumbnailImageView.contentMode =UIViewContentModeCenter;
//    if (indexPath.section ==0) {
//        cell.thumbnailImageView.layer.cornerRadius =15;
//    }
//    cell.descriptionLabel.adjustsFontSizeToFitWidth =YES;
//    cell.thumbnailImageView.clipsToBounds = YES;
//    
//    cell.descriptionLabel.textAlignment = NSTextAlignmentCenter;
//    cell.descriptionLabel.text = shareItem.title;
//    cell.backgroundColor = UIColor.clearColor;
}

-(void)makeOverViewDetailCell:(MHMediaPreviewCollectionViewCell*)cell atIndexPath:(NSIndexPath*)indexPath{
    
    MHGalleryItem *item = [self itemForIndex:indexPath.row];
    
    cell.videoDurationLength.text = @"";
    cell.videoIcon.hidden = YES;
    cell.videoGradient.hidden = YES;
    cell.thumbnail.image = nil;
    cell.galleryItem = item;
    cell.thumbnail.backgroundColor = [UIColor colorWithWhite:0 alpha:0.1];
    cell.thumbnail.contentMode = UIViewContentModeScaleAspectFill;
    cell.selectionImageView.hidden = NO;
    
    cell.selectionImageView.layer.borderWidth = 1;
    cell.selectionImageView.layer.cornerRadius = 11;
    cell.selectionImageView.layer.borderColor = UIColor.whiteColor.CGColor;
    cell.selectionImageView.image =  nil;
    cell.selectionImageView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.45];
    
    if ([self.selectedRows containsObject:indexPath]) {
        cell.selectionImageView.backgroundColor = UIColor.whiteColor;
        cell.selectionImageView.tintColor = [UIColor colorWithRed:0 green:0.46 blue:1 alpha:1];
        cell.selectionImageView.image =  MHTemplateImage(@"EditControlSelected");
    }
    cell.tag = indexPath.row;
    
}
-(void)makeSelectedCell:(MHMediaPreviewCollectionViewCell*)cell atIndexPath:(NSIndexPath*)indexPath{
    
    indexPath = [self.selectedRows objectAtIndex:indexPath.row];
    MHGalleryItem *item = [self itemForIndex:indexPath.row];
    
    cell.videoDurationLength.text = @"";
    cell.videoIcon.hidden = YES;
    cell.videoGradient.hidden = YES;
    cell.thumbnail.image = nil;
    cell.galleryItem = item;
    cell.thumbnail.backgroundColor = [UIColor colorWithWhite:0 alpha:0.1];
    cell.thumbnail.contentMode = UIViewContentModeScaleAspectFill;
    cell.selectionImageView.hidden = YES;

    cell.tag = indexPath.row;
    
}
-(NSArray*)sortObjectsWithFrame:(NSArray*)objects{
    NSComparator comparatorBlock = ^(id obj1, id obj2) {
        if ([obj1 frame].origin.x > [obj2 frame].origin.x) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        if ([obj1 frame].origin.x < [obj2 frame].origin.x) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    };
    NSMutableArray *fieldsSort = [NSMutableArray.alloc initWithArray:objects];
    [fieldsSort sortUsingComparator:comparatorBlock];
    return [NSArray arrayWithArray:fieldsSort];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    if ([scrollView isEqual:self.collectionView]) {
        NSArray *visibleCells = [self sortObjectsWithFrame:self.collectionView.visibleCells];
        for (MHMediaPreviewCollectionViewCell *cellOther in visibleCells) {
            if (!cellOther.videoIcon.isHidden){
                cellOther.selectionImageView.frame = CGRectMake(cellOther.bounds.size.width-30,  cellOther.bounds.size.height-50, 22, 22);
            }else{
                cellOther.selectionImageView.frame = CGRectMake(cellOther.bounds.size.width-30,  cellOther.bounds.size.height-30, 22, 22);
            }
        }
        
        MHMediaPreviewCollectionViewCell *cell = [visibleCells lastObject];
        CGRect rect = [self.view convertRect:cell.thumbnail.frame
                                    fromView:cell.thumbnail.superview];
        
        NSInteger valueToAddYForVideoType =0;
        if (!cell.videoIcon.isHidden){
            valueToAddYForVideoType+=20;
        }
        
        cell.selectionImageView.frame = CGRectMake(self.view.frame.size.width-rect.origin.x-30, cell.bounds.size.height-(30+valueToAddYForVideoType), 22, 22);
        if (cell.selectionImageView.frame.origin.x < 5) {
            cell.selectionImageView.frame = CGRectMake(5,  cell.bounds.size.height-(30+valueToAddYForVideoType), 22, 22);
        }
        
        if (cell.selectionImageView.frame.origin.x > cell.bounds.size.width-30 ) {
            cell.selectionImageView.frame = CGRectMake(cell.bounds.size.width-30,  cell.bounds.size.height-(30+valueToAddYForVideoType), 22, 22);
        }
    }
}

//-(void)updateCollectionView{

//    NSInteger index =0;
//    NSArray *storedData = [NSArray arrayWithArray:self.shareDataSource];
//    
//    self.shareDataSource = NSMutableArray.new;
//    
//    for (NSArray *array in self.shareDataSourceStart) {
//        NSMutableArray *newObjects  = NSMutableArray.new;
//        
//        for (MHShareItem *item in array) {
//            if (self.selectedRows.count <= item.maxNumberOfItems) {
//                if (![storedData[index] containsObject:item]) {
//                    [newObjects addObject:item];
//                }else{
//                    [newObjects addObject:item];
//                }
//            }
//        }
//        [self.shareDataSource addObject:newObjects];
//        MHCollectionViewTableViewCell *cell = (MHCollectionViewTableViewCell*)[self.tableViewShare cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:index]];
//        [cell.collectionView reloadData];
//        index++;
//    }
//}
//-(void)presentSLComposeForServiceType:(NSString*)serviceType{
//    
//    __weak typeof(self) weakSelf = self;
//    
//    [self getAllImagesForSelectedRows:^(NSArray *images){
//        SLComposeViewController *shareconntroller = [SLComposeViewController composeViewControllerForServiceType:serviceType];
//        SLComposeViewControllerCompletionHandler completionHandler=^(SLComposeViewControllerResult result){
//            
//            [shareconntroller dismissViewControllerAnimated:YES
//                                                 completion:^{
//                                                     [weakSelf cancelPressed];
//                                                 }];
//        };
//        NSString *videoURLS = NSString.new;
//        for (MHImageURL *dataURL in images) {
//            if ([dataURL.image isKindOfClass:UIImage.class] && !dataURL.image.images) {
//                [shareconntroller addImage:dataURL.image];
//            }else{
//                videoURLS = [videoURLS stringByAppendingString:[NSString stringWithFormat: @"%@ \n",dataURL.URL]];
//            }
//        }
//        [shareconntroller setInitialText:videoURLS];
//        [shareconntroller setCompletionHandler:completionHandler];
//        [self presentViewController:shareconntroller
//                           animated:YES
//                         completion:nil];
//    } saveDataToCameraRoll:NO];
//}
//-(void)twShareImages:(NSArray*)object{
//    [self presentSLComposeForServiceType:SLServiceTypeTwitter];
//}
//
//-(void)fbShareImages:(NSArray*)object{
//    [self presentSLComposeForServiceType:SLServiceTypeFacebook];
//}

//-(void)smsImages:(NSArray*)object{
//    [self getAllImagesForSelectedRows:^(NSArray *images) {
//        MFMessageComposeViewController *picker = MFMessageComposeViewController.new;
//        picker.messageComposeDelegate = self;
//        NSString *videoURLS = NSString.new;
//        
//        for (MHImageURL *dataURL in images) {
//            if ([dataURL.image isKindOfClass:UIImage.class]) {
//                UIImage *image = dataURL.image;
//                if (image.images) {
//                    [picker addAttachmentData:[NSData dataWithContentsOfFile:[SDImageCache.sharedImageCache defaultCachePathForKey:dataURL.URL]]
//                               typeIdentifier:(__bridge NSString *)kUTTypeGIF
//                                     filename:@"animated.gif"];
//                }else{
//                    [picker addAttachmentData:UIImageJPEGRepresentation(dataURL.image, 1.0)
//                               typeIdentifier:@"public.image"
//                                     filename:@"image.JPG"];
//                }
//            }else{
//                videoURLS = [videoURLS stringByAppendingString:[NSString stringWithFormat: @"%@ \n",dataURL.URL]];
//            }
//        }
//        picker.body = videoURLS;
//        
//        [self presentViewController:picker
//                           animated:YES
//                         completion:nil];
//        
//    } saveDataToCameraRoll:NO];
//}

//-(void)mailImages:(NSArray*)object{
//    [self getAllImagesForSelectedRows:^(NSArray *images) {
//        MFMailComposeViewController *picker = MFMailComposeViewController.new;
//        picker.mailComposeDelegate = self;
//        NSString *videoURLS = [NSString new];
//        
//        for (MHImageURL *dataURL in images) {
//            if ([dataURL.image isKindOfClass:UIImage.class]) {
//                UIImage *image = dataURL.image;
//                if (image.images) {
//                    [picker addAttachmentData:[NSData dataWithContentsOfFile:[[SDImageCache sharedImageCache] defaultCachePathForKey:dataURL.URL]]
//                                     mimeType:@"image/gif"
//                                     fileName:@"pic.gif"];
//                }else{
//                    [picker addAttachmentData:UIImageJPEGRepresentation(dataURL.image, 1.0)
//                                     mimeType:@"image/jpeg"
//                                     fileName:@"image"];
//                }
//                
//            }else{
//                videoURLS = [videoURLS stringByAppendingString:[NSString stringWithFormat: @"%@ \n",dataURL.URL]];
//            }
//        }
//        [picker setMessageBody:videoURLS isHTML:NO];
//        
//        if([MFMailComposeViewController canSendMail]){
//            [self presentViewController:picker
//                               animated:YES
//                             completion:nil];
//        }
//    } saveDataToCameraRoll:NO];
//}
-(void)messageComposeViewController:(MFMessageComposeViewController *)controller
                didFinishWithResult:(MessageComposeResult)result{
    
    __weak typeof(self) weakSelf = self;
    [controller dismissViewControllerAnimated:YES
                                   completion:^{
                                       [weakSelf cancelPressed];
                                   }];
}
-(void)mailComposeController:(MFMailComposeViewController *)controller
         didFinishWithResult:(MFMailComposeResult)result
                       error:(NSError *)error{
    
    __weak typeof(self) weakSelf = self;
    [controller dismissViewControllerAnimated:YES
                                   completion:^{
                                       [weakSelf cancelPressed];
                                   }];
}

//-(void)setSaveCounter:(NSInteger)saveCounter{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        if (saveCounter == self.selectedRows.count) {
//            UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
//            if (self.downloadView) {
//                [self removeBlurBlurBackgorundToolbarFromSuperView:^(BOOL complition) {
//                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                        self.finishedCallbackDownloadData(self.dataDownload);
//                    });
//                }];
//            }else{
//                self.finishedCallbackDownloadData(self.dataDownload);
//            }
//        }
//        [self.downloadView attributedStringForDownloadLabelWithDownloadedDataNumber:@(saveCounter)
//                                                                          maxNumber:@(self.selectedRows.count)];
//    });
//    _saveCounter = saveCounter;
//}
//-(void)removeBlurBlurBackgorundToolbarFromSuperView:(void(^)(BOOL complition))SuccessBlock{
//    [UIView animateWithDuration:0.3 animations:^{
//        self.downloadView.blurBackgroundToolbar.alpha =0;
//    } completion:^(BOOL finished) {
//        [self.downloadView removeFromSuperview];
//        if (SuccessBlock) {
//            SuccessBlock(YES);
//        }
//    }];
//}
-(void)addDataToDownloadArray:(id)data{
    [self.dataDownload addObject:data];
    self.saveCounter++;
}


//-(void)getAllImagesForSelectedRows:(void(^)(NSArray *images))SuccessBlock
//              saveDataToCameraRoll:(BOOL)saveToCameraRoll{
//    
//    BOOL containsVideo = NO;
//    for (NSIndexPath *indexPath in self.selectedRows) {
//        MHGalleryItem *item = [self itemForIndex:indexPath.row];
//        
//        if (item.galleryType == MHGalleryTypeVideo) {
//            containsVideo = YES;
//        }
//    }
//    self.sessions = NSMutableArray.new;
//    
//    if (saveToCameraRoll && containsVideo) {
//        
//        self.downloadView = [MHDownloadView.alloc initWithFrame:self.view.bounds];
//        self.downloadView.blurBackgroundToolbar.alpha =0;
//        __weak typeof(self) weakSelf = self;
//        self.downloadView.cancelCallbackDownloadData = ^(BOOL cancel){
//            UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
//            for (NSURLSession *session in weakSelf.sessions) {
//                [session invalidateAndCancel];
//            }
//            [weakSelf removeBlurBlurBackgorundToolbarFromSuperView:nil];
//        };
//        self.downloadView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
//        [self.downloadView attributedStringForDownloadLabelWithDownloadedDataNumber:@(0) maxNumber:@(self.selectedRows.count)];
//        [self.navigationController.view addSubview:self.downloadView];
//        
//        [UIView animateWithDuration:0.3 animations:^{
//            self.downloadView.blurBackgroundToolbar.alpha =1;
//        }];
//    }
//    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
//    
//    self.dataDownload = NSMutableArray.new;
//    
//    self.finishedCallbackDownloadData = SuccessBlock;
//    
//    self.saveCounter =0;
//    
//    __weak typeof(self) weakSelf = self;
//    
//    for (NSIndexPath *indexPath in self.selectedRows) {
//        MHGalleryItem *item = [self itemForIndex:indexPath.row];
//        
//        if (item.galleryType == MHGalleryTypeVideo) {
//            if (!saveToCameraRoll) {
//                MHImageURL *imageURL = [MHImageURL.alloc initWithURL:item.URLString image:nil];
//                [weakSelf addDataToDownloadArray:imageURL];
//            }else{
//                [MHGallerySharedManager.sharedManager getURLForMediaPlayer:item.URLString successBlock:^(NSURL *URL, NSError *error) {
//                    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
//                    
//                    [self.sessions addObject:session];
//                    [[session downloadTaskWithURL:URL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
//                        if (error){
//                            weakSelf.saveCounter++;
//                            return;
//                        }
//                        NSURL *documentsURL = [[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
//                        NSURL *tempURL = [documentsURL URLByAppendingPathComponent:@"storeForShare.mp4"];
//                        
//                        NSError *moveItemError = nil;
//                        [NSFileManager.defaultManager moveItemAtURL:location toURL:tempURL error:&moveItemError];
//                        
//                        if (moveItemError) {
//                            weakSelf.saveCounter++;
//                            return;
//                        }
//                        ALAssetsLibrary* library = ALAssetsLibrary.new;
//                        [library writeVideoAtPathToSavedPhotosAlbum:tempURL
//                                                    completionBlock:^(NSURL *assetURL, NSError *error){
//                                                        NSError *removeError =nil;
//                                                        [NSFileManager.defaultManager removeItemAtURL:tempURL error:&removeError];
//                                                        
//                                                        [weakSelf.sessions removeObject:session];
//                                                        weakSelf.saveCounter++;
//                                                    }];
//                    }] resume];
//                }];
//            }
//            
//        }
//        
//        if (item.galleryType == MHGalleryTypeImage) {
//            
//            if ([item.URLString rangeOfString:MHAssetLibrary].location != NSNotFound && item.URLString) {
//                [MHGallerySharedManager.sharedManager getImageFromAssetLibrary:item.URLString
//                                                                     assetType:MHAssetImageTypeFull
//                                                                  successBlock:^(UIImage *image, NSError *error) {
//                                                                      MHImageURL *imageURL = [MHImageURL.alloc initWithURL:item.URLString
//                                                                                                                     image:image];
//                                                                      [weakSelf addDataToDownloadArray:imageURL];
//                                                                  }];
//            }else if (item.image) {
//                [self addDataToDownloadArray:item.image];
//            }else{
//                [SDWebImageManager.sharedManager downloadWithURL:[NSURL URLWithString:item.URLString]
//                                                         options:SDWebImageContinueInBackground
//                                                        progress:nil
//                                                       completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished) {
//                                                           
//                                                           MHImageURL *imageURL = [MHImageURL.alloc initWithURL:item.URLString
//                                                                                                          image:image];
//                                                           
//                                                           [weakSelf addDataToDownloadArray:imageURL];
//                                                       }];
//            }
//        }
//    }
//}
-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                        duration:(NSTimeInterval)duration{
    if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
        self.navigationItem.leftBarButtonItem = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                            target:self
                                                                                            action:@selector(cancelPressed)];
        self.navigationItem.rightBarButtonItem = nil;
        self.collectionView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-240);
        self.toolbar.frame = CGRectMake(0, self.view.frame.size.height-240, self.view.frame.size.width,240);
        self.tableViewShare.frame = CGRectMake(0, self.view.frame.size.height-230, self.view.frame.size.width, 240);
        self.gradientView.frame = CGRectMake(0, self.view.frame.size.height-240, self.view.frame.size.width,240);
    }else{
        self.tableViewShare.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 240);
        self.toolbar.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width,240);
        self.collectionView.frame = self.view.bounds;
        self.navigationItem.rightBarButtonItem = [self nextBarButtonItem];
    }
    [self.collectionView.collectionViewLayout invalidateLayout];
}

-(UIBarButtonItem*)nextBarButtonItem{
    return [UIBarButtonItem.alloc initWithTitle:@"Next"
                                          style:UIBarButtonItemStyleBordered
                                         target:self
                                         action:@selector(showShareSheet)];
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    
    NSArray *visibleCells = [self sortObjectsWithFrame:self.collectionView.visibleCells];
    NSInteger numberToScrollTo = visibleCells.count/2;
    MHMediaPreviewCollectionViewCell *cell =  (MHMediaPreviewCollectionViewCell*)visibleCells[numberToScrollTo];
    
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:cell.tag inSection:0]
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:YES];
    
    if (self.isShowingShareViewInLandscapeMode) {
        self.showingShareViewInLandscapeMode = NO;
    }
    
}
-(void)cancelShareSheet{
    self.showingShareViewInLandscapeMode = NO;
    
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                        target:self
                                                                                        action:@selector(cancelPressed)];
    
    self.navigationItem.rightBarButtonItem = [self nextBarButtonItem];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.toolbar.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width,240);
        self.tableViewShare.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 240);
    }];
}
-(void)showShareSheet{
    self.showingShareViewInLandscapeMode = YES;
    self.navigationItem.rightBarButtonItem = nil;
    
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                        target:self
                                                                                        action:@selector(cancelShareSheet)];
    
    self.toolbar.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width,240);
    self.tableViewShare.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 240);
    
    [UIView animateWithDuration:0.3 animations:^{
        self.toolbar.frame = CGRectMake(0, self.view.frame.size.height-240, self.view.frame.size.width,240);
        self.tableViewShare.frame = CGRectMake(0, self.view.frame.size.height-230, self.view.frame.size.width, 240);
    }];
    
}
//-(void)saveImages:(NSArray*)object{
//    [self getAllImagesForSelectedRows:^(NSArray *images) {
//        for (MHImageURL *dataURL in images) {
//            if ([dataURL.image isKindOfClass:[UIImage class]]) {
//                
//                UIImage *imageToStore = dataURL.image;
//                
//                ALAssetsLibrary* library = ALAssetsLibrary.new;
//                NSData *data;
//                
//                if (imageToStore.images) {
//                    data = [NSData dataWithContentsOfFile:[[SDImageCache sharedImageCache] defaultCachePathForKey:dataURL.URL]];
//                }else{
//                    data = UIImageJPEGRepresentation(imageToStore, 1.0);
//                }
//                
//                [library writeImageDataToSavedPhotosAlbum:data metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
//                    NSLog(@"%@",error);
//                }];
//            }
//        }
//        [self cancelPressed];
//    } saveDataToCameraRoll:YES];
//}



-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    
    if ([collectionView isEqual:self.collectionView]) {
        [collectionView deselectItemAtIndexPath:indexPath animated:NO];
        if ([self.selectedRows containsObject:indexPath]) {
            [self.selectedRows removeObject:indexPath];
        }else{
            [self.selectedRows addObject:indexPath];
        }
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        
        [self.collectionView.delegate scrollViewDidScroll:self.collectionView];
        [UIView animateWithDuration:0.35 animations:^{
            [self.collectionView scrollToItemAtIndexPath:indexPath
                                        atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                animated:NO];
        } completion:^(BOOL finished) {
            [self.collectionView.delegate scrollViewDidScroll:self.collectionView];
        }];
        
//        [self updateCollectionView];
        [self.selectedRowsCollectionView reloadData];
        [self updateTitle];
    }else{
        indexPath = [self.selectedRows objectAtIndex:indexPath.row];
        [collectionView deselectItemAtIndexPath:indexPath animated:NO];
        if ([self.selectedRows containsObject:indexPath]) {
            [self.selectedRows removeObject:indexPath];
        }else{
            [self.selectedRows addObject:indexPath];
        }
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        
        [self.collectionView.delegate scrollViewDidScroll:self.collectionView];
        [UIView animateWithDuration:0.35 animations:^{
            [self.collectionView scrollToItemAtIndexPath:indexPath
                                        atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                animated:NO];
        } completion:^(BOOL finished) {
            [self.collectionView.delegate scrollViewDidScroll:self.collectionView];
        }];
        if (self.selectedRows.count > 2)
        [self.selectedRowsCollectionView reloadData];
        [self updateTitle];
    }
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
