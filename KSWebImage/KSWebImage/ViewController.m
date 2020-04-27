//
//  ViewController.m
//  KSWebImage
//
//  Created by KSummer on 2020/4/27.
//  Copyright © 2020 KSummer. All rights reserved.
//

#import "ViewController.h"
#import "UIImageView+KSWebCache.h"

@interface ViewController ()


@property (weak, nonatomic) IBOutlet UIImageView *testImage;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSString *picUrlString = @"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1587975630506&di=4f068ada1e821422189cf37ab9bbb6e6&imgtype=0&src=http%3A%2F%2Fa3.att.hudong.com%2F14%2F75%2F01300000164186121366756803686.jpg";
    [self.testImage ks_webImageWithUrl:picUrlString placeholder:nil];
    self.testImage.ks_imageUrl = @"11111";
    
}


@end
