#import "DocPickerViewController.h"


@interface DocPickerViewController ()

@property BOOL isUpload;

@property BOOL callImageFileCallback;

@end

@implementation DocPickerViewController

@synthesize isUpload = _isUpload;

- (void)openBoxApp :(CDVInvokedUrlCommand *)command {
    
    self.isUpload = false; // This function is for downloads
    self.callImageFileCallback = false;
    
    @try
    {
        self->supportedFormat = [command.arguments objectAtIndex:0];
        self->dirName = [command.arguments objectAtIndex:1];
        NSLog(@"openBoxApp: set self.dirName = '%@'", dirName);
        NSLog(@"openBoxApp: set self.supportedFormat = '%@'", supportedFormat);
        
        if ([supportedFormat containsString:@"jpeg"]) {
            NSLog(@"openBoxApp: supportedFormat is for image files!");
            self.callImageFileCallback = true;
        } else {
            NSLog(@"openBoxApp: supportedFormat is NOT for image files");
        }

        NSArray *supportedFormatInput = [supportedFormat componentsSeparatedByString:@","];
        UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:supportedFormatInput
                                                                                                                inMode:UIDocumentPickerModeImport];
        documentPicker.delegate = self;
        documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
        [self.viewController presentViewController:documentPicker animated:YES completion:nil];
    }
    @catch (NSException *e)
    {
        NSLog(@"openBoxApp: Error here --------> %@",e);
        
        [self.commandDelegate evalJs:[NSString stringWithFormat:@"boxAppAceessError('%@');",e]];
        //[(UIWebView*)self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"boxAppAceessError('%@');",e]];
    }
   
    
//    NSString *stringURL = @"itms-books:";
//    NSURL *url = [NSURL URLWithString:stringURL];
//    [[UIApplication sharedApplication] openURL:url];
    
}

-(void)viewDidAppear{
    NSLog(@"viewDidAppear---");
}

-(void)viewDidLoad{
     NSLog(@"viewDidLoad---");
}

-(NSString *)checkOutFileExist:(CDVInvokedUrlCommand *)command
{
    NSString *boxFileUploadPath=[command.arguments objectAtIndex:0];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fileExist=@"NO";
    
    if ([fileManager fileExistsAtPath:boxFileUploadPath]){
        NSLog(@"The file exist while checking in the folder path");
        fileExist=@"Exist";
        
    }else{
        NSLog(@"The file does not exist while checking in the folder path");

        
        fileExist=@"NO";

    }
    NSLog(@"Before sending back to js %@",fileExist);
    return fileExist;
}

                         
- (void)uploadFileToBox:(CDVInvokedUrlCommand *)command{
    
    self.isUpload = true;
    
    NSString *boxFileUploadPath=[command.arguments objectAtIndex:0];
    
    // Make sure file exists first.
    if (![[NSFileManager defaultManager] fileExistsAtPath:boxFileUploadPath]) {
        // Oops. The file doesn't exist.
        NSString* msg = [NSString stringWithFormat:@"File does not exist.\n%@",boxFileUploadPath];
        UIAlertController * alert=   [UIAlertController
                                      alertControllerWithTitle:@"Alert!"
                                      message:msg 
                                      preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* ok = [UIAlertAction
                             actionWithTitle:@"OK"
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                             }];
        [alert addAction:ok];
        [self.viewController presentViewController:alert animated:YES completion:nil];
        
        return;
    }
    
    NSURL *url = [NSURL fileURLWithPath:boxFileUploadPath];
    
    NSLog(@" 1 uploadFileToBox CALLED %@",url);
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURL:[url URLByStandardizingPath] inMode:UIDocumentPickerModeExportToService];
    NSLog(@" documentPicker initiated %@",documentPicker);
    documentPicker.delegate = self;
    NSLog(@" documentPicker initiated 1 [self.viewController dismissViewControllerAnimated:YES completion:nil];");
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    //[self.viewController dismissViewControllerAnimated:NO completion:nil];
    //    dispatch_async(dispatch_get_main_queue(), ^(void){
    //         [self.viewController presentViewController:documentPicker animated:NO completion:nil];
    //    });
    
    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.viewController presentViewController:documentPicker animated:NO completion:nil];
    });
    
    
    NSLog(@" documentPicker initiated 12");
    NSLog(@" File Uploaded to Box ");
    
}

- (void)uploadFileToBox:(NSURL *)url : (UIViewController *)controller{
    
    self.isUpload = true;
    
    NSLog(@" 2 uploadFileToBox CALLED %@",url);
 
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURL:[url URLByStandardizingPath] inMode:UIDocumentPickerModeExportToService];
    NSLog(@" documentPicker initiated %@",documentPicker);
    documentPicker.delegate = self;
    NSLog(@" documentPicker initiated 1 [self.viewController dismissViewControllerAnimated:YES completion:nil];");
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    //[self.viewController dismissViewControllerAnimated:NO completion:nil];
    //    dispatch_async(dispatch_get_main_queue(), ^(void){
    //         [self.viewController presentViewController:documentPicker animated:NO completion:nil];
    //    });
    
    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [controller presentViewController:documentPicker animated:NO completion:nil];
    });
    
    
    NSLog(@" documentPicker initiated 12");
    NSLog(@" File Uploaded to Box ");
    
}

/*
 * Handle passing selected file(s) back to app UI.
 * NOTE: this funtion API is defined by Apple.  This signature has been deprecated by Apple.
 *
 * @deprecated
 */
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
   
    //NSString *fileUrl = (NSString*)[url filePathURL];
    NSString *fileName = (NSString*)[url lastPathComponent];
    NSCharacterSet *doNotWant = [NSCharacterSet characterSetWithCharactersInString:@"#%;:?,/|\[]{}@$%^*"];
    fileName = [[fileName componentsSeparatedByCharactersInSet: doNotWant] componentsJoinedByString: @""];
    NSLog(@"didPickDocumentAtURL: the filename after removing special characters is %@", fileName);
    
  //  unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:nil] fileSize];
    [self copyFileToDocFolder:url];
    
    if (!self.isUpload) {
        [self.commandDelegate evalJs:[NSString stringWithFormat:@"boxFileCallback('%@');",fileName]];
    }
    else {
        [self.commandDelegate evalJs:[NSString stringWithFormat:@"boxUploadCallback('%@');",fileName]];
    }
    //[self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"boxFileCallback('%@');",fileName]];
}

/*
 * Handle passing selected file(s) back to app UI.
 *
 * Called via "[self.viewController ...", e.g line 30 in function openBoxApp:
 *     [self.viewController presentViewController:documentPicker animated:YES completion:nil];
 * NOTE: this funtion's signature is defined by Apple as part of interface DocPickerViewController
 */
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(nonnull NSArray<NSURL *> *)urlArray {

    // copy all (may only be one) selected files into documents folder for app.
    unsigned short int selectedCount = 0;
    for (NSURL* url in urlArray) {
        ++selectedCount;
        //NSString *fileUrl = (NSString*)[url filePathURL];
        NSString *fileName = (NSString*)[url lastPathComponent];
        NSCharacterSet *doNotWant = [NSCharacterSet characterSetWithCharactersInString:@"#%;:?,/|\[]{}@$%^*"];
        fileName = [[fileName componentsSeparatedByCharactersInSet: doNotWant] componentsJoinedByString: @""];
        NSLog(@"didPickDocumentsAtURLs: selectedCount = %hu | filename after removing special characters = '%@'", selectedCount, fileName);
        
        //  unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:nil] fileSize];
        [self copyFileToDocFolder:url];
    }

    NSURL* fileURL = [urlArray objectAtIndex:0]; // just get the first document in the array.
    NSString *fileName = (NSString*)[fileURL lastPathComponent];
    NSCharacterSet *doNotWant = [NSCharacterSet characterSetWithCharactersInString:@"#%;:?,/|\[]{}@$%^*"];
    fileName = [[fileName componentsSeparatedByCharactersInSet: doNotWant] componentsJoinedByString: @""];

    if (!self.isUpload) {
        // callback functions are in doclist.js.
        if (!self.callImageFileCallback) {
            NSLog(@"didPicksDocumentAtURLs: call boxFileCallback with = '%@'", fileName);
            [self.commandDelegate evalJs:[NSString stringWithFormat:@"boxFileCallback('%@');", fileName]];
        } else {
            NSLog(@"didPicksDocumentAtURLs: call boxFileCallbackForImageFiles with = '%@'", fileName);
            [self.commandDelegate evalJs:[NSString stringWithFormat:@"boxFileCallbackForImageFiles('%@');", fileName]];
        }
    }
    else {
        [self.commandDelegate evalJs:[NSString stringWithFormat:@"boxUploadCallback('%@');",fileName]];
    }
}

- (void) correctImageOrientation:(CDVInvokedUrlCommand *)command{
    
    NSString *filePath = [command.arguments objectAtIndex:0];
    NSURL *url = [[NSURL alloc] initWithString:filePath];
    NSString *fileName = (NSString*)[url lastPathComponent];
    
    NSURL *destinationURL = [self correctImageOrientationWithPath:filePath];
    
    NSString *fileUrl = (NSString*)[destinationURL filePathURL];
    
    [self.commandDelegate evalJs:[NSString stringWithFormat:@"boxFileCallbackAfterImageOrientationCorrection('%@','%@');",fileUrl,fileName]];
    //[self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"boxFileCallbackAfterImageOrientationCorrection('%@','%@');",fileUrl,fileName]];
}

- (NSURL *) correctImageOrientationWithPath:(NSString *)filePath{
   
    NSURL *url = [[NSURL alloc] initWithString:filePath];
   // NSString *fileUrl = (NSString*)[url filePathURL];
    NSString *fileName = (NSString*)[url lastPathComponent];
    
    NSData *imageData = [NSData dataWithContentsOfURL:url];
    UIImage *image = [UIImage imageWithData:imageData];
    
    UIImage *rotatedImage = [self fixrotation:image];
    
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *geBoxImageDirectory = [documentsDirectory stringByAppendingPathComponent:@"GEBoxImages"];
    NSString *imageFileDestination = [geBoxImageDirectory stringByAppendingPathComponent:fileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL success = [fileManager removeItemAtPath:geBoxImageDirectory error:nil];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:geBoxImageDirectory]){
        [[NSFileManager defaultManager] createDirectoryAtPath:geBoxImageDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    else
    {
        NSLog(@"geBoxImageDirectory dir exists");
        //        NSFileManager *fileManager = [NSFileManager defaultManager];
        //        BOOL success = [fileManager removeItemAtPath:imageFileDestination error:nil];
        //        NSLog(@"image deleted %hhd",success);
        
    }
    
    NSData *rotatedImageData = UIImageJPEGRepresentation(rotatedImage, 0.25);
    [rotatedImageData writeToFile:imageFileDestination atomically:YES];
    
    NSURL *destinationUrl = [NSURL fileURLWithPath:imageFileDestination];
    
    return destinationUrl;
}

- (void)copyFileToAttachmentFolder:(CDVInvokedUrlCommand *)command{
    
     NSString *stringUrl = [command.arguments objectAtIndex:0];
     NSURL *url = [[NSURL alloc] initWithString:stringUrl];
     NSString *fileUrl = (NSString*)[url filePathURL];
     NSString *fileName = (NSString*)[url lastPathComponent];
    
     NSString *fileExtension = [fileName pathExtension];
    
    
    if([fileExtension isEqualToString:@"JPEG"] || [fileExtension isEqualToString:@"JPG"] || [fileExtension isEqualToString:@"PNG"] || [fileExtension isEqualToString:@"jpeg"] || [fileExtension isEqualToString:@"jpg"] || [fileExtension isEqualToString:@"png"]){
        url = [self correctImageOrientationWithPath:stringUrl];
    }
   
    if ( [[NSFileManager defaultManager] isReadableFileAtPath:fileUrl] )
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *destination = documentsDirectory;//[documentsDirectory stringByAppendingPathComponent:@"/Attachments"];
        NSLog(@"destination 1 created is %@",destination);

       if(![[NSFileManager defaultManager] fileExistsAtPath:destination]){
            [[NSFileManager defaultManager] createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:NULL];
            NSLog(@"dir created");
        }
        else
        {
           NSLog(@"dir exists");
        }
        
        
        NSString *destination2 = [destination stringByAppendingPathComponent:fileName];
        NSURL *destinationUrl = [NSURL fileURLWithPath:destination2];
        [[NSFileManager defaultManager] copyItemAtPath:[url path] toPath: destination2 error:nil];
        NSDictionary *attributesDict=[[NSFileManager defaultManager] attributesOfItemAtPath:[destinationUrl path] error:NULL];
        long long fileSize=[attributesDict fileSize];
       
        //[self.commandDelegate evalJs:[NSString stringWithFormat:@"smout.reportbuilder.taskitem.reportAttachment.attachmentCopyCallBack('%@','%@');",destinationUrl,fileName]];
        //[self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"smout.reportbuilder.taskitem.reportAttachment.attachmentCopyCallBack('%@','%@');",destinationUrl,fileName]];
        
    }else{
        NSLog(@" FILE IS NOT READABLE ");
    }
    
}


- (bool)copyFileToDocFolder:(NSURL *)command {
    
    //NSString *stringUrl = [command.arguments objectAtIndex:0];
    NSURL *url = command;//[[NSURL alloc] initWithString:stringUrl];
    NSString *fileUrl = (NSString*)[url filePathURL];
    NSString *fileName = (NSString*)[url lastPathComponent];
    NSCharacterSet *doNotWant = [NSCharacterSet characterSetWithCharactersInString:@"#%;:?,/|\[]{}@$%^*"];
    fileName = [[fileName componentsSeparatedByCharactersInSet: doNotWant] componentsJoinedByString: @""];
    NSLog(@"copyFileToDocFolder: the filename after removing special characters is %@", fileName);
    // Leave file name as is.  When using SpreaddJS server to convert file to JSON, this was not an issue.
    // Now that we convert .xlsx file to .json on the fly, forcing file name to lower case causes issues.
    //fileName=[fileName lowercaseString];
    
    //Memory Management :-
   // NSString *fileExtension = [fileName pathExtension];
    
    if ( [[NSFileManager defaultManager] isReadableFileAtPath:fileUrl] )
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *destination = [documentsDirectory stringByAppendingPathComponent:dirName];
        NSLog(@"copyFileToDocFolder: documentsDirectory + dirName = %@ | fileName = '%@'", destination, fileName);

        if(![[NSFileManager defaultManager] fileExistsAtPath:destination]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:NULL];
            NSLog(@"copyFileToDocFolder: dir %@ created", destination);
        } else {
            NSLog(@"copyFileToDocFolder: dir %@ exists", destination);
        }
        

        NSString *destination2 = [destination stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] copyItemAtPath:[url path] toPath: destination2 error:nil];

        // NSURL *destinationUrl = [NSURL fileURLWithPath:destination2];
        //NSDictionary *attributesDict=[[NSFileManager defaultManager] attributesOfItemAtPath:[destinationUrl path] error:NULL];
        //long long fileSize=[attributesDict fileSize];
        
        //[self.commandDelegate evalJs:[NSString stringWithFormat:@"smout.reportbuilder.taskitem.reportAttachment.attachmentCopyCallBack('%@','%@');",destinationUrl,fileName]];
        //[self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"smout.reportbuilder.taskitem.reportAttachment.attachmentCopyCallBack('%@','%@');",destinationUrl,fileName]];

        return true;
        
    }else {
        NSLog(@" FILE IS NOT READABLE: %@", fileUrl);
        return false;
    }

}


- (UIImage *)fixrotation:(UIImage *)image{
    
    
    if (image.imageOrientation == UIImageOrientationUp) return image;
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (image.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, image.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, image.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (image.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, image.size.width, image.size.height,
                                             CGImageGetBitsPerComponent(image.CGImage), 0,
                                             CGImageGetColorSpace(image.CGImage),
                                             CGImageGetBitmapInfo(image.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (image.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,image.size.height,image.size.width), image.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,image.size.width,image.size.height), image.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}



/*
 *
 * Cancelled
 *
 */
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSLog(@"Cancelled");
    self.isUpload = false;
    [self.commandDelegate evalJs:[NSString stringWithFormat:@"boxUploadCallback('');"]];
}

@end
