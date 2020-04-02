#import <UIKit/UIKit.h>
#import <Cordova/CDVPlugin.h>

@interface DocPickerViewController :  CDVPlugin <UIDocumentPickerDelegate>
{
    NSString *supportedFormat;
    NSString *dirName;
}

- (void)openBoxApp :(CDVInvokedUrlCommand *)command;
- (void)uploadFileToBox :(NSURL *)url;
- (void)uploadFileToBox:(NSURL *)url : (UIViewController *)controller;
-(NSString *)checkOutFileExist:(CDVInvokedUrlCommand *)command;


@end

