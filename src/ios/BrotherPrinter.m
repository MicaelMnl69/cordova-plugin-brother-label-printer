#import "BrotherPrinter.h"

@implementation BrotherPrinter {
    NSMutableArray *_brotherDeviceList;
    BRPtouchNetworkManager *_networkManager;
    BRPtouchPrinter *_ptp;
    NSString *_customPaperFilePath;
    UIImage *_image;
    NSString *_printCallbackId;

    void (^_callback)(NSArray *, NSError *);

    NSArray *printerList;
    NSArray *supportedPrinterList;
}
@synthesize operationQueue = _operationQueue;

- (void)pluginInitialize {
    [super pluginInitialize];
    _operationQueue = [NSOperationQueue mainQueue]; // [[NSOperationQueue alloc] init];
    printerList = @[
            @"Brother RJ-4040",
            @"Brother RJ-3150",
            @"Brother RJ-3150Ai",
            @"Brother RJ-3050",
            @"Brother RJ-3050Ai",
            @"Brother QL-710W",
            @"Brother QL-720NW",
            @"Brother QL-810W",
            @"Brother QL-820NWB",
            @"Brother PT-E550W",
            @"Brother PT-P750W",
            @"Brother PT-D800W",
            @"Brother PT-E800W",
            @"Brother PT-E850TKW",
            @"Brother PT-P900W",
            @"Brother PT-P950NW",
            @"Brother TD-2120N",
            @"Brother TD-2130N",
            @"Brother PJ-673",
            @"Brother PJ-763",
            @"Brother PJ-773",
            @"Brother MW-145MF",
            @"Brother MW-260MF",
            @"Brother RJ-4030Ai",
            @"Brother RJ-2050",
            @"Brother RJ-2140",
            @"Brother RJ-2150"];

    supportedPrinterList = @[
            @"Brother QL-710W",
            @"Brother QL-720NW",
            @"Brother QL-810W",
            @"Brother QL-820NWB",
            @"Brother TD-2120N",
            @"Brother TD-2120N",
            @"Brother TD-2125NWB",
            @"Brother TD-2130N",
            @"Brother TD-4550DNWB",
            @"Brother TD-4520DN",
            @"Brother TD-TD2125NWB",
            @"Brother TD-2135N",
            @"Brother TD-2135NWB",
            @"Brother TD-2320D",
            @"Brother TD-2320DF",
            @"Brother TD-2350D",
            @"Brother TD-2350DF",
            @"Brother TD-2350DSA",
            @"Brother TD-2030A",
            @"Brother TD-2020",
    ];
}

- (NSArray *)suffixedPrinterList:(NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger count = list.count;
    for (NSUInteger i = 0; i < count; i++) {
        [result addObject:[list[i] componentsSeparatedByString:@" "][1]];
    }

    return result;
}

- (void)pairedDevices:(NSArray *)deviceList withCompletion:(void (^)(NSArray *, NSError *))completion {
    __block NSMutableArray *resultList = [NSMutableArray array];
    [deviceList enumerateObjectsUsingBlock:^(EAAccessory *deviceInfo, NSUInteger idx, BOOL *stop) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];

        NSLog(@"==== paired devices              = %@", deviceInfo);

        dict[@"ipAddress"] = @"";

        dict[@"modelName"] = [NSString stringWithFormat:@"%@", deviceInfo.modelNumber];
        dict[@"serialNumber"] = [NSString stringWithFormat:@"%@", deviceInfo.serialNumber];
        dict[@"port"] = @"BLUETOOTH";

        [resultList addObject:[dict copy]];
    }];

    completion(resultList, nil);
}

- (void)pairedDevicesWithCompletion:(void (^)(NSArray *result, NSError *error))completion {
    EAAccessoryManager *accessoryManager = [EAAccessoryManager sharedAccessoryManager];
    NSArray *connectedAccessories = [accessoryManager connectedAccessories];

    if ([connectedAccessories count] > 0) {
        // skip scanning for Accessories
        [self pairedDevices:connectedAccessories withCompletion:completion];
        return;
    }

    NSLog(@"Connected Accessories: %@", connectedAccessories);

    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(NSString *evaluatedObject, NSDictionary *bindings) {

        if (!evaluatedObject || ![evaluatedObject isKindOfClass:[NSString class]]) {
            return NO;
        }

        __block BOOL keep = NO;
        [[self suffixedPrinterList:supportedPrinterList] enumerateObjectsUsingBlock:^(NSString *printerName, NSUInteger index, BOOL *stop) {
            keep = keep || [evaluatedObject hasPrefix:printerName];
        }];

        return keep;
    }];

    [accessoryManager showBluetoothAccessoryPickerWithNameFilter:pred completion:^(NSError *error) {
        if (error) {
            NSLog(@"Error while to pick an accessory: %@", [error localizedDescription]);
            completion(nil, error);
            return;
        }

        NSArray *connectedAccessories = [accessoryManager connectedAccessories];
        NSLog(@"Connected Accessories: %@", connectedAccessories);
        [self pairedDevices:connectedAccessories withCompletion:completion];
    }];
}


- (void)networkPrintersWithCompletion:(void (^)(NSArray *result, NSError *error))completion {
   // NSLog(@"==== in networkPrintersWithCompletion with callback id                ");

    if (!_networkManager) {
        _networkManager = [[BRPtouchNetworkManager alloc] init];
        _networkManager.delegate = self;
        _networkManager.isEnableIPv6Search = YES;
    }

    _callback = completion;

    [_networkManager setPrinterNames:supportedPrinterList];
    [_networkManager startSearch:5];

   // NSLog(@"==== in networkPrintersWithCompletion END                ");

}

#pragma mark - BRPtouchNetworkDelegate

- (void)didFinishSearch:(id)sender {
    //NSLog(@"==== in didFinishSearch with callback id                = %@", sender);

    NSArray *deviceList = [_networkManager getPrinterNetInfo];
    __block NSMutableArray *resultList = [NSMutableArray array];

    NSLog(@"==== resultat              = %@", resultList);
    [deviceList enumerateObjectsUsingBlock:^(BRPtouchDeviceInfo *deviceInfo, NSUInteger idx, BOOL *stop) {
        NSLog(@"==== didFinishSearch= %@", deviceInfo);

        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        if (deviceInfo.strIPAddress && ![deviceInfo.strIPAddress isEqual:@""]) {
            dict[@"ipAddress"] = deviceInfo.strIPAddress;
        }

        if (deviceInfo.strMACAddress && ![deviceInfo.strMACAddress isEqual:@""]) {
            dict[@"macAddress"] = deviceInfo.strMACAddress;
        }

        if (deviceInfo.strModelName && ![deviceInfo.strModelName isEqual:@""]) {
            dict[@"modelName"] = deviceInfo.strModelName;
        }

        if (deviceInfo.strSerialNumber && ![deviceInfo.strSerialNumber isEqual:@""]) {
            dict[@"serialNumber"] = deviceInfo.strSerialNumber;
        }

        dict[@"port"] = @"NET";

        [resultList addObject:[dict copy]];
    }];

    NSLog(@"resultList: %@", resultList);
    if (_callback) {
        _callback(resultList, nil);
        _callback = nil;
    }

   // NSLog(@"==== in didFinishSearch with callback id                = %@ END", sender);

}

#pragma mark - Plugin Commands

- (void)findNetworkPrinters:(CDVInvokedUrlCommand *)command {
    // NSLog(@"==== in findNetworkPrinters with callback id = %@", command.callbackId);

    // Utilisation de DispatchQueue pour gérer le délai
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self networkPrintersWithCompletion:^(NSArray *networkPrinters, NSError *error) {
            if (error) {
                [self.commandDelegate
                        sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]]
                              callbackId:command.callbackId];
                return;
            }

            [self.commandDelegate
                    sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:networkPrinters]
                          callbackId:command.callbackId];
        }];
    });
}

- (void)findBluetoothPrinters:(CDVInvokedUrlCommand *)command {

//	[self.commandDelegate runInBackground:^{
    [self pairedDevicesWithCompletion:^(NSArray *bluetoothPrinters, NSError *error) {
        if (error) {
            [self.commandDelegate
                    sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]]
                          callbackId:command.callbackId];
            return;
        }

        [self.commandDelegate
                sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:bluetoothPrinters]
                      callbackId:command.callbackId];
    }];
//    }];
}

- (void)findPrinters:(CDVInvokedUrlCommand *)command {
    NSLog(@"==== in findPrinters with callback id                = %@", command.callbackId);

    [self findNetworkPrinters:command];
    return;

//    [[BRPtouchBluetoothManager sharedManager] brShowBluetoothAccessoryPickerWithNameFilter:nil];
//	[self.commandDelegate runInBackground:^{
//        [self networkPrintersWithCompletion:^(NSArray* networkPrinters, NSError *error) {
//            [self pairedDevicesWithCompletion:^(NSArray* bluetoothPrinters, NSError *error) {
//
//                if (error) {
//                    [self.commandDelegate
//                        sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]]
//                              callbackId:command.callbackId];
//                    return;
//                }
//
//                NSArray *resultList = [[[NSArray alloc] initWithArray:networkPrinters] arrayByAddingObjectsFromArray:bluetoothPrinters];
//
//                [self.commandDelegate
//                    sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resultList]
//                          callbackId:command.callbackId];
//
//            }];
//        }];
//    }];
}

- (void)setPrinter:(CDVInvokedUrlCommand *)command {
  //  NSLog(@"==== in setPrinter with callback id                = %@", command.callbackId);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *obj = command.arguments[0];
    if (!obj) {
        [self.commandDelegate
                sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Expected an object as the first argument."]
                      callbackId:command.callbackId];
        return;
    }

    NSString *ipAddress = obj[@"ipAddress"];
    NSString *modelName = obj[@"modelName"];
    NSString *paperLabelName = obj[@"paperLabelName"];
    NSString *numberOfCopies = obj[@"numberOfCopies"];
    NSString *orientation = obj[@"orientation"];
    NSString *customPaperFilePath = obj[@"customPaperFilePath"];
    NSString *serialNumber = obj[@"serialNumber"];

    if (!modelName) {
        [self.commandDelegate
                sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Expected a \"modelName\" key in the given object"]
                      callbackId:command.callbackId];
        return;
    }
    [userDefaults
            setObject:modelName
               forKey:kSelectedDevice];

    NSString *port = obj[@"port"];
    if (!port) {
        [self.commandDelegate
                sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Expected a \"port\" key in the given object"]
                      callbackId:command.callbackId];
        return;
    }

    if ([@"BLUETOOTH" isEqualToString:port]) {

        if(!serialNumber){
            [self.commandDelegate
                    sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Expected a \"serialNumber\" key in the given object for BlueTooth devices"]
                          callbackId:command.callbackId];
            return;
        }
        [userDefaults
                setObject:@"0"
                   forKey:kIsWiFi];
        [userDefaults
                setObject:@"1"
                   forKey:kIsBluetooth];

        [userDefaults
                setObject:serialNumber
                   forKey:kSerialNumber];
    }

    if ([@"NET" isEqualToString:port]) {
        [userDefaults
                setObject:@"1"
                   forKey:kIsWiFi];
        [userDefaults
                setObject:@"0"
                   forKey:kIsBluetooth];

        [userDefaults
                setObject:@"0"
                   forKey:kSerialNumber];
    }

    [userDefaults
            setObject:ipAddress
               forKey:kIPAddress];

    if (paperLabelName) {
        [userDefaults
                setObject:paperLabelName
                   forKey:kPaperLabelName];
    }

    if(numberOfCopies) {
        [userDefaults
                    setObject:numberOfCopies
                       forKey:kPrintNumberOfPaperKey];
    }

    if (orientation) {
        if ([[orientation uppercaseString] isEqual:@"PORTRAIT"]) {
            [userDefaults
                    setObject:@0x01
                       forKey:kPrintOrientationKey];
        } else {
            [userDefaults
                    setObject:@0x00
                       forKey:kPrintOrientationKey];
        }
    }

    if(customPaperFilePath) {
        NSString *absoluteCustomPaperFilePath = [NSString stringWithFormat:@"%@/%@", @"public", [customPaperFilePath stringByDeletingPathExtension]];
        _customPaperFilePath = [[NSBundle mainBundle] pathForResource:absoluteCustomPaperFilePath ofType:@"bin"];

        // Log the result
        if (_customPaperFilePath) {
            NSLog(@"✅ Custom paper file exists: %@", _customPaperFilePath);
        } else {
            NSLog(@"❌ Custom paper file NOT found. Expected path: %@", absoluteCustomPaperFilePath);
        }
    }

    [userDefaults synchronize];

    // Send okay
    [self.commandDelegate
            sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
                  callbackId:command.callbackId];

  //  NSLog(@"==== in setPrinter with callback id                = %@ END", command.callbackId);

}

- (NSInteger)integerValueFromDefaults:(NSUserDefaults *)userDefaults forKey:(NSString *)key withFallback:(NSInteger)fallback {
    if ([userDefaults objectForKey:key] == nil) {
        return fallback;
    }

    return [userDefaults integerForKey:key];
}

- (NSString *)stringValueFromDefaults:(NSUserDefaults *)userDefaults forKey:(NSString *)key withFallback:(NSString *)fallback {
    NSString *str = [userDefaults stringForKey:key];
    if (str == nil) {
        return fallback;
    }

    return str;
}

- (double)doubleValueFromDefaults:(NSUserDefaults *)userDefaults forKey:(NSString *)key withFallback:(double)fallback {
    if ([userDefaults objectForKey:key] == nil) {
        return fallback;
    }

    return [userDefaults doubleForKey:key];
}

- (void)printViaSDK:(CDVInvokedUrlCommand *)command {
 //   NSLog(@"==== in printViaSdk with callback id                = %@", command.callbackId);
    NSString *base64Data = command.arguments[0];
    if (base64Data == nil) {
        [self.commandDelegate
                sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Expected a string as the first argument."]
                      callbackId:command.callbackId];
        return;
    }


    _printCallbackId = command.callbackId;

    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Data options:NSDataBase64DecodingIgnoreUnknownCharacters];
    _image = [[UIImage alloc] initWithData:imageData];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSString *selectedDevice = [userDefaults stringForKey:kSelectedDevice];

    NSString *ipAddress = [userDefaults stringForKey:kIPAddress];
    NSString *serialNumber = [userDefaults stringForKey:kSerialNumber];

    // Set the Print Info
    // PrintInfo
    BRPtouchPrintInfo *printInfo = [[BRPtouchPrintInfo alloc] init];

    NSString *numPaper = [self stringValueFromDefaults:userDefaults forKey:kPrintNumberOfPaperKey withFallback:@"1"]; // Item 1

    printInfo.strPaperName = [self stringValueFromDefaults:userDefaults forKey:kPaperLabelName withFallback:@"62mm"]; // Item 2
    printInfo.nOrientation = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintOrientationKey withFallback:Landscape]; // Item 3
    printInfo.nPrintMode = (int) [self integerValueFromDefaults:userDefaults forKey:kScalingModeKey withFallback:Fit]; // Item 4
    printInfo.scaleValue = [self doubleValueFromDefaults:userDefaults forKey:kScalingFactorKey withFallback:1.0]; // Item 5
///////////
    printInfo.nHalftone = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintHalftoneKey withFallback:Dither]; // Item 6
    printInfo.nHorizontalAlign = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintHorizintalAlignKey withFallback:Left]; // Item 7
    printInfo.nVerticalAlign = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintVerticalAlignKey withFallback:Top]; // Item 8
    printInfo.nPaperAlign = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintPaperAlignKey withFallback:PaperLeft]; // Item 9

    printInfo.nExtFlag |= (int) [self integerValueFromDefaults:userDefaults forKey:kPrintCodeKey withFallback:CodeOff]; // Item 10
    printInfo.nExtFlag |= (int) [self integerValueFromDefaults:userDefaults forKey:kPrintCarbonKey withFallback:CarbonOff]; // Item 11
    printInfo.nExtFlag |= (int) [self integerValueFromDefaults:userDefaults forKey:kPrintDashKey withFallback:DashOff]; // Item 12
    printInfo.nExtFlag |= (int) [self integerValueFromDefaults:userDefaults forKey:kPrintFeedModeKey withFallback:FixPage]; // Item 13

    printInfo.nRollPrinterCase = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintCurlModeKey withFallback:CurlModeOff]; // Item 14
    printInfo.nSpeed = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintSpeedKey withFallback:Fast]; // Item 15
    printInfo.bBidirection = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintBidirectionKey withFallback:BidirectionOff]; // Item 16

    printInfo.nCustomFeed = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintFeedMarginKey withFallback:0]; // Item 17
    printInfo.nCustomLength = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintCustomLengthKey withFallback:0]; // Item 18
    printInfo.nCustomWidth = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintCustomWidthKey withFallback:0]; // Item 19

    printInfo.nAutoCutFlag |= (int) [self integerValueFromDefaults:userDefaults forKey:kPrintAutoCutKey withFallback:AutoCutOn]; // Item 20
    printInfo.bEndcut = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintCutAtEndKey withFallback:CutAtEndOn]; // Item 21
    printInfo.bHalfCut = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintHalfCutKey withFallback:HalfCutOff]; // Item 22
    printInfo.bSpecialTape = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintSpecialTapeKey withFallback:SpecialTapeOff]; // Item 23
    printInfo.bRotate180 = (int) [self integerValueFromDefaults:userDefaults forKey:kRotateKey withFallback:RotateOff]; // Item 24
    printInfo.bPeel = (int) [self integerValueFromDefaults:userDefaults forKey:kPeelKey withFallback:PeelOff]; // Item 25
    printInfo.bCutMark = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintCutMarkKey withFallback:CutMarkOff]; // Item 27
    printInfo.nLabelMargine = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintLabelMargineKey withFallback:0]; // Item 28

    if ([selectedDevice rangeOfString:@"RJ-"].location != NSNotFound ||
            [selectedDevice rangeOfString:@"TD-"].location != NSNotFound) {
        printInfo.nDensity = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintDensityMax5Key withFallback:DensityMax5Level1]; // Item 29
    } else if ([selectedDevice rangeOfString:@"PJ-"].location != NSNotFound) {
        printInfo.nDensity = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintDensityMax10Key withFallback:DensityMax10Level5]; // Item 30
    } else {
        // Error
        printInfo.nDensity = (int) [self integerValueFromDefaults:userDefaults forKey:@"density" withFallback:DensityMax5Level0];
    }

    printInfo.nTopMargin = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintTopMarginKey withFallback:0]; // Item 31
    printInfo.nLeftMargin = (int) [self integerValueFromDefaults:userDefaults forKey:kPrintLeftMarginKey withFallback:0]; // Item 32

    NSLog(@"kSelectedDevice             = %@", selectedDevice);
    NSLog(@"kIPAddress                  = %@", ipAddress);
    NSLog(@"kSerialNumber               = %@", serialNumber);
    /* NSLog(@"");
     NSLog(@"strSaveFilePath             = %@"   , printInfo.strSaveFilePath);
     NSLog(@"kPrintNumberOfPaperKey      = %@"   , numPaper);
     NSLog(@"kPrintPaperSizeKey          = %@"   , printInfo.strPaperName);
     NSLog(@"kPrintOrientationKey        = %d"   , printInfo.nOrientation);
     NSLog(@"kPrintDensityKey            = %d"   , printInfo.nDensity);
     NSLog(@"kScalingModeKey             = %d"   , printInfo.nPrintMode);
     NSLog(@"kScalingFactorKey           = %lf"  , printInfo.scaleValue);
     NSLog(@"kPrintHalftoneKey           = %d"   , printInfo.nHalftone);
     NSLog(@"kPrintHorizintalAlignKey    = %d"   , printInfo.nHorizontalAlign);
     NSLog(@"kPrintVerticalAlignKey      = %d"   , printInfo.nVerticalAlign);
     NSLog(@"kPrintPaperAlignKey         = %d"   , printInfo.nPaperAlign);
     NSLog(@"");
     NSLog(@"nExtFlag                    = %d"   , printInfo.nExtFlag);
     NSLog(@"");
     NSLog(@"nRollPrinterCase            = %d"   , printInfo.nRollPrinterCase);
     NSLog(@"nSpeed                      = %d"   , printInfo.nSpeed);
     NSLog(@"bBidirection                = %d"   , printInfo.bBidirection);
     NSLog(@"");
     NSLog(@"kPrintFeedMarginKey         = %d"   , printInfo.nCustomFeed);
     NSLog(@"kPrintCustomLengthKey       = %d"   , printInfo.nCustomLength);
     NSLog(@"kPrintCustomWidthKey        = %d"   , printInfo.nCustomWidth);
     NSLog(@"");
     NSLog(@"nAutoCutFlag                = %d"   , printInfo.nAutoCutFlag);
     NSLog(@"bEndCut                     = %d"   , printInfo.bEndcut);
     NSLog(@"bSpecialTape                = %d"   , printInfo.bSpecialTape);
     NSLog(@"bHalfCut                    = %d"   , printInfo.bHalfCut);
     NSLog(@"bRotate180                  = %d"   , printInfo.bRotate180);
     NSLog(@"bPeel                       = %d"   , printInfo.bPeel);
     NSLog(@"");
     NSLog(@"kPrintCustomPaperKey        = %@"   , customPaperFilePath);
     NSLog(@"");
     NSLog(@"bCutMark                    = %d"   , printInfo.bCutMark);
     NSLog(@"nLabelMargine               = %d"   , printInfo.nLabelMargine);
 */
    NSInteger isWifi = [userDefaults integerForKey:kIsWiFi];
    NSInteger isBluetooth = [userDefaults integerForKey:kIsBluetooth];

    __block NSString *finalDeviceName = selectedDevice;
    [[self suffixedPrinterList:supportedPrinterList] enumerateObjectsUsingBlock:^(NSString *printerName, NSUInteger index, BOOL *stop) {
        if ([selectedDevice hasPrefix:printerName]) {
            finalDeviceName = [NSString stringWithFormat:@"Brother %@", printerName];
        }
    }];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (isBluetooth == 1) {

        _ptp = [[BRPtouchPrinter alloc] initWithPrinterName:finalDeviceName interface:CONNECTION_TYPE_BLUETOOTH];
        if ([fileManager fileExistsAtPath:_customPaperFilePath]){
            [_ptp setCustomPaperFile:_customPaperFilePath];
        }

        [_ptp setupForBluetoothDeviceWithSerialNumber:serialNumber];

    } else if (isWifi == 1) {
        _ptp = [[BRPtouchPrinter alloc] initWithPrinterName:finalDeviceName interface:CONNECTION_TYPE_WLAN];

       if ([fileManager fileExistsAtPath:_customPaperFilePath]){
            [_ptp setCustomPaperFile:_customPaperFilePath];
        }
    } else {
        _ptp = nil;
    }

    if (!_ptp) {
        // oh noes!
        NSLog(@"We don't have a printer!");

        //[self.commandDelegate sendPluginResult:pluginResult callbackId: _printCallbackId];

        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No printer was set"] callbackId:command.callbackId];
        _printCallbackId = nil;
        return;
    }

    NSOperation *operation = nil;
    if (isBluetooth == 1) {
        BRBluetoothPrintOperation *bluetoothPrintOperation = [[BRBluetoothPrintOperation alloc]
                            initWithOperation:_ptp
                                    printInfo:printInfo
                                        imgRef:[_image CGImage]
                                numberOfPaper:[numPaper intValue]
                                serialNumber:serialNumber];

        [bluetoothPrintOperation addObserver:self
                    forKeyPath:@"isFinishedForBT"
                        options:NSKeyValueObservingOptionNew
                        context:nil];

        [bluetoothPrintOperation addObserver:self
                    forKeyPath:@"communicationResultForBT"
                        options:NSKeyValueObservingOptionNew
                        context:nil];

        operation = bluetoothPrintOperation;
       
    } else if (isWifi == 1) {
        BRWLANPrintOperation *wlanPrintOperation = [[BRWLANPrintOperation alloc]
                initWithOperation:_ptp
                        printInfo:printInfo
                           imgRef:[_image CGImage]
                    numberOfPaper:[numPaper intValue]
                        ipAddress:ipAddress
                         withDict:nil];

        [wlanPrintOperation addObserver:self
                             forKeyPath:IS_FINISHED_FOR_WLAN
                                options:NSKeyValueObservingOptionNew
                                context:nil];

        [wlanPrintOperation addObserver:self
                             forKeyPath:@"communicationResultForWLAN"
                                options:NSKeyValueObservingOptionNew
                                context:nil];

        operation = wlanPrintOperation;

    } else {

    }

    NSLog(@"==== in printViaSdk with callback id                = %@ ...  operation: %@", command.callbackId, operation);

    if (!operation) {
        return;
    }

    NSLog(@"==== in printViaSdk with callback id                = %@ ...  operation adding to que: %@", command.callbackId, operation);
    [_operationQueue addOperation:operation];
    NSLog(@"==== in printViaSdk with callback id                = %@ ...  operation: %@  END", command.callbackId, operation);

}


#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    NSOperation *operation = (NSOperation *) object;
    if ([keyPath isEqualToString:IS_FINISHED_FOR_WLAN]) {
        NSLog(@"isFinishedForWLAN ....");

        [operation removeObserver:self forKeyPath:IS_FINISHED_FOR_WLAN];
        [operation removeObserver:self forKeyPath:COMMUNICATION_RESULT_FOR_WLAN];
        BRWLANPrintOperation *wlanOperation = (BRWLANPrintOperation *) operation;

        NSLog(@"Error Code in BrotherPrinter is: %d", wlanOperation.errorCode);
        
        if (wlanOperation.errorCode != ERROR_NONE_) {
            [self.commandDelegate
                    sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[self errorMessageFromStatusInfo:wlanOperation.errorCode]] callbackId:_printCallbackId];
        } else {

            [self.commandDelegate
                    sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
                          callbackId:_printCallbackId];
        }

        _printCallbackId = nil;
        _image = nil;

        return;

    } else if ([keyPath isEqualToString:@"isFinishedForBT"]) {
        [operation removeObserver:self forKeyPath:@"isFinishedForBT"];
        [operation removeObserver:self forKeyPath:@"communicationResultForBT"];
        [self.commandDelegate
                sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
                      callbackId:_printCallbackId];
        _printCallbackId = nil;
        _image = nil;
    } else if ([keyPath isEqualToString:COMMUNICATION_RESULT_FOR_WLAN]) {

        BRWLANPrintOperation *wlanOperation = (BRWLANPrintOperation *) operation;
        BOOL result = wlanOperation.communicationResultForWLAN;
        NSLog(@"Communication Result: %d", result);
        NSLog(@"Error Code in BrotherPrinter is: %d", wlanOperation.errorCode);

        if (!result) {
            [operation removeObserver:self forKeyPath:IS_FINISHED_FOR_WLAN];
            [operation removeObserver:self forKeyPath:COMMUNICATION_RESULT_FOR_WLAN];
            PTSTATUSINFO resultStatus = wlanOperation.resultStatus;

            [self.commandDelegate
                    sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No print response received from Network printer"]
                          callbackId:_printCallbackId];

            _printCallbackId = nil;
            _image = nil;

            return;
        }
    } else if ([keyPath isEqualToString:@"communicationResultForBT"]) {
        BRBluetoothPrintOperation *bluetoothOperation = (BRBluetoothPrintOperation *) operation;
        BOOL result = bluetoothOperation.communicationResultForBT;
        NSLog(@"Communication Result: %d", result);
        if (!result) {
            [operation removeObserver:self forKeyPath:@"isFinishedForBT"];
            [operation removeObserver:self forKeyPath:@"communicationResultForBT"];
            PTSTATUSINFO resultStatus = bluetoothOperation.resultStatus;
            [self.commandDelegate
                sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Error occured while Bluetooth printing"]
                        callbackId:_printCallbackId];
            _printCallbackId = nil;
            _image = nil;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - Error Handler

- (NSString *)errorMessageFromStatusInfo:(NSInteger)statusInfo {
    switch (statusInfo) {
        case ERROR_NONE_:
            return @"Succeeded";

        case ERROR_TIMEOUT:
            return @"ERROR_TIMEOUT";

        case ERROR_BADPAPERRES:
            return @"ERROR_BADPAPERRES";

        case ERROR_IMAGELARGE:
            return @"ERROR_IMAGELARGE";

        case ERROR_CREATESTREAM:
            return @"ERROR_CREATESTREAM";

        case ERROR_OPENSTREAM:
            return @"ERROR_OPENSTREAM";

        case ERROR_FILENOTEXIST:
            return @"ERROR_FILENOTEXIST";

        case ERROR_PAGERANGEERROR:
            return @"ERROR_PAGERANGEERROR";

        case ERROR_NOT_SAME_MODEL_:
            return @"ERROR_NOT_SAME_MODEL_";

        case ERROR_BROTHER_PRINTER_NOT_FOUND_:
            return @"RROR_BROTHER_PRINTER_NOT_FOUND_";

        case ERROR_PAPER_EMPTY_:
            return @"ERROR_PAPER_EMPTY_";

        case ERROR_BATTERY_EMPTY_:
            return @"ERROR_BATTERY_EMPTY_";

        case ERROR_COMMUNICATION_ERROR_:
            return @"ERROR_COMMUNICATION_ERROR_";

        case ERROR_OVERHEAT_:
            return @"ERROR_OVERHEAT_";

        case ERROR_PAPER_JAM_:
            return @"ERROR_PAPER_JAM_";

        case ERROR_HIGH_VOLTAGE_ADAPTER_:
            return @"ERROR_HIGH_VOLTAGE_ADAPTER_";

        case ERROR_CHANGE_CASSETTE_:
            return @"ERROR_CHANGE_CASSETTE_";

        case ERROR_FEED_OR_CASSETTE_EMPTY_:
            return @"ERROR_FEED_OR_CASSETTE_EMPTY_";

        case ERROR_SYSTEM_ERROR_:
            return @"ERROR_SYSTEM_ERROR_";

        case ERROR_NO_CASSETTE_:
            return @"ERROR_NO_CASSETTE_";

        case ERROR_WRONG_CASSENDTE_DIRECT_:
            return @"ERROR_WRONG_CASSENDTE_DIRECT_";

        case ERROR_CREATE_SOCKET_FAILED_:
            return @"ERROR_CREATE_SOCKET_FAILED_";

        case ERROR_CONNECT_SOCKET_FAILED_:
            return @"ERROR_CONNECT_SOCKET_FAILED_";

        case ERROR_GET_OUTPUT_STREAM_FAILED_:
            return @"ERROR_GET_OUTPUT_STREAM_FAILED_";

        case ERROR_GET_INPUT_STREAM_FAILED_:
            return @"ERROR_GET_INPUT_STREAM_FAILED_";

        case ERROR_CLOSE_SOCKET_FAILED_:
            return @"ERROR_CLOSE_SOCKET_FAILED_";

        case ERROR_OUT_OF_MEMORY_:
            return @"ERROR_OUT_OF_MEMORY_";

        case ERROR_SET_OVER_MARGIN_:
            return @"ERROR_SET_OVER_MARGIN_";

        case ERROR_NO_SD_CARD_:
            return @"ERROR_NO_SD_CARD_";

        case ERROR_FILE_NOT_SUPPORTED_:
            return @"ERROR_FILE_NOT_SUPPORTED_";

        case ERROR_EVALUATION_TIMEUP_:
            return @"ERROR_EVALUATION_TIMEUP_";

        case ERROR_WRONG_CUSTOM_INFO_:
            return @"ERROR_WRONG_CUSTOM_INFO_";

        case ERROR_NO_ADDRESS_:
            return @"ERROR_NO_ADDRESS_";

        case ERROR_NOT_MATCH_ADDRESS_:
            return @"ERROR_NOT_MATCH_ADDRESS_";

        case ERROR_FILE_NOT_FOUND_:
            return @"ERROR_FILE_NOT_FOUND_";

        case ERROR_TEMPLATE_FILE_NOT_MATCH_MODEL_:
            return @"ERROR_TEMPLATE_FILE_NOT_MATCH_MODEL_";

        case ERROR_TEMPLATE_NOT_TRANS_MODEL_:
            return @"ERROR_TEMPLATE_NOT_TRANS_MODEL_";

        case ERROR_COVER_OPEN_:
            return @"ERROR_COVER_OPEN_";

        case ERROR_WRONG_LABEL_:
            return @"ERROR_WRONG_LABEL_";

        case ERROR_PORT_NOT_SUPPORTED_:
            return @"ERROR_PORT_NOT_SUPPORTED_";

        case ERROR_WRONG_TEMPLATE_KEY_:
            return @"ERROR_WRONG_TEMPLATE_KEY_";

        case ERROR_BUSY_:
            return @"ERROR_BUSY_";

        case ERROR_TEMPLATE_NOT_PRINT_MODEL_:
            return @"ERROR_TEMPLATE_NOT_PRINT_MODEL_";

        case ERROR_CANCEL_:
            return @"RROR_CANCEL_";

        case ERROR_PRINTER_SETTING_NOT_SUPPORTED_:
            return @"ERROR_PRINTER_SETTING_NOT_SUPPORTED_";

        case ERROR_INVALID_PARAMETER_:
            return @"ERROR_INVALID_PARAMETER_";

        case ERROR_INTERNAL_ERROR_:
            return @"ERROR_INTERNAL_ERROR_";

        case ERROR_TEMPLATE_NOT_CONTROL_MODEL_:
            return @"ERROR_TEMPLATE_NOT_CONTROL_MODEL_";

        case ERROR_TEMPLATE_NOT_EXIST_:
            return @"ERROR_TEMPLATE_NOT_EXIST_";

        case ERROR_BUFFER_FULL_:
            return @"ERROR_BUFFER_FULL_";

        case ERROR_TUBE_EMPTY_:
            return @"ERROR_TUBE_EMPTY_";

        case ERROR_TUBE_RIBON_EMPTY_:
            return @"ERROR_TUBE_RIBON_EMPTY_";

        case ERROR_BADENCRYPT_: // This does not occur in iOS
        case ERROR_UPDATE_FRIM_NOT_SUPPORTED_: // This does not occur in iOS
        case ERROR_OS_VERSION_NOT_SUPPORTED_: // This does not occur in iOS
        default:
            return @"unknown error.";
    }
}

@end
