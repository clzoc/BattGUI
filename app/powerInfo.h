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
NSString *_Nonnull getChargingStatus(void);

// Class for interacting with the batt daemon socket
// Function for interacting with the batt daemon socket
// Sends a command value to the specified Unix domain socket path.
// Returns the response string on success, nil on failure.
// Populates the error pointer if an error occurs and the pointer is not NULL.
NSString *_Nullable sendCommandToUnixSocket(NSInteger value, const char *_Nonnull socketPath, NSError *_Nullable *_Nullable error);
