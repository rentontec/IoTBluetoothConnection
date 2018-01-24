//
//  ViewController.m
//  IoTDevices
//
//  Created by Scott Moody on 1/21/18.
//  Copyright © 2018 Scott Moody. All rights reserved.
//

#import "ViewController.h"
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import <CoreBluetooth/CoreBluetooth.h>

//@see https://www.raywenderlich.com/177848/core-bluetooth-tutorial-for-ios-heart-rate-monitor


@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (weak, nonatomic) IBOutlet UITextView *infoTextView;

@end

@implementation ViewController
{
    CBCentralManager* cbcentralmanager;
    NSDate* lastScanStartDate;
    NSMutableDictionary* beanRecords; //Uses NSUUID as key
    
    CBPeripheral *thePeripheral;
    CBService * theService;
    CBCharacteristic *theCharacteristic;
    
#define SERVICE_FEED_UUID                        @"0xB0E6A4BF-CCCC-FFFF-330C-0000000000F0"
#define SERVICE_BATTERY                     @"Battery"
#define FEED_CHARACTERISTIC_UUID                 @"0xB0E6A4BF-CCCC-FFFF-330C-0000000000F1"
    CBUUID *feedServiceUUID;
    CBUUID *feedCharacteristicUUID;
    NSString *textWindowString;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    textWindowString = @"";
    [self updateTextMessage:@"IoT Testing"];
    
    cbcentralmanager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil]; //options:@{CBCentralManagerOptionRestoreIdentifierKey:stateRestorationIdentifier}];
    feedServiceUUID = [CBUUID UUIDWithString:SERVICE_FEED_UUID];
    feedCharacteristicUUID = [CBUUID UUIDWithString:FEED_CHARACTERISTIC_UUID];
    //    // Define array of app service UUID
    //    NSArray * services = [NSArray arrayWithObjects:[CBUUID UUIDWithString:GLOBAL_SERIAL_PASS_SERVICE_UUID], nil];
    //
}

-(void)updateTextMessage:(NSString*)msg
{
    textWindowString = [NSString stringWithFormat:@"%@\n%@", textWindowString, msg];
    [self.infoTextView setText:textWindowString];
}

- (IBAction)invokeButtonSelected:(id)sender
{
    //perform feed
    NSLog(@"Writing value for characteristic %@", theCharacteristic);
    NSString *msg = [NSString stringWithFormat:@"%@\n%@\n%@", thePeripheral, theService, theCharacteristic] ;
    
    [self updateTextMessage:msg];
    
    UInt8 feedValue=0;
    NSData *data = [NSData dataWithBytes:&feedValue length:sizeof(feedValue)];
    [self updateTextMessage:@"writing value 0"];
    
    [thePeripheral writeValue:data forCharacteristic:theCharacteristic type:CBCharacteristicWriteWithResponse];
    
}

- (IBAction)connectButtonSelected:(id)sender
{
    [self updateTextMessage:@"#CONNECT"];
    
}

-(IBAction)readValue:(id)sender
{
    [self updateTextMessage:@"#READ_VALUE"];
    
    [thePeripheral readValueForCharacteristic:theCharacteristic];
    // calls didUpdateValue..
    
    Boolean isScanning = [cbcentralmanager isScanning];
    NSString *msg = [NSString stringWithFormat:@"Manager %@ Scanning", isScanning?@"IS":@"IS NOT"];
    [self updateTextMessage:msg];
}

-(IBAction)disConnectButtonSelected:(id)sender
{
    [self updateTextMessage:@"#DISCONNECT"];
    
    if (!thePeripheral)
        return;
    
    [cbcentralmanager cancelPeripheralConnection:thePeripheral]; //IMPORTANT, to clear off any pending connections
    [cbcentralmanager stopScan];
    
    
}
- (IBAction)discoverButtonSelected:(id)sender
{
    [self updateTextMessage:@"#DISCOVER"];
    
    // [self.infoTextView setText:@"information on bluetooth beacons"];
    [self updateTextMessage:@"scan..."];
    
    [cbcentralmanager scanForPeripheralsWithServices:nil options:nil];
    
    // Bluetooth must be ON
    if (cbcentralmanager.state != CBManagerStatePoweredOn)
    {
        NSLog(@"Error, bluetooth must be on");
        [self updateTextMessage:@"ERROR: Bluetooth must be on!"];
        
        return;
    }
    
}


#pragma mark - CBCharacteristic

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"didWriteValueForCharacteristic: %@", characteristic);
    
    NSString *msg = [NSString stringWithFormat:@"wroteVal %@", characteristic];
    [self updateTextMessage:msg];
    
}
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    NSLog(@"didUpdateValueForCharacteristic: %@", characteristic);
    
    NSString *msg = [NSString stringWithFormat:@"didUpdateVal %@", characteristic];
    [self updateTextMessage:msg];
    
}
#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    
    switch (central.state) {
        case CBManagerStatePoweredOn:
            NSLog(@"%@: Bluetooth ON", self.class.description);
            break;
            
        default:
            NSLog(@"%@: Bluetooth state error: %d", self.class.description, (int)central.state);
            break;
    }
}

-(void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    //NOTE: this version is looking for a peripheral named PTFeeder ..
    NSString *msg = [NSString stringWithFormat:@"didDiscoverPeripheral %@ - %@", RSSI, peripheral];
    //  [self updateTextMessage:msg];
    NSLog(@"%@",msg);
    
    
    if ([@"PTFeeder" isEqualToString: peripheral.name])
    {
        NSLog(@"didDiscoverPeripheral %@ - %@", RSSI, peripheral);
        thePeripheral = peripheral;
        thePeripheral.delegate = self;
        
        [central cancelPeripheralConnection:peripheral]; //IMPORTANT, to clear off any pending connections
        [cbcentralmanager stopScan];
        [central connectPeripheral:thePeripheral options:nil];
        
    }
}

-(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"***centralManager:didConnectPeripheral %@", peripheral);
    
    peripheral.delegate = self;
    
    if(peripheral.services)
    {
        NSLog(@"already discovered....");
        [self peripheral:peripheral didDiscoverServices:nil]; //already discovered services, DO NOT re-discover. Just pass along the peripheral.
    }
    else
    {
        NSLog(@"NOT  already discovered....");
        
        [peripheral discoverServices:nil]; //yet to discover, normal path. Discover your services needed
    }
}

-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error
{
    for(CBService* svc in peripheral.services)
    {
        if(svc.characteristics)
        {
            NSLog(@"0.Characteristic = %@", svc.characteristics);
            
            [self peripheral:peripheral didDiscoverCharacteristicsForService:svc error:nil]; //already discovered characteristic before, DO NOT do it again
        }
        else
        {
            [peripheral discoverCharacteristics:nil
                                     forService:svc]; //need to discover characteristics
        }
    }
}

//https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonCentralRoleTasks/PerformingCommonCentralRoleTasks.html#//apple_ref/doc/uid/TP40013257-CH3-SW4
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"Service = %@", service);
    NSLog(@"1.Characteristic = %@", service.characteristics);
    
    if ([service.UUID isEqual: feedServiceUUID])
    {
        NSLog(@"*** Discovered the FEED %@", service);
        NSString *msg = [NSString stringWithFormat:@"%@", service];
        [self updateTextMessage:msg];
        
        
        theService = service;
        
        for (CBCharacteristic *ch in service.characteristics)
        {
            if ([ch.UUID isEqual:feedCharacteristicUUID])
            {
                theCharacteristic = ch;
                
                NSLog(@"Found ch=%@", ch);
                break;
            }
        }
        
    }
    else if ([@"Battery" isEqualToString:[service.UUID UUIDString]])
    {
        NSLog(@"*** Discovered the BATTERY %@", service);
        
    }
    
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"centralManager:didFailToConnectPeripheral %@", peripheral);
    NSString *msg = [NSString stringWithFormat:@"FailToConnect %@", peripheral];
    [self updateTextMessage:msg];
    
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"centralManager:didDisconnectPeripheral %@", peripheral);
    NSString *msg = [NSString stringWithFormat:@"didConnect %@", peripheral];
    [self updateTextMessage:msg];
    
    
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict
{
    NSLog(@"centralManager:willRestoreState %@", dict);
    
    //nothing needs to happen here
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

