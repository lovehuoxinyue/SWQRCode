//
//  SWQRCodeViewController.m
//  SWQRCode_Objc
//
//  Created by zhuku on 2018/4/4.
//  Copyright © 2018年 selwyn. All rights reserved.
//

#import "SWQRCodeViewController.h"
#import "SWScannerView.h"
#import "NSArray+Map.h"

@interface SWQRCodeViewController ()<AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

/** 扫描器 */
@property (nonatomic, strong) SWScannerView *scannerView;
@property (nonatomic, strong) AVCaptureSession *session;

@property (nonatomic, strong) SCANRESULTBLOCK oldBlock;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@end

@implementation SWQRCodeViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (SWScannerView *)scannerView
{
    if (!_scannerView) {
        _scannerView = [[SWScannerView alloc]initWithFrame:self.view.bounds config:_codeConfig];;
    }
    return _scannerView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *naviTopView = [UIView new];
    naviTopView.frame = CGRectMake(0, -kNavBarH, kScreenWidth, kNavBarH);
    naviTopView.backgroundColor = kNavBGColor;
    [self.view addSubview:naviTopView];
    self.navigationItem.title = [SWQRCodeManager sw_navigationItemTitleWithType:self.codeConfig.scannerType];
    UIButton * btnClose = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnClose setFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
    [btnClose setContentEdgeInsets:UIEdgeInsetsMake(0.0f, -18.0f, 0.0f, 14.0f)];
    [btnClose eiImageName2x:@"live_back" forState:UIControlStateNormal];
    [btnClose addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:btnClose];
    [self _setupUI];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [UIImage loadWithBlock2x:@"public_back" Image:^(UIImage * _Nonnull imageBlock) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[imageBlock imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] style:(UIBarButtonItemStylePlain) target:self action:@selector(back)];
    }];
    
}

- (void)back;
{
    // 判断两种情况: push 和 present
    if ((self.navigationController.presentedViewController || self.navigationController.presentingViewController) && self.navigationController.childViewControllers.count == 1)
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self resumeScanning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.scannerView sw_setFlashlightOn:NO];
    [self.scannerView sw_hideFlashlightWithAnimated:YES];
}

- (void)_setupUI {
    
    self.view.backgroundColor = [UIColor blackColor];
    UIBarButtonItem *albumItem = [[UIBarButtonItem alloc]initWithTitle:@"相册" style:UIBarButtonItemStylePlain target:self action:@selector(showAlbum)];
    [albumItem setTintColor:kGreyColor];
    self.navigationItem.rightBarButtonItem = albumItem;
    
    [self.view addSubview:self.scannerView];
    
    // 校验相机权限
    [SWQRCodeManager sw_checkCameraAuthorizationStatusWithGrand:^(BOOL granted) {
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self _setupScanner];
            });
        }
    }];
}

/** 创建扫描器 */
- (void)_setupScanner {
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    if (self.codeConfig.scannerArea == SWScannerAreaDefault) {
        metadataOutput.rectOfInterest = CGRectMake([self.scannerView scanner_y]/self.view.frame.size.height, [self.scannerView scanner_x]/self.view.frame.size.width, [self.scannerView scanner_width]/self.view.frame.size.height, [self.scannerView scanner_width]/self.view.frame.size.width);
    }
    
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    self.session = [[AVCaptureSession alloc]init];
    [self.session setSessionPreset:AVCaptureSessionPresetHigh];
    if ([self.session canAddInput:deviceInput]) {
        [self.session addInput:deviceInput];
    }
    if ([self.session canAddOutput:metadataOutput]) {
        [self.session addOutput:metadataOutput];
    }
    if ([self.session canAddOutput:videoDataOutput]) {
        [self.session addOutput:videoDataOutput];
    }

    NSArray<AVMetadataObjectType>* metadataObjectTypes = [SWQRCodeManager sw_metadataObjectTypesWithType:self.codeConfig.scannerType];
    metadataObjectTypes = [metadataObjectTypes filter:^BOOL(AVMetadataObjectType _Nonnull obj) {
        return [metadataOutput.availableMetadataObjectTypes containsObject:obj];
    }];
    metadataOutput.metadataObjectTypes = metadataObjectTypes;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    videoPreviewLayer.frame = self.view.layer.bounds;
    [self.view.layer insertSublayer:videoPreviewLayer atIndex:0];
    WEAKSELF
    dispatch_async(self.sessionQueue, ^{
        if (!weakSelf.session.running) {
            [weakSelf.session startRunning];
        }
    });
}
- (dispatch_queue_t)sessionQueue{
    if (!_sessionQueue) {
        _sessionQueue = dispatch_queue_create("gqcode.session.queue", DISPATCH_QUEUE_SERIAL);
    }
    return _sessionQueue;;
}

#pragma mark -- 跳转相册
- (void)imagePicker {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc]init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark -- AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    // 获取扫一扫结果
    if (metadataObjects && metadataObjects.count > 0) {
        
        [self pauseScanning];
        AVMetadataMachineReadableCodeObject *metadataObject = metadataObjects[0];
        NSString *stringValue = metadataObject.stringValue;
        
        [self sw_handleWithValue:stringValue];
    }
}

#pragma mark -- AVCaptureVideoDataOutputSampleBufferDelegate
/** 此方法会实时监听亮度值 */
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
    CFRelease(metadataDict);
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    
    // 亮度值
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    
    if (![self.scannerView sw_flashlightOn]) {
        if (brightnessValue < -4.0) {
            [self.scannerView sw_showFlashlightWithAnimated:YES];
        }else
        {
            [self.scannerView sw_hideFlashlightWithAnimated:YES];
        }
    }
}

- (void)showAlbum {
    // 校验相册权限
    [SWQRCodeManager sw_checkAlbumAuthorizationStatusWithGrand:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                [self imagePicker];
            }
        });
    }];
}

#pragma mark -- UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    UIImage *pickImage = info[UIImagePickerControllerOriginalImage];
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    // 获取选择图片中识别结果
    NSArray *features = [detector featuresInImage:[CIImage imageWithData:UIImagePNGRepresentation(pickImage)]];
    
    [picker dismissViewControllerAnimated:YES completion:^{
        if (features.count > 0) {
            CIQRCodeFeature *feature = features[0];
            NSString *stringValue = feature.messageString;
            [self sw_handleWithValue:stringValue];
        }
        else {
            [self sw_didReadFromAlbumFailed];
        }
    }];
}

#pragma mark -- App 从后台进入前台
- (void)appDidBecomeActive:(NSNotification *)notify {
    [self resumeScanning];
}

#pragma mark -- App 从前台进入后台
- (void)appWillResignActive:(NSNotification *)notify {
    [self pauseScanning];
}

/** 恢复扫一扫功能 */
- (void)resumeScanning {
    if (self.session) {
        [self.session startRunning];
        [self.scannerView sw_addScannerLineAnimation];
    }
}


/** 暂停扫一扫功能 */
- (void)pauseScanning {
    if (self.session) {
        [self.session stopRunning];
        [self.scannerView sw_pauseScannerLineAnimation];
    }
}

- (void)scanResult:(SCANRESULTBLOCK)block {
    self.oldBlock = block;
}

#pragma mark -- 扫一扫API
/**
 处理扫一扫结果
 @param value 扫描结果
 */
- (void)sw_handleWithValue:(NSString *)value {
    NSLog(@"sw_handleWithValue === %@", value);
    [self back];
    if (self.oldBlock) {
        self.oldBlock(value);
    }
}

/**
 相册选取图片无法读取数据
 */
- (void)sw_didReadFromAlbumFailed {
    [MessageBox showMessage:@"扫码失败"];
}

@end
