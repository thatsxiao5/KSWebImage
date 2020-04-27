//
//  ImageLoadOperation.h
//  KSWebImage
//
//  Created by KSummer on 2020/4/27.
//  Copyright © 2020 KSummer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageLoadOperation : NSOperation

/* imageUrl*/
@property (nonatomic, strong) NSString *imageUrl;

/* imageView*/
@property (nonatomic, weak) UIImageView *imageView;


@end

NS_ASSUME_NONNULL_END
