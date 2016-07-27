//
//  EditorTableViewCell.h
//  InstaVideoMerge
//
//  Created by DEEPINDERPAL SINGH on 24/02/16.
//  Copyright © 2016 Dimonds Infosys Pvt Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditorTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *VideoThumbImgView;
@property (weak, nonatomic) IBOutlet UIView *SliderBackView;
@property (weak, nonatomic) IBOutlet UIButton *deleteBtn;

@end
