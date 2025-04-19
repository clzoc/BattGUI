//
//  powerInfo.h
//  app
//
//  Created by tsunami on 2025/4/19.
//
// power_info.h
#import <Foundation/Foundation.h>

// Declare functions to be exposed to Swift
float getRawSystemPower(void);
float getAdapterPower(void);
float getAdapterVoltage(void);
float getAdapterAmperage(void);
float getBatteryVoltage(void);
float getBatteryAmperage(void);
float getBatteryPower(void);
NSString* getChargingStatus(void);
