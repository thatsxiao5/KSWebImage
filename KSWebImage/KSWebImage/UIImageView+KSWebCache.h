//
//  UIImageView+KSWebCache.h
//  KSWebImage
//
//  Created by KSummer on 2020/4/27.
//  Copyright © 2020 KSummer. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImageView (KSWebCache)

- (void)ks_webImageWithUrl:(NSString *)url placeholder:(nullable UIImage *)placeholder;

/* 下载的url*/
@property (nonatomic, copy) NSString *ks_imageUrl;

@end

NS_ASSUME_NONNULL_END
