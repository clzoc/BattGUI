//
//  powerInfo.m
//  app
//
//  Created by tsunami on 2025/4/19.
//
/*
 * Power Management Suite - System Power Information Tool (power_info)
 * Copyright (C) 2025 <Your Name or Organization>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * --- Acknowledgments ---
 * This tool incorporates code originally from the Power Monitor Tool by SAP SE,
 * which was licensed under the Apache License, Version 2.0.
 * See original notice below (preserved for attribution):
 *
 * Original file info:
 * PowerConsumption.m
 * Standalone tool to get current power consumption on macOS
 * Extracted from Power Monitor Tool by SAP SE
 * Original code licensed under Apache License, Version 2.0
 */

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <unistd.h>

// Structure to communicate with the SMC
typedef struct {
    uint32_t  key;
    char      unused0[24];
    uint32_t  size;
    char      unused1[10];
    char      command;
    char      unused2[5];
    float     value;
    char      unused3[28];
} AppleSMCData_Float; // Renamed for clarity

// Structure for reading 16-bit integer SMC values
typedef struct {
    uint32_t  key;
    char      unused0[24];
    uint32_t  size;
    char      unused1[10];
    char      command;
    char      unused2[5];
    uint16_t  value; // Changed to uint16_t
    char      unused3[30]; // Adjusted padding size
} AppleSMCData_Int16;

// Enum for Battery Status
typedef enum {
    BATTERY_STATUS_IDLE,
    BATTERY_STATUS_CHARGING,
    BATTERY_STATUS_DISCHARGING,
    BATTERY_STATUS_FAILED
} BatteryStatus;

// Struct to hold battery info
typedef struct {
    BatteryStatus status;
    float powerWatts; // Positive for charging, negative for discharging
} BatteryInfo;


// Helper function to read a signed fixed-point 7.8 value from SMC (e.g., temperature)
BOOL getSMCSignedFixedPoint78Value(uint32_t key, float* outValue) {
    BOOL success = NO;
    io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    
    if (smc) {
        io_connect_t conn = IO_OBJECT_NULL;
        IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
        
        if (result == kIOReturnSuccess && conn != IO_OBJECT_NULL) {
            // sp78 is 2 bytes, so use the Int16 structure
            AppleSMCData_Int16 inStruct, outStruct;
            size_t outStructSize = sizeof(AppleSMCData_Int16);

            bzero(&inStruct, sizeof(AppleSMCData_Int16));
            bzero(&outStruct, sizeof(AppleSMCData_Int16));
            
            inStruct.command = 5; // read command
            inStruct.size = 2;    // Size for sp78
            inStruct.key = key;
            
            result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(AppleSMCData_Int16), &outStruct, &outStructSize);
            IOServiceClose(conn);

            if (result == kIOReturnSuccess) {
                // Convert sp78 raw value (signed int16) to float
                // sp78: 1 sign bit, 7 integer bits, 8 fractional bits
                *outValue = (float)((int16_t)outStruct.value) / 256.0f; // Divide by 2^8
                success = YES;
            }
        }
        IOObjectRelease(smc);
    }
    return success;
}


// Helper function to read a 16-bit integer value from SMC
BOOL getSMCUInt16Value(uint32_t key, uint16_t* outValue) { // Changed to uint16_t output
    BOOL success = NO;
    io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    
    if (smc) {
        io_connect_t conn = IO_OBJECT_NULL;
        IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
        
        if (result == kIOReturnSuccess && conn != IO_OBJECT_NULL) {
            AppleSMCData_Int16 inStruct, outStruct; // Still use Int16 struct for 2 bytes
            size_t outStructSize = sizeof(AppleSMCData_Int16);

            bzero(&inStruct, sizeof(AppleSMCData_Int16));
            bzero(&outStruct, sizeof(AppleSMCData_Int16));
            
            inStruct.command = 5; // read command
            inStruct.size = 2;    // Size for ui16/si16
            inStruct.key = key;
            
            result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(AppleSMCData_Int16), &outStruct, &outStructSize);
            IOServiceClose(conn);

            if (result == kIOReturnSuccess) {
                // Value is in outStruct.value (as uint16_t)
                *outValue = outStruct.value;
                success = YES;
            }
        }
        IOObjectRelease(smc);
    }
    return success;
}

// Helper function to read a signed 8-bit integer value from SMC
BOOL getSMCSInt8Value(uint32_t key, int8_t* outValue) {
    BOOL success = NO;
    io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    
    if (smc) {
        io_connect_t conn = IO_OBJECT_NULL;
        IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
        
        if (result == kIOReturnSuccess && conn != IO_OBJECT_NULL) {
            // Use Int16 struct but only read/expect 1 byte
            AppleSMCData_Int16 inStruct, outStruct;
            size_t outStructSize = sizeof(AppleSMCData_Int16);

            bzero(&inStruct, sizeof(AppleSMCData_Int16));
            bzero(&outStruct, sizeof(AppleSMCData_Int16));
            
            inStruct.command = 5; // read command
            inStruct.size = 1;    // Size for si8
            inStruct.key = key;
            
            result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(AppleSMCData_Int16), &outStruct, &outStructSize);
            IOServiceClose(conn);

            if (result == kIOReturnSuccess) {
                // Value is in the lower byte of outStruct.value
                *outValue = (int8_t)(outStruct.value & 0xFF);
                success = YES;
            }
        }
        IOObjectRelease(smc);
    }
    return success;
}


// Helper function to read a signed 16-bit integer value from SMC
BOOL getSMCSInt16Value(uint32_t key, int16_t* outValue) { // Specific function for signed
    BOOL success = NO;
    io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    
    if (smc) {
        io_connect_t conn = IO_OBJECT_NULL;
        IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
        
        if (result == kIOReturnSuccess && conn != IO_OBJECT_NULL) {
            AppleSMCData_Int16 inStruct, outStruct; // Use Int16 struct for 2 bytes
            size_t outStructSize = sizeof(AppleSMCData_Int16);

            bzero(&inStruct, sizeof(AppleSMCData_Int16));
            bzero(&outStruct, sizeof(AppleSMCData_Int16));
            
            inStruct.command = 5; // read command
            inStruct.size = 2;    // Size for si16
            inStruct.key = key;
            
            result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(AppleSMCData_Int16), &outStruct, &outStructSize);
            IOServiceClose(conn);

            if (result == kIOReturnSuccess) {
                // Value is in outStruct.value (as uint16_t), cast to int16_t
                *outValue = (int16_t)outStruct.value;
                success = YES;
            }
        }
        IOObjectRelease(smc);
    }
    return success;
}


// Function to get the current power consumption (using original float struct)
float getRawSystemPower(void)
{
    float returnValue = 0;
    
    io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    
    if (smc) {
        
        io_connect_t conn = IO_OBJECT_NULL;
        IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
        
        if (result == kIOReturnSuccess && conn != IO_OBJECT_NULL) {
            
            AppleSMCData_Float inStruct, outStruct; // Use float struct
            size_t outStructSize = sizeof(AppleSMCData_Float);

            bzero(&inStruct, sizeof(AppleSMCData_Float));
            bzero(&outStruct, sizeof(AppleSMCData_Float));
            
            inStruct.command = 5; // read command
            inStruct.size = 4;
            inStruct.key = ('P' << 24) + ('S' << 16) + ('T' << 8) + 'R'; // PSTR key
            
            result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(AppleSMCData_Float), &outStruct, &outStructSize);
            IOServiceClose(conn);

            if (result == kIOReturnSuccess) {
                returnValue = outStruct.value;
            }
        }
        
        IOObjectRelease(smc);
    }
    
    return returnValue;
}

// Function to get the current power input from the adapter
float getAdapterPower(void)
{
    float returnValue = 0;
    
    io_service_t smc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    
    if (smc) {
        
        io_connect_t conn = IO_OBJECT_NULL;
        IOReturn result = IOServiceOpen(smc, mach_task_self(), 1, &conn);
        
        if (result == kIOReturnSuccess && conn != IO_OBJECT_NULL) {
            
            AppleSMCData_Float inStruct, outStruct; // Use float struct
            size_t outStructSize = sizeof(AppleSMCData_Float);

            bzero(&inStruct, sizeof(AppleSMCData_Float));
            bzero(&outStruct, sizeof(AppleSMCData_Float));
            
            inStruct.command = 5; // read command
            inStruct.size = 4; // Assuming float or similar sp format handled by the struct/call
            inStruct.key = ('P' << 24) + ('D' << 16) + ('T' << 8) + 'R'; // PDTR key for DC-In total power
            
            result = IOConnectCallStructMethod(conn, 2, &inStruct, sizeof(AppleSMCData_Float), &outStruct, &outStructSize);
            IOServiceClose(conn);

            if (result == kIOReturnSuccess) {
                // Assuming the value is returned correctly as a float or interpretable as such
                returnValue = outStruct.value;
            }
        }
        
        IOObjectRelease(smc);
    }
    
    return returnValue;
}

// Function to get battery info (status and power)
BatteryInfo getBatteryInfo(void) {
    BatteryInfo info;
    info.status = BATTERY_STATUS_FAILED; // Default to failed
    info.powerWatts = 0.0f;

    int16_t voltage_mV = 0;
    int16_t current_mA = 0; // Signed, positive=charging, negative=discharging

    // Define keys
    uint32_t voltageKey = ('B' << 24) + ('0' << 16) + ('A' << 8) + 'V'; // B0AV (ui16)
    uint32_t currentKey = ('B' << 24) + ('0' << 16) + ('A' << 8) + 'C'; // B0AC (si16)

    uint16_t raw_voltage_mV = 0; // Use uint16_t for B0AV
    BOOL voltageSuccess = getSMCUInt16Value(voltageKey, &raw_voltage_mV);
    voltage_mV = (int16_t)raw_voltage_mV; // Cast for calculation, sign irrelevant here
    
    BOOL currentSuccess = getSMCSInt16Value(currentKey, &current_mA); // Use signed helper for B0AC

    if (voltageSuccess && currentSuccess) {
        // Calculate power: P(W) = V(V) * I(A) = (mV / 1000) * (mA / 1000)
        info.powerWatts = ( (float)voltage_mV / 1000.0f ) * ( (float)current_mA / 1000.0f );

        // Determine status based on current
        if (current_mA > 50) { // Add a small threshold to avoid noise around zero
            info.status = BATTERY_STATUS_CHARGING;
        } else if (current_mA < -50) {
            info.status = BATTERY_STATUS_DISCHARGING;
        } else {
            info.status = BATTERY_STATUS_IDLE; // Near zero current
        }
    }
    // If only one succeeded, status remains FAILED, power remains 0.

    return info;
} // <-- ADDED MISSING CLOSING BRACE FOR getBatteryInfo

// Function to get battery temperature (tries multiple keys)
float getBatteryTemperature(void) {
    float temperature = -999.0f; // Indicate failure
    BOOL success = NO;
    
    // Define potential keys
    uint32_t keysToTry[] = {
        ('T' << 24) + ('B' << 16) + ('0' << 8) + 'T', // TB0T
        ('T' << 24) + ('B' << 16) + ('1' << 8) + 'T', // TB1T
        ('T' << 24) + ('B' << 16) + ('2' << 8) + 'T', // TB2T
        ('T' << 24) + ('B' << 16) + ('3' << 8) + 'T', // TB3T
        ('T' << 24) + ('C' << 16) + ('0' << 8) + 'B'  // TC0B (Another possible battery temp key)
    };
    int numKeys = sizeof(keysToTry) / sizeof(keysToTry[0]);

    for (int i = 0; i < numKeys; ++i) {
        success = getSMCSignedFixedPoint78Value(keysToTry[i], &temperature);
        // If the SMC call itself succeeded, return the value immediately.
        if (success) {
            return temperature; // Found a valid reading
        }
    }

    // If loop finishes without returning, all SMC calls failed for these keys.
    return -999.0f; // Return failure indicator
}

// Function to get battery cycle count
uint16_t getBatteryCycleCount(void) {
    uint16_t cycles = 0xFFFF; // Indicate failure
    uint32_t cycleKey = ('B' << 24) + ('0' << 16) + ('C' << 8) + 'T'; // B0CT (ui16)
    getSMCUInt16Value(cycleKey, &cycles);
    return cycles;
}

// Function to get adapter voltage (Reads D<port>VR as ui16)
float getAdapterVoltage(void) {
    int8_t activePort = 0; // Default to port 0
    uint32_t winnerPortKey = ('A' << 24) + ('C' << 16) + ('-' << 8) + 'W'; // AC-W (si8)
    getSMCSInt8Value(winnerPortKey, &activePort);

    // Ensure port index is within a reasonable range (e.g., 0-4)
    if (activePort < 0 || activePort > 4) {
        activePort = 0;
    }

    uint16_t voltage_mV = 0;
    float voltage_V = -1.0f; // Indicate failure
    // Construct key dynamically: D<port>VR
    uint32_t voltageKey = ('D' << 24) + ((uint32_t)('0' + activePort) << 16) + ('V' << 8) + 'R';
    
    if (getSMCUInt16Value(voltageKey, &voltage_mV)) {
        voltage_V = (float)voltage_mV / 1000.0f;
    }
    // Return -1.0f if read failed, otherwise the voltage (likely 20.000)
    return voltage_V;
}

// Function to get adapter amperage (Calculated from Real-Time Power and Reported Voltage)
float getAdapterAmperage(void) {
    float power = getAdapterPower(); // Get real-time power (PDTR)
    float voltage = getAdapterVoltage(); // Get reported voltage (D<port>VR)
    
    float current_A = -1.0f; // Indicate failure

    // Check if both readings were likely successful and voltage is usable
    // Use PDTR / D<port>VR as D<port>IR seems to report max rated current, not real-time.
    if (power >= 0 && voltage > 0.1f) { // Allow power to be 0
        current_A = power / voltage; // Calculate Amps = Watts / Volts
    }
    
    return current_A;
}

float getBatteryVoltage(void) {
    float bv = 1.0f;
    
    uint16_t batteryVoltage_mV = 0;
    BOOL batteryVoltageSuccess = getSMCUInt16Value(('B' << 24) + ('0' << 16) + ('A' << 8) + 'V', &batteryVoltage_mV);

    if (batteryVoltageSuccess) {
        bv = (float) batteryVoltage_mV / 1000;
    }
    return bv;
}

float getBatteryAmperage(void) {
    float ba = 1.0f;
    
    int16_t batteryAmperage_mA = 0;
    BOOL batteryAmperageSuccess = getSMCSInt16Value(('B' << 24) + ('0' << 16) + ('A' << 8) + 'C', &batteryAmperage_mA);
    
    if (batteryAmperageSuccess) {
        ba = (float) batteryAmperage_mA / 1000;
    }
    return ba;
}

float getBatteryPower(void) {
    float bp = 1.0f;
    bp = getBatteryVoltage() * getBatteryAmperage();
    return bp;
}

NSString* getChargingStatus(void) {
    NSString *myString = @"This is a string to return.";
    float ba = getBatteryAmperage();
    if (ba > 0.05) {
        myString = @"Charging";
    } else {
        myString = @"Idle";
    }
    return myString;
}
