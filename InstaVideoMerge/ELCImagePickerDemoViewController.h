//
//  ELCImagePickerDemoViewController.h
//  ELCImagePickerDemo
//
//  Created by ELC on 9/9/10.
//  Copyright 2010 ELC Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ELCImagePickerHeader.h"
#import "SettingsViewController.h"



@interface ELCImagePickerDemoViewController : UIViewController <ELCImagePickerControllerDelegate, UINavigationControllerDelegate, UIScrollViewDelegate>
{
}

@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, copy) NSArray *chosenImages;
@property (nonatomic) BOOL LoadmultipleVideosAgain;


// the default picker controller
- (IBAction)launchController;

// a special picker controller that limits itself to a single album, and lets the user
// pick just one image from that album.
- (IBAction)launchSpecialController;

@end

