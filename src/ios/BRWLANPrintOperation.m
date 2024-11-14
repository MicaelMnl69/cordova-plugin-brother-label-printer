//
//  BRWLANPrintOperation.m
//  SDK_Sample_Ver2
//
//  Created by Kusumoto Naoki on 2015/08/18.
//  Copyright (c) 2015年 Kusumoto Naoki. All rights reserved.
//

#import "BRUserDefaults.h"
#import "BRWLANPrintOperation.h"

@interface BRWLANPrintOperation () {
}
@property(nonatomic, assign) BOOL isExecutingForWLAN;
@property(nonatomic, assign) BOOL isFinishedForWLAN;

@property(nonatomic, weak) BRPtouchPrinter *ptp;
@property(nonatomic, strong) BRPtouchPrintInfo *printInfo;
@property(nonatomic, assign) CGImageRef imgRef;
@property(nonatomic, assign) int numberOfPaper;
@property(nonatomic, strong) NSString *ipAddress;

@end

@implementation BRWLANPrintOperation

@synthesize resultStatus = _resultStatus;
@synthesize errorCode = _errorCode;
@synthesize dict = _dict;


- (id)initWithOperation:(BRPtouchPrinter *)targetPtp
              printInfo:(BRPtouchPrintInfo *)targetPrintInfo
                 imgRef:(CGImageRef)targetImgRef
          numberOfPaper:(int)targetNumberOfPaper
              ipAddress:(NSString *)targetIPAddress
               withDict:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        self.ptp = targetPtp;
        self.printInfo = targetPrintInfo;
        self.imgRef = targetImgRef;
        self.numberOfPaper = targetNumberOfPaper;
        self.ipAddress = targetIPAddress;
        _dict = dict;

    }

    return self;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
   // NSLog(@"==== in automaticallyNotifiesObserversForKey with callback id             = %@  ", key);
    if ([key isEqualToString:@"communicationResultForWLAN"] ||
            [key isEqualToString:@"isExecutingForWLAN"] ||
            [key isEqualToString:@"isFinishedForWLAN"]) {
        return YES;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

- (void)main {
     self.isExecutingForWLAN = YES;
     [self.ptp setIPAddress:self.ipAddress];

     // Commencez la communication avec l'imprimante
     if ([self.ptp startCommunication]) {
         self.communicationResultForWLAN = YES;

         BRPtouchPrinterStatus *status = [[BRPtouchPrinterStatus alloc] init];
         int error = [self.ptp getStatus:&status];
         NSLog(@"Statue de l'imprimante : %d", ERROR_NONE_);

         if (error == ERROR_NONE_ || error == 1) {
             // Vérifiez les erreurs dans status.statusInfo.byErrorInf et status.statusInfo.byErrorInf2
             if (status.statusInfo.byErrorInf == 0 && status.statusInfo.byErrorInf2 == 0) {
                 // Aucun problème détecté, l'imprimante est prête
                 NSLog(@"L'imprimante est prête.");

                 // Configurer les informations d'impression
                 [self.ptp setPrintInfo:self.printInfo];

                 // Démarrer l'impression de l'image
                 _errorCode = [self.ptp printImage:self.imgRef copy:self.numberOfPaper];

                 if (_errorCode == ERROR_NONE_ || 1) {
                      NSLog(@"Impression avec ok !!!");

                     PTSTATUSINFO resultstatus;
                     [self.ptp getPTStatus:&resultstatus];
                     _resultStatus = resultstatus;
                 }
             } else {
                 self.communicationResultForWLAN = NO;

                 NSLog(@"Erreur d'imprimante détectée : byErrorInf = %d, byErrorInf2 = %d", status.statusInfo.byErrorInf, status.statusInfo.byErrorInf2);
             }
         } else {
             self.communicationResultForWLAN = NO;
             NSLog(@"Erreur lors de la récupération du statut de l'imprimante : %d", error);
         }

         [self.ptp endCommunication];
     } else {
         self.communicationResultForWLAN = NO;
         NSLog(@"Impossible de démarrer la communication avec l'imprimante");
     }

     self.isExecutingForWLAN = NO;
     self.isFinishedForWLAN = YES;
 }
@end
