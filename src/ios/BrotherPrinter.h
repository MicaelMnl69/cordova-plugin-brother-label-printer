#import <ExternalAccessory/ExternalAccessory.h>
#import <Cordova/CDVPlugin.h>
#import "BRUserDefaults.h"
#import <BRLMPrinterKit/BRPtouchNetworkManager.h>
#import <BRLMPrinterKit/BRPtouchPrinterKit.h>
#import "BRBluetoothPrintOperation.h"
#import "BRWLANPrintOperation.h"
#import <BRLMPrinterKit/BRLMPrinterKit.h> // Assurez-vous d'importer BRLMPrinterKit

#define kPaperLabelName        @"paperLabelName"
#define kPrintNumberOfPaperKey		@"numberOfCopies"
#define kPrintOrientationKey		@"orientation"
#define kCustomPaperFilePath        @"customPaperFilePath"

static NSString *const IS_FINISHED_FOR_WLAN = @"isFinishedForWLAN";
static NSString *const COMMUNICATION_RESULT_FOR_WLAN = @"communicationResultForWLAN";


@interface BrotherPrinter : CDVPlugin<BRPtouchNetworkDelegate>
@property (retain, atomic) NSOperationQueue *operationQueue;

- (void)findNetworkPrinters:(CDVInvokedUrlCommand*)command;
- (void)findBluetoothPrinters:(CDVInvokedUrlCommand*)command;
- (void)findPrinters:(CDVInvokedUrlCommand*)command;
- (void)setPrinter:(CDVInvokedUrlCommand*)command;
- (void)printViaSDK:(CDVInvokedUrlCommand*)command;
@end