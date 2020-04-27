//
//  ImageLoadOperation.m
//  KSWebImage
//
//  Created by KSummer on 2020/4/27.
//  Copyright © 2020 KSummer. All rights reserved.
//

#import "ImageLoadOperation.h"
#import "UIImageView+KSWebCache.h"
#import <CommonCrypto/CommonDigest.h>

typedef BOOL (^CancleBlock)(void);

static NSCache *_ksImageCache;
@implementation ImageLoadOperation
@synthesize finished = _finished;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ksImageCache = [NSCache new];
    });
}

- (void)start {
    [self main];
}

- (void)main {
    
    CancleBlock isCancelBlock = ^BOOL () {
        BOOL cancel = NO;

        if (!self.imageView) {
            cancel = YES;
        } else if (![self.imageView.ks_imageUrl isEqualToString:self.imageUrl]) {
            cancel = YES;
        }

        return cancel;
    };

    // 1.查找缓存.首先我们不去管,缓存是什么

    NSData *imageData = [self cacheForKey:self.imageUrl];

    if (imageData) {
        if (!isCancelBlock) {
            [self mainThreadLoadImage:[UIImage imageWithData:imageData]];
        }
    } else {
        // 2.没有缓存就去下载

        // 2.1下载
        imageData = [self netLoadImageWithUrl:self.imageUrl];
        // 2.2 bitmap处理
        UIImage *bitmapImage = [self bitmapFormImage:[UIImage imageWithData:imageData]];
        // 2.3 保存
        NSData *bitmapData = UIImageJPEGRepresentation(bitmapImage, 1);
        [self saveBitmapImageData:bitmapData url:self.imageUrl];
        // 2.4. 找到缓存或者下载完成,给imageView赋值
        if (!isCancelBlock()) {
            [self mainThreadLoadImage:bitmapImage];
        }
    }

    // 3.结束operation
    [self finishStatus];
}

#pragma mark - Search Cache 查找缓存

- (NSData *)cacheForKey:(NSString *)key {
    // 1.首先从内存中查找
    NSData *imageData = [_ksImageCache objectForKey:[self md5FormString:key]];
    // 2.然后从文件中查找
    if (!imageData) {
        imageData = [self findImageFromKey:key];
    }

    // 3.返回NSData
    return imageData;
}

// 默认放到沙盒的document下面
- (NSData*)findImageFromKey:(NSString*)url{
    
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    NSString *filePath = [documentPath stringByAppendingPathComponent:[self md5FormString:url]];
    
    return [NSData dataWithContentsOfFile:filePath];
}


- (void)saveBitmapImageData:(NSData *)bitmapData url:(NSString *)url {
    // 1.存入内存
    [_ksImageCache setObject:bitmapData forKey:url];
    // 2.存入文件缓存
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentPath stringByAppendingPathComponent:[self md5FormString:url]];
    [bitmapData writeToFile:filePath atomically:YES];

    // 3.考虑文件读取的安全性
    // 4.考虑内存大小限制,考虑文件删除策略
}

#pragma mark - netWorkLoad relative 下载图片相关

- (NSData *)netLoadImageWithUrl:(NSString *)url {
    // 如果你需要在block中对一个对象赋值,那么你要使用__block修饰
    __block NSData *imageData = nil;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionTask *task = [session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        imageData = data;
        if (error) {
            NSLog(@"网络异常: %@", error);
        }

        dispatch_semaphore_signal(semaphore);
    }];

    [task resume];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return imageData;
}

#pragma mark - finish the operation 结束任务
// 手动KVO
- (void)finishStatus {
    [self willChangeValueForKey:@"finished"];
    _finished = YES;
    [self didChangeValueForKey:@"finished"];
}

#pragma mark - bitmap image transform 将image 转化为 bitmap

- (UIImage *)bitmapFormImage:(UIImage *)targetImage {
    // image -> CGImage
    CGImageRef imageRef = targetImage.CGImage;
    //上下文
    CGContextRef contextRef =  CGBitmapContextCreate(NULL, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef), CGImageGetBitsPerComponent(imageRef), CGImageGetBytesPerRow(imageRef), CGImageGetColorSpace(imageRef), CGImageGetBitmapInfo(imageRef));
    //上下文绘制image
    CGContextDrawImage(contextRef, CGRectMake(0, 0, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef)), imageRef);
    // bitmap
    CGImageRef bitmapRef = CGBitmapContextCreateImage(contextRef);
    // 又变成image
    UIImage *bitmapImage = [UIImage imageWithCGImage:bitmapRef];
    // 需要我们手动管理内存.注意
    CFRelease(bitmapRef);
    // 结束上下文绘制
    UIGraphicsEndImageContext();
    return bitmapImage;
}

#pragma mark - MD5 使用MD5对文件名进行加密处理

- (NSString *)md5FormString:(NSString *)target {
    if (target.length == 0) {
        return nil;
    }

    const char *original_string = [target UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(original_string, (unsigned int)strlen(original_string), original_string);
    NSMutableString *hash = [NSMutableString string];

    for (int i = 0; i < 16; i++) {
        [hash appendFormat:@"%02X", result[i]];
    }

    return [hash lowercaseString];
}

#pragma mark - document relative  目录相关

- (NSData *)searchImageForKey:(NSString *)url {
    if (!url || !url.length) {
        return nil;
    }

    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentPath stringByAppendingPathComponent:[self md5FormString:url]];
    return [NSData dataWithContentsOfFile:filePath];
}

#pragma mark - mainThread show image

- (void)mainThreadLoadImage:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = image;
    });
}

@end
