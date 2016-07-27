//
//  ELCImagePickerDemoViewController.m
//  ELCImagePickerDemo
//
//  Created by ELC on 9/9/10.
//  Copyright 2010 ELC Technologies. All rights reserved.
//

#import "ELCImagePickerDemoViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "SettingsViewController.h"
#import "EditorViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>



@interface ELCImagePickerDemoViewController ()<UIImagePickerControllerDelegate>

@property (nonatomic, strong) ALAssetsLibrary *specialLibrary;

@end

@implementation ELCImagePickerDemoViewController


- (void) viewDidLoad
{
    NSLog(@"ViewDidLoad");
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:nil forKey:@"ArrayOfAssets"];
    [userDefaults synchronize];
    self.navigationController.navigationBarHidden = YES;
//    [self loadimagePicker];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [self launchController];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ShowSettings) name:@"showSetting" object:nil];
}


- (void)removeImage:(NSString *)fileName
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];
    NSError *error;
    BOOL success = [fileManager removeItemAtPath:filePath error:&error];
    if (success) {
        NSLog(@"Succesfully deleted file -:%@ ",filePath);
    }
    else
    {
        NSLog(@"Could not delete file -:%@ ",[error localizedDescription]);
    }
}

#pragma mark **************************
#pragma mark UIImagePickerViewController
#pragma mark **************************

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    // This is the NSURL of the video object
    [self dismissViewControllerAnimated:NO completion:nil];
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    
    if ([type isEqualToString:(NSString *)kUTTypeVideo] || [type isEqualToString:(NSString *)kUTTypeMovie])
    {
        NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
        
        NSLog(@"found a video");
        
        // Code To give Name to video and store to DocumentDirectory //
        
//        UIImage* image=[info objectForKey:UIImagePickerControllerOriginalImage];
//        
//        NSData *pngData = UIImagePNGRepresentation(image);
//        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//        NSString *documentsPath = [paths objectAtIndex:0]; //Get the docs directory
//        NSString *filePath = [documentsPath stringByAppendingPathComponent:@"image.png"]; //Add the file name
//        [pngData writeToFile:filePath atomically:YES]; //Write the file
        
        
        NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
        NSString *documentsDirectory = [paths objectAtIndex:0];
        
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"dd-MM-yyyy||HH:mm:SS"];
        NSDate *now = [[NSDate alloc] init];
        NSString *theDate = [dateFormat stringFromDate:now];
        
        NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"Default Album"];
        
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
            [[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:NO attributes:nil error:nil];
        
        NSString *videopath= [[NSString alloc] initWithString:[NSString stringWithFormat:@"%@/MyMovie.mov",documentsDirectory]];
        
        BOOL success = [videoData writeToFile:videopath atomically:NO];
        
        NSLog(@"Successs:::: %@", success ? @"YES" : @"NO");
        NSLog(@"video path --> %@",videopath);
        
        EditorViewController *obj = [self.storyboard instantiateViewControllerWithIdentifier:@"EditorViewControllerID"];
        [self.navigationController pushViewController:obj animated:YES];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:NULL];
}


-(void)loadimagePicker {
    
    UIImagePickerController *videoPicker = [[UIImagePickerController alloc] init];
    videoPicker.delegate = self;
    videoPicker.modalPresentationStyle = UIModalPresentationCurrentContext;
    videoPicker.mediaTypes =[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    videoPicker.editing = YES;
    
    //    videoPicker.mediaTypes = @[(NSString*)kUTTypeMovie];\
    
    videoPicker.mediaTypes = @[(NSString*)kUTTypeMovie, (NSString*)kUTTypeAVIMovie, (NSString*)kUTTypeVideo, (NSString*)kUTTypeMPEG4];
    videoPicker.videoQuality = UIImagePickerControllerQualityTypeHigh;
     [self addChildViewController:videoPicker];
     [self.view addSubview:videoPicker.view];
     [videoPicker didMoveToParentViewController:self];
    //    NSString *workSpacePath=[[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"image"];
    //    VidBackImage = [UIImage imageWithData:[NSData dataWithContentsOfFile:workSpacePath]];
}


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}
//Using generated synthesizers

- (void)ShowSettings
{
    SettingsViewController *obj = [self.storyboard instantiateViewControllerWithIdentifier:@"SettingsViewControllerID"];
    [self presentViewController:obj animated:YES completion:nil];
}

- (IBAction)launchController
{
	ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initImagePicker];

    elcPicker.maximumImagesCount = 9; //Set the maximum number of images to select to 100
    elcPicker.returnsOriginalImage = YES; //Only return the fullScreenImage, not the fullResolutionImage
    elcPicker.returnsImage = YES; //Return UIimage if YES. If NO, only return asset location information
    elcPicker.onOrder = YES; //For multiple image selection, display and return order of selected images
    elcPicker.mediaTypes = @[(NSString *)kUTTypeMovie]; //Supports image and movie types

	elcPicker.imagePickerDelegate = self;
    
//    [self presentViewController:elcPicker animated:NO completion:nil];
    
    [self addChildViewController:elcPicker];
    [self.view addSubview:elcPicker.view];
    [elcPicker didMoveToParentViewController:self];
    
}

- (IBAction)launchSpecialController
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    self.specialLibrary = library;
    NSMutableArray *groups = [NSMutableArray array];
    [_specialLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (group) {
            [groups addObject:group];
        } else {
            // this is the end
            [self displayPickerForGroup:[groups objectAtIndex:0]];
        }
    } failureBlock:^(NSError *error) {
        self.chosenImages = nil;
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Album Error: %@ - %@", [error localizedDescription], [error localizedRecoverySuggestion]] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        
        NSLog(@"A problem occured %@", [error description]);
        // an error here means that the asset groups were inaccessable.
        // Maybe the user or system preferences refused access.
    }];
}

- (void)displayPickerForGroup:(ALAssetsGroup *)group
{
	ELCAssetTablePicker *tablePicker = [[ELCAssetTablePicker alloc] initWithStyle:UITableViewStylePlain];
    tablePicker.singleSelection = YES;
    tablePicker.immediateReturn = YES;
    
	ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initWithRootViewController:tablePicker];
    elcPicker.maximumImagesCount = 2;
    elcPicker.imagePickerDelegate = self;
    elcPicker.returnsOriginalImage = YES; //Only return the fullScreenImage, not the fullResolutionImage
    elcPicker.returnsImage = YES; //Return UIimage if YES. If NO, only return asset location information
    elcPicker.onOrder = NO; //For single image selection, do not display and return order of selected images
	tablePicker.parent = elcPicker;
    
    // Move me
    tablePicker.assetGroup = group;
    [tablePicker.assetGroup setAssetsFilter:[ALAssetsFilter allVideos]];
    
    [self presentViewController:elcPicker animated:YES completion:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else {
        return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
    }
}

#pragma mark ELCImagePickerControllerDelegate Methods

- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
	
    if ([info count] >= 2)
    {
        CGRect workingFrame = _scrollView.frame;
        workingFrame.origin.x = 0;
        
        NSMutableArray *ArrayOfAssets = [info mutableCopy];
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        if (![userDefaults objectForKey:@"ArrayOfAssets"])
        {
            [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:ArrayOfAssets] forKey:@"ArrayOfAssets"];
            [userDefaults synchronize];
        }
        
        if ([userDefaults boolForKey:@"AddNewVideo"] == YES)
        {
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

            [userDefaults setBool:NO forKey:@"AddNewVideo"];
            
            NSData *data = [userDefaults objectForKey:@"ArrayOfAssets"];
            NSDictionary *retrievedDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            NSMutableArray *PrevVideos = [retrievedDictionary mutableCopy];
            
            for (int i = 0; i<=0; i++) {
                [PrevVideos addObject:[info objectAtIndex:i]
                 ];
            }
            ArrayOfAssets = [PrevVideos mutableCopy];
            [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:ArrayOfAssets] forKey:@"ArrayOfAssets"];
            [userDefaults synchronize];
        }
        
        EditorViewController *obj = [self.storyboard instantiateViewControllerWithIdentifier:@"EditorViewControllerID"];
        //        obj.VideoAssetArray = [info mutableCopy];
        [self.navigationController pushViewController:obj animated:YES];
    }
	else
    {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Please select at least two videos" message:nil delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    if ([userDefaults boolForKey:@"AddNewVideo"] == YES)
    {
        EditorViewController *obj = [self.storyboard instantiateViewControllerWithIdentifier:@"EditorViewControllerID"];
        //        obj.VideoAssetArray = [info mutableCopy];
        [self.navigationController pushViewController:obj animated:YES];
    }
    else
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}


@end
