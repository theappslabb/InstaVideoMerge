//
//  EditorViewController.m
//
#import "EditorViewController.h"
#import "EditorTableViewCell.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "YAScrollSegmentControl.h"
#import <QuartzCore/QuartzCore.h>
#import "AVFoundation/AVFoundation.h"

@interface EditorViewController ()<UINavigationControllerDelegate, UIImagePickerControllerDelegate, YAScrollSegmentControlDelegate>
{
    UIImage *VidBackImage;
    AVPlayer *player;
    NSURL *videoFileUrl;
}

@property (nonatomic, weak) IBOutlet YAScrollSegmentControl *scrollSegment;


@property (strong, nonatomic) SAVideoRangeSlider *mySAVideoRangeSlider;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (strong, nonatomic) AVAssetExportSession *exportSession;
@property (strong, nonatomic) NSString *originalVideoPath;
@property (strong, nonatomic) NSString *tmpVideoPath;
@property (nonatomic) CGFloat startTime;
@property (nonatomic) CGFloat stopTime;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *myActivityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *trimBtn;

@end

@implementation EditorViewController

@synthesize VideoAssetArray;
@synthesize firstAsset,secondAsset,audioAsset,ActivityView;


- (void)viewDidLoad
{
    [super viewDidLoad];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [userDefaults objectForKey:@"ArrayOfAssets"];
    NSDictionary *retrievedDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    VideoAssetArray = [retrievedDictionary mutableCopy];
    
    NSString *tempDir = NSTemporaryDirectory();
    self.tmpVideoPath = [tempDir stringByAppendingPathComponent:@"tmpMov.mov"];

    
    [self setUpDefaultValues];
    
    savebtnImgView.image = [savebtnImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [savebtnImgView setTintColor:[UIColor redColor]];
    self.myActivityIndicator.hidden = YES;
    
    //Long Press gesture for drag drop functionality
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognized:)];
    longPress.minimumPressDuration = 2.0;
    [editorTableView addGestureRecognizer:longPress];
    
    UITapGestureRecognizer *playPauseTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playPausePlayer:)];
    playPauseTapRecognizer.numberOfTapsRequired = 1;
    [preViewBack addGestureRecognizer:playPauseTapRecognizer];

    [mScrubber setThumbImage:[UIImage imageNamed:@"img"] forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [userDefaults objectForKey:@"ArrayOfAssets"];
    NSDictionary *retrievedDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    VideoAssetArray = [retrievedDictionary mutableCopy];
    if ([userDefaults boolForKey:@"AddNewVideo"] == YES)
    {
        [editorTableView reloadData];
    }
}

- (void)playPausePlayer:(UITapGestureRecognizer*)sender {
//    UIView *view = sender.view;
//    NSLog(@"%ld", (long)view.tag);//By tag, you can find out where you had tapped.
    
    [self pauseVideo];
}



- (void)setUpDefaultValues
{
    selectedIndex= 0;
//    [self loadimage];
    videoFileUrl = [[VideoAssetArray valueForKey:UIImagePickerControllerReferenceURL] objectAtIndex:0];
    [self prepairVideoPlayer];
    [self syncScrubber];
}

-(void)prepairVideoPlayer
{
    avAsset = [AVAsset assetWithURL:videoFileUrl];
    avPlayerItem =[[AVPlayerItem alloc]initWithAsset:avAsset];
    avPlayer = [[AVPlayer alloc]initWithPlayerItem:avPlayerItem];
    avPlayerLayer =[AVPlayerLayer playerLayerWithPlayer:avPlayer];
    [avPlayerLayer setFrame:preViewBack.frame];
    [preViewBack.layer addSublayer:avPlayerLayer];
//    [avPlayerLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [avPlayerLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    //[avPlayerLayer setBackgroundColor:[[UIColor redColor]CGColor]];
    [avPlayer seekToTime:kCMTimeZero];
    [avPlayer setVolume:0];
    
    [avPlayer play];
    [avPlayer pause];
    
    [self initScrubberTimer];
    [self syncScrubber];
}


#pragma mark -
#pragma mark Movie scrubber control

/* ---------------------------------------------------------
 **  Methods to handle manipulation of the movie scrubber control
 ** ------------------------------------------------------- */

/* Requests invocation of a given block during media playback to update the movie scrubber control. */
-(void)initScrubberTimer
{
    double interval = .1f;
    
    CMTime playerDuration = [avAsset duration];
    if (CMTIME_IS_INVALID(playerDuration))
    {
        return;
    }
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration))
    {
        CGFloat width = CGRectGetWidth([mScrubber bounds]);
        interval = 0.5f * duration / width;
    }
    
    /* Update the scrubber during normal playback. */
    __weak EditorViewController *weakSelf = self;
    mTimeObserver = [avPlayer  addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC)
                                                               queue:NULL /* If you pass NULL, the main queue is used. */
                                                          usingBlock:^(CMTime time)
                     {
                         [weakSelf syncScrubber];
                     }];
}

-(void)getDuration
{
    
}

/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
    NSLog(@"syncScrubbe");
    CMTime playerDuration = [avAsset duration];
    if (CMTIME_IS_INVALID(playerDuration))
    {
        mScrubber.minimumValue = 0.0;
        return;
    }
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration))
    {
        float minValue = [mScrubber minimumValue];
        float maxValue = [mScrubber maximumValue];
        double time = CMTimeGetSeconds([avPlayer currentTime]);
        
        [mScrubber setValue:(maxValue - minValue) * time / duration + minValue];
    }
}

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (IBAction)beginScrubbing:(id)sender
{
    mRestoreAfterScrubbingRate = [avPlayer rate];
    [avPlayer setRate:0.f];
    [self initScrubberTimer];
    /* Remove previous timer. */
    [self removePlayerTimeObserver];
}

/* Set the player current time to match the scrubber position. */
- (IBAction)scrub:(id)sender
{
    if ([sender isKindOfClass:[UISlider class]] && !isSeeking)
    {
        isSeeking = YES;
        UISlider* slider = sender;
        
        CMTime playerDuration = [avAsset duration];
        if (CMTIME_IS_INVALID(playerDuration)) {
            return;
        }
        [PlayButton setHidden:NO];
        double duration = CMTimeGetSeconds(playerDuration);
        if (isfinite(duration))
        {
            float minValue = [slider minimumValue];
            float maxValue = [slider maximumValue];
            float value = [slider value];
            
            double time = duration * (value - minValue) / (maxValue - minValue);
            
            [avPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    isSeeking = NO;
                });
            }];
        }
    }
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (IBAction)endScrubbing:(id)sender
{
    if (!mTimeObserver)
    {
        CMTime playerDuration = [avAsset duration];
        if (CMTIME_IS_INVALID(playerDuration))
        {
            return;
        }
        
        double duration = CMTimeGetSeconds(playerDuration);
        if (isfinite(duration))
        {
            CGFloat width = CGRectGetWidth([mScrubber bounds]);
            double tolerance = 0.5f * duration / width;
            
            __weak EditorViewController *weakSelf = self;
            mTimeObserver = [avPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC) queue:NULL usingBlock:
                             ^(CMTime time)
                             {
                                 [weakSelf syncScrubber];
                             }];
        }
    }
    
    if (mRestoreAfterScrubbingRate)
    {
        [avPlayer setRate:mRestoreAfterScrubbingRate];
        mRestoreAfterScrubbingRate = 0.f;
    }
}

- (BOOL)isScrubbing
{
    return mRestoreAfterScrubbingRate != 0.f;
}

-(void)enableScrubber
{
    mScrubber.enabled = YES;
}

-(void)disableScrubber
{
    mScrubber.enabled = NO;
}

/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
    if (mTimeObserver)
    {
        [avPlayer removeTimeObserver:mTimeObserver];
        mTimeObserver = nil;
    }
}


- (CMTime)playerItemDuration
{
//    AVPlayerItem *playerItem = avPlayerItem;
//    if (playerItem.status == AVPlayerItemStatusReadyToPlay)
//    {
        return([avAsset duration]);
//    }
//    return(kCMTimeInvalid);
}

- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

-(void)loadimage{
    
    VidBackImage = [[VideoAssetArray valueForKey:UIImagePickerControllerOriginalImage] objectAtIndex:selectedIndex];
    VidPreViewImgView.image = VidBackImage;
}

//- (void) startplayingWithURl:(NSURL *) Url
//{
//        MPMoviePlayerViewController *videoPlayerView = [[MPMoviePlayerViewController alloc] initWithContentURL:Url];
//        [self presentMoviePlayerViewControllerAnimated:videoPlayerView];
//        [videoPlayerView.moviePlayer play];
//}




#pragma mark *********************
#pragma mark Table View DataSource
#pragma mark *********************

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [VideoAssetArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"EditorTableViewCell";
    
    EditorTableViewCell *cell = (EditorTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
//    if (<#condition#>) {
//        <#statements#>
//    }
//    UIView *view = [self.view viewWithTag:indexPath.row * 100];
//    if (view)
//    {
//        [view removeFromSuperview];
//    }
//    videoTimeLbl  = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 50, 20)];
//    videoTimeLbl.tag = indexPath.row * 100;
//    [cell addSubview:videoTimeLbl];
    
  
    
    self.mySAVideoRangeSlider = [[SAVideoRangeSlider alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width - 110, 40) videoUrl:[[VideoAssetArray valueForKey:UIImagePickerControllerReferenceURL] objectAtIndex:indexPath.row] ];
    self.mySAVideoRangeSlider.bubleText.font = [UIFont systemFontOfSize:12];
    [self.mySAVideoRangeSlider setPopoverBubbleSize:40 height:20];
    
    // Yellow
    self.mySAVideoRangeSlider.topBorder.backgroundColor = [UIColor blackColor];
    
    self.mySAVideoRangeSlider.delegate = self;
    [cell.SliderBackView addSubview:self.mySAVideoRangeSlider];
    
    cell.VideoThumbImgView.layer.cornerRadius = 2.0f;
    cell.VideoThumbImgView.clipsToBounds = YES;
    cell.VideoThumbImgView.layer.borderColor = (__bridge CGColorRef _Nullable)([UIColor redColor]);
    cell.VideoThumbImgView.layer.borderWidth = 2.0f;
    cell.VideoThumbImgView.image = [[VideoAssetArray valueForKey:UIImagePickerControllerOriginalImage] objectAtIndex:indexPath.row];
    selectedIndex = indexPath.row;
    cell.deleteBtn.tag = indexPath.row;
    [cell.deleteBtn addTarget:self action:@selector(DeleteVideo:) forControlEvents:UIControlEventTouchUpInside];
    
    
    cell.selectionStyle = UITableViewCellEditingStyleNone;
    tableView.backgroundColor = [UIColor clearColor];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    // This will create a "invisible" footer
    return 0.01f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
    
    // If you are not using ARC:
    // return [[UIView new] autorelease];
}

-(CGFloat)tableView: (UITableView*)tableView heightForRowAtIndexPath: (NSIndexPath*) indexPath
{
    return 80;
}


#pragma mark ********************
#pragma mark Table View Delegates
#pragma mark ********************

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    selectedIndex = indexPath.row;
    [self pauseVideo];
//    [self loadimage];
    videoFileUrl = [[VideoAssetArray valueForKey:UIImagePickerControllerReferenceURL] objectAtIndex:indexPath.row];
    [self prepairVideoPlayer];
}



-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if ([tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    
    if ([tableView respondsToSelector:@selector(setLayoutMargins:)]) {
        [tableView setLayoutMargins:UIEdgeInsetsZero];
    }
    
    if ([cell respondsToSelector:@selector(setLayoutMargins:)])
    {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}



- (IBAction)displayGestureForTapRecognizer:(UITapGestureRecognizer *)recognizer
{
    [player pause];
// Will implement method later...
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark - IBAction
- (IBAction)showOriginalVideo:(id)sender {
    
    [self playMovie:self.originalVideoPath];
    
}

- (IBAction)DeleteVideo:(id)sender {
    
    NSUInteger indexToDelete = [sender tag];
    [VideoAssetArray removeObjectAtIndex:indexToDelete];
    [editorTableView reloadData];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([VideoAssetArray count] == 0)
    {
        [userDefaults setObject:nil forKey:@"ArrayOfAssets"];
        [userDefaults synchronize];
        [self.navigationController popViewControllerAnimated:YES];
    } else
    {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:VideoAssetArray] forKey:@"ArrayOfAssets"];
        [userDefaults synchronize];
    }
}



- (IBAction)showTrimmedVideo:(id)sender {
    
    [self deleteTmpFile];
    
    videoFileUrl = videoFileUrl;
    
    AVAsset *anAsset = [[AVURLAsset alloc] initWithURL:videoFileUrl options:nil];
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:anAsset];
    if ([compatiblePresets containsObject:AVAssetExportPresetMediumQuality]) {
        
        self.exportSession = [[AVAssetExportSession alloc]
                              initWithAsset:anAsset presetName:AVAssetExportPresetPassthrough];
        // Implementation continues.
        
        NSURL *furl = [NSURL fileURLWithPath:self.tmpVideoPath];
        
        self.exportSession.outputURL = furl;
        self.exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        
        CMTime start = CMTimeMakeWithSeconds(self.startTime, anAsset.duration.timescale);
        CMTime duration = CMTimeMakeWithSeconds(self.stopTime-self.startTime, anAsset.duration.timescale);
        CMTimeRange range = CMTimeRangeMake(start, duration);
        self.exportSession.timeRange = range;
        
        self.trimBtn.hidden = YES;
        self.myActivityIndicator.hidden = NO;
        [self.myActivityIndicator startAnimating];
        [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
            
            switch ([self.exportSession status]) {
                case AVAssetExportSessionStatusFailed:
                    NSLog(@"Export failed: %@", [[self.exportSession error] localizedDescription]);
                    break;
                case AVAssetExportSessionStatusCancelled:
                    NSLog(@"Export canceled");
                    break;
                default:
                    NSLog(@"NONE");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.myActivityIndicator stopAnimating];
                        self.myActivityIndicator.hidden = YES;
                        self.trimBtn.hidden = NO;
                        [self playMovie:self.tmpVideoPath];
                    });
                    
                    break;
            }
        }];
        
    }
    
}


#pragma mark - Other
-(IBAction)reload:(id)sender
{
    UIAlertController *alertController;
    UIAlertAction *destroyAction;
    UIAlertAction *otherAction;
    
    alertController = [UIAlertController alertControllerWithTitle:@"Reload"
                                                          message:@"Reload will lost all your changes"
                                                   preferredStyle:UIAlertControllerStyleAlert];
    destroyAction = [UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction *action) {
                                               // do destructive stuff here
                                               [self dismissViewControllerAnimated:YES completion:nil];
                                           }];
    otherAction = [UIAlertAction actionWithTitle:@"Done"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                             // do something here
                                             NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                                             [userDefaults setObject:nil forKey:@"ArrayOfAssets"];
                                             [userDefaults synchronize];
                                             [self dismissViewControllerAnimated:YES completion:nil];
                                             [self.navigationController popViewControllerAnimated:YES];
                                         }];
    // note: you can control the order buttons are shown, unlike UIActionSheet
    [alertController addAction:destroyAction];
    [alertController addAction:otherAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

-(AVAsset *)currentAsset:(int)num
{
    NSLog(@"%@",[AVAsset assetWithURL:[[VideoAssetArray valueForKey:UIImagePickerControllerReferenceURL] objectAtIndex:num]]);
    
    return [AVAsset assetWithURL:[[VideoAssetArray valueForKey:UIImagePickerControllerReferenceURL] objectAtIndex:num]];
//    if(num == 0)
//    {
//        return firstAsset;
//    }
//    else if(num == 1){
//        return secondAsset;
//    }
//    else if(num == 2){
//        
//        //        return lastAsset;
//    }
    return nil;
}




- (void)MergeAndSaving
{
    AVMutableComposition* mixComposition = [[AVMutableComposition alloc] init];
    
    NSMutableArray *arrayInstruction = [[NSMutableArray alloc] init];
    
    AVMutableVideoCompositionInstruction * MainInstruction =
    [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    
    AVMutableCompositionTrack *audioTrack =                             [mixComposition      addMutableTrackWithMediaType:AVMediaTypeAudio
                                             preferredTrackID:kCMPersistentTrackID_Invalid];
    

    
    CMTime duration = kCMTimeZero;
    CGSize videoSize;
    
    for(int i=0;i< [VideoAssetArray count];i++)
    {

        AVAsset *currentAsset = [self currentAsset:i]; // i take the for loop for geting the asset
        
         videoSize = [[[currentAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];

        /* Current Asset is the asset of the video From the Url Using AVAsset */
        
        
        AVMutableCompositionTrack *currentTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [currentTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, currentAsset.duration) ofTrack:[[currentAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:duration error:nil];
        
        if ([[currentAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0])
        {
            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, currentAsset.duration) ofTrack:[[currentAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:duration error:nil];
        }
        
        AVMutableVideoCompositionLayerInstruction *currentAssetLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:currentTrack];
        AVAssetTrack *currentAssetTrack = [[currentAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        UIImageOrientation currentAssetOrientation  = UIImageOrientationUp;
        BOOL  isCurrentAssetPortrait  = NO;
        CGAffineTransform currentTransform = currentAssetTrack.preferredTransform;
        
        if(currentTransform.a == 0 && currentTransform.b == 1.0 && currentTransform.c == -1.0 && currentTransform.d == 0)  {currentAssetOrientation= UIImageOrientationRight; isCurrentAssetPortrait = YES;}
        if(currentTransform.a == 0 && currentTransform.b == -1.0 && currentTransform.c == 1.0 && currentTransform.d == 0)  {currentAssetOrientation =  UIImageOrientationLeft; isCurrentAssetPortrait = YES;}
        if(currentTransform.a == 1.0 && currentTransform.b == 0 && currentTransform.c == 0 && currentTransform.d == 1.0)   {currentAssetOrientation =  UIImageOrientationUp;}
        if(currentTransform.a == -1.0 && currentTransform.b == 0 && currentTransform.c == 0 && currentTransform.d == -1.0) {currentAssetOrientation = UIImageOrientationDown;}
        //Change
        CGFloat FirstAssetScaleToFitRatio = FirstAssetScaleToFitRatio = 640.0/640.0;;
//        CGFloat FirstAssetScaleToFitRatio = videoSize.width/videoSize.height;
        if(isCurrentAssetPortrait){
            FirstAssetScaleToFitRatio = 640.0/640.0;
//            FirstAssetScaleToFitRatio = videoSize.width/videoSize.height;
//            CGFloat FirstAssetScaleToFitRatio = 640.0/currentAssetTrack.naturalSize.height*2;
            CGAffineTransform FirstAssetScaleFactor = CGAffineTransformMakeScale(FirstAssetScaleToFitRatio,FirstAssetScaleToFitRatio);
            [currentAssetLayerInstruction setTransform:CGAffineTransformConcat(currentAssetTrack.preferredTransform, FirstAssetScaleFactor) atTime:duration];
        }else{
            
            CGAffineTransform FirstAssetScaleFactor = CGAffineTransformMakeScale(FirstAssetScaleToFitRatio,FirstAssetScaleToFitRatio);
            [currentAssetLayerInstruction setTransform:CGAffineTransformConcat(CGAffineTransformConcat(currentAssetTrack.preferredTransform, FirstAssetScaleFactor),CGAffineTransformMakeTranslation(0, 0)) atTime:duration];
        }
        
        duration=CMTimeAdd(duration, currentAsset.duration);
        
        [currentAssetLayerInstruction setOpacity:0.0 atTime:duration];
        [arrayInstruction addObject:currentAssetLayerInstruction];
        
        NSLog(@"%lld", duration.value/duration.timescale);
        
        /*
        myImage = [UIImage imageNamed:@"mits@2x.png"];
        aLayer  = [CALayer layer];
        //[aLayer retain];
        aLayer.contents = (id)myImage.CGImage;
        aLayer.frame = CGRectMake(640-100, 100, 20, 20);
        aLayer.opacity = 1;
        */
        parentLayer = [CALayer layer];
        videoLayer  = [CALayer layer];
        parentLayer.frame = CGRectMake(0, 0, 640,640);
        videoLayer.frame = CGRectMake(0, 0, 640, 640);
        [parentLayer addSublayer:videoLayer];
//        [parentLayer addSublayer:aLayer];
        
        
    }
    
    MainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
    MainInstruction.layerInstructions = arrayInstruction;
    AVMutableVideoComposition *MainCompositionInst = [AVMutableVideoComposition videoComposition];
    MainCompositionInst.instructions = [NSArray arrayWithObject:MainInstruction];
    MainCompositionInst.frameDuration = CMTimeMake(1, 30);
    //With orignal video
//    MainCompositionInst.renderSize = CGSizeMake(videoSize.width, videoSize.height);
    
    MainCompositionInst.renderSize = CGSizeMake(640.0, 320.0);
    
    //
    MainCompositionInst.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    
//New Code
/*
 
*******************
 AVMutableVideoComposition *videoComp = [AVMutableVideoComposition videoComposition];
 videoComp.renderSize = videoSize;
 videoComp.frameDuration = CMTimeMake(1, 30);
 videoComp.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
 ******************
 
 
 
 AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
 instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [mixComposition duration]);
 AVAssetTrack *videoTrack = [[mixComposition tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
 
 AVMutableVideoCompositionLayerInstruction* layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
 instruction.layerInstructions = [NSArray arrayWithObject:layerInstruction];
 videoComp.instructions = [NSArray arrayWithObject: instruction];
 
 UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
 BOOL  isVideoAssetPortrait_  = NO;
 CGAffineTransform videoTransform = clipVideoTrack.preferredTransform;
 
 if(videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0)  {videoAssetOrientation_= UIImageOrientationRight; isVideoAssetPortrait_ = YES;}
 if(videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0)  {videoAssetOrientation_ =  UIImageOrientationLeft; isVideoAssetPortrait_ = YES;}
 if(videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0)   {videoAssetOrientation_ =  UIImageOrientationUp;}
 if(videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {videoAssetOrientation_ = UIImageOrientationDown;}
 
 CGFloat FirstAssetScaleToFitRatio = 320.0 / clipVideoTrack.naturalSize.width;
 
 if(isVideoAssetPortrait_) {
 FirstAssetScaleToFitRatio = 320.0/clipVideoTrack.naturalSize.height;
 CGAffineTransform FirstAssetScaleFactor = CGAffineTransformMakeScale(FirstAssetScaleToFitRatio,FirstAssetScaleToFitRatio);
 [layerInstruction setTransform:CGAffineTransformConcat(clipVideoTrack.preferredTransform, FirstAssetScaleFactor) atTime:kCMTimeZero];
 }else{
 CGAffineTransform FirstAssetScaleFactor = CGAffineTransformMakeScale(FirstAssetScaleToFitRatio,FirstAssetScaleToFitRatio);
 [layerInstruction setTransform:CGAffineTransformConcat(CGAffineTransformConcat(clipVideoTrack.preferredTransform, FirstAssetScaleFactor),CGAffineTransformMakeTranslation(0, 160)) atTime:kCMTimeZero];
 }
 // [layerInstruction setOpacity:0.0 atTime:kCMTimeZero];
 
 AVAssetExportSession *assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];//AVAssetExportPresetPassthrough
 assetExport.videoComposition = videoComp;
 */
    
    NSString *myPathDocs =  [[self applicationCacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"mergeVideo%-dtemp.mp4",arc4random() % 10000]];
    
    NSURL *url = [NSURL fileURLWithPath:myPathDocs];
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=url;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.videoComposition = MainCompositionInst;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^
     {
         switch (exporter.status)
         {
             case AVAssetExportSessionStatusCompleted:
             {
                 NSURL *outputURL = exporter.outputURL;
                 
                 ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                 if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputURL]) {
                     
                     ALAssetsLibrary* library = [[ALAssetsLibrary alloc]init];
                     [library writeVideoAtPathToSavedPhotosAlbum:outputURL completionBlock:^(NSURL *assetURL, NSError *error)
                      {
                          NSLog(@"ASSET URL %@",assetURL);
                          if (error)
                          {
                              NSLog(@"EROR %@ ", error);
                          }else{
                              NSLog(@"VIDEO SAVED ");
                              [self HideLoader];
                              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"  delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil];
                              [alert show];
                          }
                          
                      }];
                 }
             }
                 break;
             case AVAssetExportSessionStatusFailed:
                 NSLog(@"Failed:%@", exporter.error.description);
                 break;
             case AVAssetExportSessionStatusCancelled:
                 NSLog(@"Canceled:%@", exporter.error);
                 break;
             case AVAssetExportSessionStatusExporting:
                 NSLog(@"Exporting!");
                 break;
             case AVAssetExportSessionStatusWaiting:
                 NSLog(@"Waiting");
                 break;
             default:
                 break;
         }
     }];
}

-(void)savefinalVideoFileToDocuments:(NSURL *)url
{
    NSString *storePath = [[self applicationCacheDirectory] stringByAppendingPathComponent:@"FinalVideo"];
    storePath = [storePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4",@"mergedvideo"]];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:storePath] == YES) {
        NSLog(@"removeItemAtPath >>>>>>>>>>>>>>>>>> saveVideoFileToDocuments 1 :%@", storePath);
        [[NSFileManager defaultManager] removeItemAtPath:storePath error:NULL];
    }
    
    NSError * error = nil;
    if (url == nil) {
        return;
    }
    
    [[NSFileManager defaultManager] copyItemAtURL:url
                                            toURL:[NSURL fileURLWithPath:storePath]
                                            error:&error];
    
    if ( error ) {
        NSLog(@"%@", error);
        NSLog(@"removeItemAtPath >>>>>>>>>>>>>>>>>> saveVideoFileToDocuments 2 :%@", storePath);
        [[NSFileManager defaultManager] removeItemAtPath:storePath error:NULL];
        return;
    }
    //[objEditView thumbnailFromVideoAtURL:url];
    NSData * movieData = [NSData dataWithContentsOfURL:url];
    [movieData writeToFile:storePath atomically:YES];
}

-(NSString *)applicationCacheDirectory
{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}


//-(void)monitorProgress{
//    if ([exporter progress] == 1.0){
//        [timer invalidate];
//    }
//    
//    NSLog(@"Progress: %f",[exporter progress]* 100);
//}


- (IBAction)MergeAndSave:(id)sender{
//    if(firstAsset !=nil && secondAsset!=nil)
//    {
        [self showLoader];
        [self MergeAndSaving];
//        [self videoOutput];
//    }
    
//        [self showLoader];
//        [ActivityView startAnimating];
//        //Create AVMutableComposition Object.This object will hold our multiple AVMutableCompositionTrack.
//        AVMutableComposition* mixComposition = [[AVMutableComposition alloc] init];
//        
//        //VIDEO TRACK
//        AVMutableCompositionTrack *firstTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
//        [firstTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, firstAsset.duration) ofTrack:[[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
//        
//        
//        AVMutableCompositionTrack *secondTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
//        [secondTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration) ofTrack:[[secondAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:firstAsset.duration error:nil];
//        
////        //AUDIO TRACK
////        AVMutableCompositionTrack *firstTrackAudio = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
////
////        AVMutableCompositionTrack *secondTrackAudio = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
//        
//        //AUDIO TRACK
//        //        if(audioAsset!=nil){
//        //            AVMutableCompositionTrack *AudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
//        //            [AudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration)) ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:nil];
//        //        }  else{
//        //
//        //        }
////        
////        if ([[firstAsset tracksWithMediaType:AVMediaTypeAudio] count] > 0)
////        {
////            AVAssetTrack *clipAudioTrack = [[firstAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
////            [firstTrackAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, firstAsset.duration) ofTrack:clipAudioTrack atTime:kCMTimeZero error:nil];
////        }
////        // it has an audio track
////        
////        if ([[secondAsset tracksWithMediaType:AVMediaTypeAudio] count] > 0)
////        {
////            AVAssetTrack *clipAudioTrack = [[secondAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
////            [secondTrackAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration) ofTrack:clipAudioTrack atTime:secondAsset.duration error:nil];
////        }
//        
//        AVMutableVideoCompositionInstruction * MainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
//        MainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration));
//        
//        //FIXING ORIENTATION//
//        AVMutableVideoCompositionLayerInstruction *FirstlayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:firstTrack];
//        AVAssetTrack *FirstAssetTrack = [[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
//        
//        UIImageOrientation FirstAssetOrientation_  = UIImageOrientationUp;
//        BOOL  isFirstAssetPortrait_  = NO;
//        CGAffineTransform firstTransform = FirstAssetTrack.preferredTransform;
//        if(firstTransform.a == 0 && firstTransform.b == 1.0 && firstTransform.c == -1.0 && firstTransform.d == 0)  {FirstAssetOrientation_= UIImageOrientationRight; isFirstAssetPortrait_ = YES;}
//        if(firstTransform.a == 0 && firstTransform.b == -1.0 && firstTransform.c == 1.0 && firstTransform.d == 0)  {FirstAssetOrientation_ =  UIImageOrientationLeft; isFirstAssetPortrait_ = YES;}
//        if(firstTransform.a == 1.0 && firstTransform.b == 0 && firstTransform.c == 0 && firstTransform.d == 1.0)   {FirstAssetOrientation_ =  UIImageOrientationUp;}
//        if(firstTransform.a == -1.0 && firstTransform.b == 0 && firstTransform.c == 0 && firstTransform.d == -1.0) {FirstAssetOrientation_ = UIImageOrientationDown;}
//        CGFloat FirstAssetScaleToFitRatio = 320.0/FirstAssetTrack.naturalSize.width;
//        if(isFirstAssetPortrait_){
//            FirstAssetScaleToFitRatio = 320.0/FirstAssetTrack.naturalSize.height;
//            CGAffineTransform FirstAssetScaleFactor = CGAffineTransformMakeScale(FirstAssetScaleToFitRatio,FirstAssetScaleToFitRatio);
//            [FirstlayerInstruction setTransform:CGAffineTransformConcat(FirstAssetTrack.preferredTransform, FirstAssetScaleFactor) atTime:kCMTimeZero];
//        }else{
//            CGAffineTransform FirstAssetScaleFactor = CGAffineTransformMakeScale(FirstAssetScaleToFitRatio,FirstAssetScaleToFitRatio);
//            [FirstlayerInstruction setTransform:CGAffineTransformConcat(CGAffineTransformConcat(FirstAssetTrack.preferredTransform, FirstAssetScaleFactor),CGAffineTransformMakeTranslation(0, 160)) atTime:kCMTimeZero];
//        }
//        [FirstlayerInstruction setOpacity:0.0 atTime:firstAsset.duration];
//        
//        AVMutableVideoCompositionLayerInstruction *SecondlayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:secondTrack];
//        AVAssetTrack *SecondAssetTrack = [[secondAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
//        
//        UIImageOrientation SecondAssetOrientation_  = UIImageOrientationUp;
//        BOOL  isSecondAssetPortrait_  = NO;
//        CGAffineTransform secondTransform = SecondAssetTrack.preferredTransform;
//        if(secondTransform.a == 0 && secondTransform.b == 1.0 && secondTransform.c == -1.0 && secondTransform.d == 0)  {SecondAssetOrientation_= UIImageOrientationRight; isSecondAssetPortrait_ = YES;}
//        if(secondTransform.a == 0 && secondTransform.b == -1.0 && secondTransform.c == 1.0 && secondTransform.d == 0)  {SecondAssetOrientation_ =  UIImageOrientationLeft; isSecondAssetPortrait_ = YES;}
//        if(secondTransform.a == 1.0 && secondTransform.b == 0 && secondTransform.c == 0 && secondTransform.d == 1.0)   {SecondAssetOrientation_ =  UIImageOrientationUp;}
//        if(secondTransform.a == -1.0 && secondTransform.b == 0 && secondTransform.c == 0 && secondTransform.d == -1.0) {SecondAssetOrientation_ = UIImageOrientationDown;}
//        CGFloat SecondAssetScaleToFitRatio = 320.0/SecondAssetTrack.naturalSize.width;
//        if(isSecondAssetPortrait_){
//            SecondAssetScaleToFitRatio = 320.0/SecondAssetTrack.naturalSize.height;
//            CGAffineTransform SecondAssetScaleFactor = CGAffineTransformMakeScale(SecondAssetScaleToFitRatio,SecondAssetScaleToFitRatio);
//            [SecondlayerInstruction setTransform:CGAffineTransformConcat(SecondAssetTrack.preferredTransform, SecondAssetScaleFactor) atTime:firstAsset.duration];
//        }else{
//            ;
//            CGAffineTransform SecondAssetScaleFactor = CGAffineTransformMakeScale(SecondAssetScaleToFitRatio,SecondAssetScaleToFitRatio);
//            [SecondlayerInstruction setTransform:CGAffineTransformConcat(CGAffineTransformConcat(SecondAssetTrack.preferredTransform, SecondAssetScaleFactor),CGAffineTransformMakeTranslation(0, 160)) atTime:firstAsset.duration];
//        }
//        
//        
//        MainInstruction.layerInstructions = [NSArray arrayWithObjects:FirstlayerInstruction,SecondlayerInstruction,nil];;
//        
//        AVMutableVideoComposition *MainCompositionInst = [AVMutableVideoComposition videoComposition];
//        MainCompositionInst.instructions = [NSArray arrayWithObject:MainInstruction];
//        MainCompositionInst.frameDuration = CMTimeMake(1, 30);
////        CGSize size = [[[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];
////        MainCompositionInst.renderSize = CGSizeMake(size.width, size.height);
//        MainCompositionInst.renderSize = CGSizeMake(320.0, 480.0);
//        
//        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//        NSString *documentsDirectory = [paths objectAtIndex:0];
//        NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"mergeVideo-%d.mov",arc4random() % 1000]];
//        
//        NSURL *url = [NSURL fileURLWithPath:myPathDocs];
//        
//        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
//        exporter.outputURL=url;
//        exporter.outputFileType = AVFileTypeQuickTimeMovie;
//        exporter.videoComposition = MainCompositionInst;
//        exporter.shouldOptimizeForNetworkUse = YES;
//        [exporter exportAsynchronouslyWithCompletionHandler:^
//         {
//             dispatch_async(dispatch_get_main_queue(), ^{
//                 [self exportDidFinish:exporter];
//             });
//         }];
//    } else
//    else
//    {
//        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Sorry not enough videos to merge"  delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil, nil];
//        [alert show];
//    }
}

//- (void)exportDidFinish:(AVAssetExportSession*)session
//{
//    if(session.status == AVAssetExportSessionStatusCompleted){
//        NSURL *outputURL = session.outputURL;
//        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
//        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputURL]) {
//            [library writeVideoAtPathToSavedPhotosAlbum:outputURL
//                                        completionBlock:^(NSURL *assetURL, NSError *error){
//                                            dispatch_async(dispatch_get_main_queue(), ^{
//                                                if (error) {
//                                                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"  delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil, nil];
//                                                    [alert show];
//                                                }else{
//                                                    [self HideLoader];
//                                                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"  delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil];
//                                                    [alert show];
//                                                }
//                                                
//                                            });
//                                            
//                                        }];
//        }
//        
//    }
//
////    [self HideLoader];
////    audioAsset = nil;
////    firstAsset = nil;
////    secondAsset = nil;
//    [ActivityView stopAnimating];
//}

-(void)deleteTmpFile{
    
    NSURL *url = [NSURL fileURLWithPath:self.tmpVideoPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL exist = [fm fileExistsAtPath:url.path];
    NSError *err;
    if (exist) {
        [fm removeItemAtURL:url error:&err];
        NSLog(@"file deleted");
        if (err) {
            NSLog(@"file remove error, %@", err.localizedDescription );
        }
    } else {
        NSLog(@"no file by that name");
    }
}

- (IBAction)playMovie:(id)sender
{
//    videoFileUrl = [NSURL URLWithString:self.tmpVideoPath];
//    [self prepairVideoPlayer];
    [PlayButton setHidden:YES];
    [avPlayer setVolume:1];
    [avPlayer play];
}

-(void) pauseVideo
{
    [PlayButton setHidden:NO];
    [avPlayer pause];
}

- (void)showLoader
{
    
    NSLog(@"Enter Loader");
    
    HUD=[MBProgressHUD showHUDAddedTo:self.view animated:YES];
    UIFont *font = [UIFont fontWithName:@"Lato-Bold" size:14.0];
    HUD.labelFont = font;
    //    [self showWithSolidBackground];
}

- (void)HideLoader
{
    NSLog(@"Enter Loader");
    [HUD setHidden:YES];
}


#pragma mark - SAVideoRangeSliderDelegate

- (void)videoRange:(SAVideoRangeSlider *)videoRange didChangeLeftPosition:(CGFloat)leftPosition rightPosition:(CGFloat)rightPosition withDuration:(CGFloat)duration
{
    self.startTime = leftPosition;
    self.stopTime = rightPosition;
    videoTimeLbl.text = [NSString stringWithFormat:@"%f",duration];
    [self showTrimmedVideo:self];
}

#pragma mark - Helper methods


- (IBAction)longPressGestureRecognized:(id)sender {
    
    UILongPressGestureRecognizer *longPress = (UILongPressGestureRecognizer *)sender;
    UIGestureRecognizerState state = longPress.state;
    
    CGPoint location = [longPress locationInView:editorTableView];
    NSIndexPath *indexPath = [editorTableView indexPathForRowAtPoint:location];
    
    static UIView       *snapshot = nil;        ///< A snapshot of the row user is moving.
    static NSIndexPath  *sourceIndexPath = nil; ///< Initial index path, where gesture begins.
    
    switch (state) {
        case UIGestureRecognizerStateBegan: {
            if (indexPath) {
                sourceIndexPath = indexPath;
                
                UITableViewCell *cell = [editorTableView cellForRowAtIndexPath:indexPath];
                
                // Take a snapshot of the selected row using helper method.
                snapshot = [self customSnapshoFromView:cell];
                
                // Add the snapshot as subview, centered at cell's center...
                __block CGPoint center = cell.center;
                snapshot.center = center;
                snapshot.alpha = 0.0;
                [editorTableView addSubview:snapshot];
                [UIView animateWithDuration:0.25 animations:^{
                    
                    // Offset for gesture location.
                    center.y = location.y;
                    snapshot.center = center;
                    snapshot.transform = CGAffineTransformMakeScale(1.05, 1.05);
                    snapshot.alpha = 0.98;
                    cell.alpha = 0.0;
                    
                } completion:^(BOOL finished) {
                    
                    cell.hidden = YES;
                    
                }];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            CGPoint center = snapshot.center;
            center.y = location.y;
            snapshot.center = center;
            
            // Is destination valid and is it different from source?
            if (indexPath && ![indexPath isEqual:sourceIndexPath]) {
                
                // ... update data source.
                [self.VideoAssetArray exchangeObjectAtIndex:indexPath.row withObjectAtIndex:sourceIndexPath.row];
                
                // ... move the rows.
                [editorTableView moveRowAtIndexPath:sourceIndexPath toIndexPath:indexPath];
//
                // ... and update source so it is in sync with UI changes.
                sourceIndexPath = indexPath;
            }
            break;
        }
            
        default: {
            // Clean up.
            UITableViewCell *cell = [editorTableView cellForRowAtIndexPath:sourceIndexPath];
            cell.hidden = NO;
            cell.alpha = 0.0;
            
            [UIView animateWithDuration:0.25 animations:^{
                
                snapshot.center = cell.center;
                snapshot.transform = CGAffineTransformIdentity;
                snapshot.alpha = 0.0;
                cell.alpha = 1.0;
                
            } completion:^(BOOL finished) {
                
                sourceIndexPath = nil;
                [snapshot removeFromSuperview];
                snapshot = nil;
                
            }];
            break;
        }
    }
}


/** @brief Returns a customized snapshot of a given view. */
- (UIView *)customSnapshoFromView:(UIView *)inputView {
    
    // Make an image from the input view.
    UIGraphicsBeginImageContextWithOptions(inputView.bounds.size, NO, 0);
//    [inputView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Create an image view.
    UIView *snapshot = [[UIImageView alloc] initWithImage:image];
    snapshot.layer.masksToBounds = NO;
    snapshot.layer.cornerRadius = 0.0;
    snapshot.layer.shadowOffset = CGSizeMake(-5.0, 0.0);
    snapshot.layer.shadowRadius = 5.0;
    snapshot.layer.shadowOpacity = 0.4;
    
    return snapshot;
}


#pragma mark - YAScrollsegment Method

- (IBAction)addButtonClicked:(id)sender
{
    
    ELCImagePickerDemoViewController *customPickerObj = [self.storyboard instantiateViewControllerWithIdentifier:@"ELCImagePickerDemoViewControllerID"];
//    customPickerObj. = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"AddNewVideo"];
//    [self presentViewController:customPickerObj animated:YES completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)addUsingCodeClicked:(id)sender
{
    if ([self.view viewWithTag:11]) {
        [[self.view viewWithTag:11] removeFromSuperview];
    }
    
    
    YAScrollSegmentControl *segmentControl = [[YAScrollSegmentControl alloc] initWithFrame:CGRectMake(0, (self.view.frame.size.height - 40) / 2, self.view.frame.size.width, 40)];
    segmentControl.buttons = @[@"Button 1", @"Button 2", @"Button 3", @"Button 4", @"Button 5"];
    segmentControl.delegate = self;
    segmentControl.tag = 11;
    [segmentControl setBackgroundImage:[UIImage imageNamed:@"background"] forState:UIControlStateNormal];
    [segmentControl setBackgroundImage:[UIImage imageNamed:@"backgroundSelected"] forState:UIControlStateSelected];
    [segmentControl setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
    segmentControl.gradientColor = [UIColor redColor]; // Purposely set strange gradient color to demonstrate the effect
    
    [self.view addSubview:segmentControl];
}

- (IBAction)ShowSettings:(id)sender
{
    SettingsViewController *obj = [self.storyboard instantiateViewControllerWithIdentifier:@"SettingsViewControllerID"];
    [self presentViewController:obj animated:YES completion:nil];
}

- (void)didSelectItemAtIndex:(NSInteger)index
{
    NSLog(@"Button selected at index: %lu", (long)index);
}


- (void)viewDidUnload {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:nil forKey:@"ArrayOfAssets"];
    [userDefaults synchronize];
    [self setMyActivityIndicator:nil];
    [self setTrimBtn:nil];
    [super viewDidUnload];
}
@end
