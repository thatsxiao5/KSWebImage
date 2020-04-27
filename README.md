#简单实现SDWebImage核心功能

--

###前言
相信在最开始学习iOS的时候, SDWebImage的使用就成为了各个小伙伴必备的开发技能.它使用简单,而且性能优越,作者为了考虑兼容性,即使是大的版本迭代,也没有更改过上层Api,同时作者已经适配了Swift版本,使得千千万万个小伙伴使用轮子的时候毫无顾虑.向开源作者致敬[SDWebImage](https://github.com/SDWebImage/SDWebImage).虽然在社区中有很多人去解析了SDWebImage,但是我还是想通过自己的理解,把SDWebImage的核心思想再总结一次,首先帮助自己感悟作者的架构设计,如果能够帮助到哪个小伙伴也算是结下善缘.在这里感谢八点钟学院的老师们,感谢你们的课程.

###SDWebImage核心功能到底有哪些?
其实,SDWebImage核心功能主要是包括了网络下载、缓存和解压，大致过程为：
![](/Users/ksummer/Desktop/sdwebImage.png)

1. 查找缓存.
2. 没有缓存就去下载,下载完成存储缓存.
3. 给图片进行赋值

### 主要技术点
1. 缓存加载 
2. 子线程执行
3. 图片下载
4. 图片解压
5. 回到主线程执行

--
之后我们分步按照代码逻辑来实现一下具体功能:

#### 按照SD的思想,方便我们使用,我们首先定义一个Category:

```

@interface UIImageView (KSWebCache)

/**
 * url:图片地址
 * placeholder: 占位
 */
- (void)ks_webImageWithUrl:(NSString *)url placeholder:(nullable UIImage *)placeholder;

@end

```

以上我们没有提供更多的对外接口,当然可以自己进行拓展

我们首先考虑一下图片下载:我们的业务场景中图片的下载是使用NSURLSession,我们可能会有多个图片同时进行下载,所以考虑定义一个ImageLoadOperation 继承于NSOperation 自己手动去管理线程状态,同时去重写start|main方法,可以结合NSOperationQueue设置并发数,下载完成后finish这个ImageLoadOperation.

```

//自定义一个NSOperation
@interface ImageLoadOperation : NSOperation

@end

//内存缓存NSCache 它本身是线程安全的
static NSCache *_ksImageCache;

@implementation ImageLoadOperation

// 重写了属性关联的变量名 //操作的是成员变量
@synthesize finished = _finished;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ksImageCache = [NSCache new];
    });
}

//重写start方法
- (void)start {
	 //main之前可以做准备操作
    [self main];
}

- (void)main {

	//任务完成之后,需要finish线程
   [self finishStatus];
}

#pragma mark - finish the operation 结束任务
// 手动KVO
- (void)finishStatus {
    [self willChangeValueForKey:@"finished"];
    _finished = YES;
    [self didChangeValueForKey:@"finished"];
}

```

以上是我们对后台下载图片进行的准备工作

####下载

我们使用NSSession对图片进行下载,下载图片的时候要注意同步操作,用信号量保证return的是正确的结果,因为NSURLSessionTask并不能保证何时完成回调,如果不加信号量,将会直接返回nil,然后将下载后的imageData转化为bitmap

```
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
```

image转化为bitmap

```
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

```

主要步骤:

```
      // 2.1下载
      imageData = [self netLoadImageWithUrl:self.imageUrl];
      // 2.2 bitmap处理
      UIImage *bitmapImage = [self bitmapFormImage:[UIImage imageWithData:imageData]];
      // 2.3 转化
      NSData *bitmapData = UIImageJPEGRepresentation(bitmapImage, 1);

```

不考虑前置判断的情况下,我们第一次下载完一张图片,将它的格式转化为了bitmap,那么接下来的操作应该是进行缓存了...


#### 缓存: 内存缓存和文件缓存

NSCache 是线程安全的,而且它本身提供了特别简单的缓存方式,类似于NSDictionary

```
[_memCache setObject:obj forKey:key];
```

文件缓存同样需要一个文件名

```
NSString *filePath = [documentPath strigByAppendingPathComponent:path];

```
以url作为唯一key,我们将两者进行统一,用同一个关键字进行内存缓存和文件缓存的增删改查操作,为了安全起见,我们将key进行MD5加密,防止出现冲突

```
#pragma mark - MD5 使用MD5对文件名进行加密处理

//target是图片的url
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
```

有了MD5加密之后我们就可以进行缓存操作了:

```
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
```

如何读取,也很简单

```
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
```

至此,我们已经完成很图片的下载,内存缓存,文件缓存.现在考虑一种场景,我们在网络下载的过程中,imageView被释放了,那么我们如何去做?NSSession已经在执行任务,图片下载还在继续.我们不考虑取消下载的情况下,应该将图片的赋值取消.

图片赋值

```
#pragma mark - mainThread show image

- (void)mainThreadLoadImage:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = image;
    });
}
```

所以完整的main执行应该是这样的

```
 - (void)main {
    
    CancleBlock isCancelBlock = ^BOOL () {
        BOOL cancel = NO;

        if (!self.imageView) {
            cancel = YES;
        } else if (![self.imageView.ks_imageUrl isEqualToString:self.imageUrl]) {
            cancel = YES;
        }

        return cancel;
    };//当cancel == YES,取消赋值操作

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


```

以上就是SDWebImage核心自己去实现的全部流程,当然此Demo并没有考虑内存和磁盘大小,以及根据LRU策略进行缓存管理的情况,关于LRU找个合适时间我再总结一下.








