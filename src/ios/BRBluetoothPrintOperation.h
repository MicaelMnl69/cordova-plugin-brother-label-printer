//
//  BRBluetoothPrintOperation.h
//  SDK_Sample_Ver2
//
//  Created by Kusumoto Naoki on 2015/08/18.
//  Copyright (c) 2015年 Kusumoto Naoki. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <BRLMPrinterKit/BRPtouchPrinterKit.h>

@interface BRBluetoothPrintOperation : NSOperation {
}
@property(nonatomic, assign) BOOL communicationResultForBT;
@property(nonatomic, assign) PTSTATUSINFO resultStatus;

-(id)initWithOperation:(BRPtouchPrinter *)targetPtp
              printInfo:(BRPtouchPrintInfo *)targetPrintInfo
                 imgRef:(CGImageRef)targetImgRef
          numberOfPaper:(int)targetNumberOfPaper
           serialNumber:(NSString *)targetSerialNumber;
@end