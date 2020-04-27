//
//  UIImageView+KSWebCache.m
//  KSWebImage
//
//  Created by KSummer on 2020/4/27.
//  Copyright © 2020 KSummer. All rights reserved.
//

#import "UIImageView+KSWebCache.h"
#import "ImageLoadOperation.h"
#import <objc/runtime.h>

/*
 1.缓存加载
 2.子线程执行
 3.图片下载
 4.图片解压
 5.回到主线程执行
 */

static NSOperationQueue *_ksImageOperationQueue;

@implementation UIImageView (KSWebCache)

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ksImageOperationQueue = [[NSOperationQueue alloc] init];
        // 设置最大并发数量为6
        _ksImageOperationQueue.maxConcurrentOperationCount = 6;
    });
}

- (void)ks_webImageWithUrl:(NSString *)url placeholder:(nullable UIImage *)placeholder {
    self.image = placeholder;
    self.ks_imageUrl = url;

    ImageLoadOperation *operation = [[ImageLoadOperation alloc] init];
    operation.imageUrl = url;
    operation.imageView = self;
    [_ksImageOperationQueue addOperation:operation];
}

#pragma mark - Category setter getter

static char _ks_imageUrl;

- (NSString *)ks_imageUrl {
    return objc_getAssociatedObject(self, &_ks_imageUrl);
}

- (void)setKs_imageUrl:(NSString *)ks_imageUrl {
    objc_setAssociatedObject(self, &_ks_imageUrl, ks_imageUrl, OBJC_ASSOCIATION_COPY);
}

@end
