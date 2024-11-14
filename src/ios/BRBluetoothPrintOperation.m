#import "BRUserDefaults.h"
#import "BRBluetoothPrintOperation.h"

@interface BRBluetoothPrintOperation () {
}
@property(nonatomic, assign) BOOL isExecutingForBT;
@property(nonatomic, assign) BOOL isFinishedForBT;

@property(nonatomic, weak) BRPtouchPrinter    *ptp;
@property(nonatomic, strong) BRPtouchPrintInfo  *printInfo;
@property(nonatomic, assign) CGImageRef         imgRef;
@property(nonatomic, assign) int                numberOfPaper;
@property(nonatomic, strong) NSString           *serialNumber;

@end

@implementation BRBluetoothPrintOperation

-(id)initWithOperation:(BRPtouchPrinter *)targetPtp
             printInfo:(BRPtouchPrintInfo *)targetPrintInfo
                imgRef:(CGImageRef)targetImgRef
         numberOfPaper:(int)targetNumberOfPaper
          serialNumber:(NSString *)targetSerialNumber {
    self = [super init];
    if (self) {
        self.ptp            = targetPtp;
        self.printInfo      = targetPrintInfo;
        self.imgRef         = targetImgRef;
        self.numberOfPaper  = targetNumberOfPaper;
        self.serialNumber   = targetSerialNumber;
    }

    return self;
}

+(BOOL)automaticallyNotifiesObserversForKey:(NSString*)key {
    if ([key isEqualToString:@"communicationResultForBT"]   ||
        [key isEqualToString:@"isExecutingForBT"]           ||
        [key isEqualToString:@"isFinishedForBT"]) {
        return YES;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

-(void)main {
    self.isExecutingForBT = YES;

    [self.ptp setupForBluetoothDeviceWithSerialNumber:self.serialNumber];

    // Démarrer la communication avec l'imprimante
    if ([self.ptp startCommunication]) {
        self.communicationResultForBT = YES;
        
        // Récupérer le statut de l'imprimante
        BRPtouchPrinterStatus *status = [[BRPtouchPrinterStatus alloc] init];
        int error = [self.ptp getStatus:&status];
        
        if (error == ERROR_NONE_ && status.statusInfo.byErrorInf == 0 && status.statusInfo.byErrorInf2 == 0) {
            // Aucune erreur détectée, l'imprimante est prête
            [self.ptp setPrintInfo:self.printInfo];

            // Démarrer l'impression de l'image
            int printResult = [self.ptp printImage:self.imgRef copy:self.numberOfPaper];
            if (printResult == ERROR_NONE_) {
                PTSTATUSINFO resultstatus;
                [self.ptp getPTStatus:&resultstatus];
                self.resultStatus = resultstatus;
            }
        } else {
            NSLog(@"Erreur d'imprimante détectée : byErrorInf = %d, byErrorInf2 = %d", status.statusInfo.byErrorInf, status.statusInfo.byErrorInf2);
            self.communicationResultForBT = NO;
        }
        
        [self.ptp endCommunication];
    } else {
        self.communicationResultForBT = NO;
        NSLog(@"Impossible de démarrer la communication avec l'imprimante");
    }

    self.isExecutingForBT = NO;
    self.isFinishedForBT = YES;
}

@end