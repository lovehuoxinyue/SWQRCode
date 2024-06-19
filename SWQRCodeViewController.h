//
//  SWQRCodeViewController.h
//  SWQRCode_Objc
//
//  Created by zhuku on 2018/4/4.
//  Copyright © 2018年 selwyn. All rights reserved.
//

#import "SWQRCode.h"

typedef void(^SCANRESULTBLOCK)(NSString *value);

@interface SWQRCodeViewController : UIViewController

@property (nonatomic, strong) SWQRCodeConfig *codeConfig;

- (void)scanResult:(SCANRESULTBLOCK)block;

@end
