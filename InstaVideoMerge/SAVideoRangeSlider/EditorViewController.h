//
//  EditorViewController.h
//
#import <UIKit/UIKit.h>
#import "SAVideoRangeSlider.h"
#import "SettingsViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "MBProgressHUD.h"
//#import "ELCImagePickerDemoViewController.h"

@class ELCImagePickerDemoViewController;


@interface EditorViewController : UIViewController<SAVideoRangeSliderDelegate>
{
    
    __weak IBOutlet UIView *preViewBack;
    __weak IBOutlet UIButton *pauseBtn;
    __weak IBOutlet UIButton *PlayButton;
    __weak IBOutlet UIImageView *VidPreViewImgView;
    __weak IBOutlet UITableView *editorTableView;
    MBProgressHUD* HUD;
    
    int numberOfFile;
    UIImage *myImage;
    CALayer *aLayer;
    CALayer *parentLayer;
    CALayer *videoLayer;
    
    IBOutlet UISlider* mScrubber;
    float mRestoreAfterScrubbingRate;
    BOOL seekToZeroBeforePlay;
    id mTimeObserver;
    BOOL isSeeking;


    
    __weak IBOutlet UIImageView *savebtnImgView;
    IBOutlet UILabel *lblDisp;
    __weak IBOutlet UIButton *saveBtnImg;

    AVAsset *avAsset;
    AVPlayerItem *avPlayerItem;
    AVPlayer *avPlayer;
    AVPlayerLayer *avPlayerLayer;
    NSUInteger selectedIndex;
    
    IBOutlet UILabel *videoTimeLbl;
}
@property(nonatomic,retain)AVAsset* firstAsset;
@property(nonatomic,retain)AVAsset* secondAsset;
@property(nonatomic,retain)AVAsset* audioAsset;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *ActivityView;
@property (nonatomic, strong) NSMutableArray *VideoAssetArray;
@end
