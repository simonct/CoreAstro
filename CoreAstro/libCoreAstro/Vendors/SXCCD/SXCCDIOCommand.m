//
//  SXCCDIOCommand.m
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
// 
//  Permission is hereby granted, free of charge, to any person obtaining a copy 
//  of this software and associated documentation files (the "Software"), to deal 
//  in the Software without restriction, including without limitation the rights 
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
//  copies of the Software, and to permit persons to whom the Software is furnished 
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//
//  SX command classes, portions derived from code Copyright (c) 2003 David Schmenk
//

/*
 Copyright (c) 2003 David Schmenk
 
 All rights reserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a
 copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, and/or sell copies of the Software, and to permit persons
 to whom the Software is furnished to do so, provided that the above
 copyright notice(s) and this permission notice appear in all copies of
 the Software and that both the above copyright notice(s) and this
 permission notice appear in supporting documentation.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
 OF THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 HOLDERS INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL
 INDIRECT OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING
 FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
 WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 
 Except as contained in this notice, the name of a copyright holder
 shall not be used in advertising or otherwise to promote the sale, use
 or other dealings in this Software without prior written authorization
 of the copyright holder.
*/

#import "SXCCDIOCommand.h"

#define USHORT      uint16_t
#define BYTE        int8_t
#define LONG        int32_t
#define ULONG       uint32_t
#define HANDLE      int32_t
#define UCHAR       uint8_t
#define DWORD       int32_t

/*
 * CCD color representation.
 *  Packed colors allow individual sizes up to 16 bits.
 *  2X2 matrix bits are represented as:
 *      0 1
 *      2 3
 */
#define SXCCD_COLOR_PACKED_RGB          0x8000
#define SXCCD_COLOR_PACKED_BGR          0x4000
#define SXCCD_COLOR_PACKED_RED_SIZE     0x0F00
#define SXCCD_COLOR_PACKED_GREEN_SIZE   0x00F0
#define SXCCD_COLOR_PACKED_BLUE_SIZE    0x000F
#define SXCCD_COLOR_MATRIX_ALT_EVEN     0x2000
#define SXCCD_COLOR_MATRIX_ALT_ODD      0x1000
#define SXCCD_COLOR_MATRIX_2X2          0x0000
#define SXCCD_COLOR_MATRIX_RED_MASK     0x0F00
#define SXCCD_COLOR_MATRIX_GREEN_MASK   0x00F0
#define SXCCD_COLOR_MATRIX_BLUE_MASK    0x000F
#define SXCCD_COLOR_MONOCHROME          0x0FFF

/*
 * Caps bit definitions.
 */
#define SXCCD_CAPS_STAR2K               0x01
#define SXCCD_CAPS_COMPRESS             0x02
#define SXCCD_CAPS_EEPROM               0x04
#define SXCCD_CAPS_GUIDER               0x08

/*
 * CCD command options.
 */
#define SXCCD_EXP_FLAGS_FIELD_ODD     	1
#define SXCCD_EXP_FLAGS_FIELD_EVEN    	2
#define SXCCD_EXP_FLAGS_FIELD_BOTH    	(SXCCD_EXP_FLAGS_FIELD_EVEN|SXCCD_EXP_FLAGS_FIELD_ODD)
#define SXCCD_EXP_FLAGS_FIELD_MASK    	SXCCD_EXP_FLAGS_FIELD_BOTH
#define SXCCD_EXP_FLAGS_NOBIN_ACCUM   	4
#define SXCCD_EXP_FLAGS_NOWIPE_FRAME  	8
#define SXCCD_EXP_FLAGS_TDI             32
#define SXCCD_EXP_FLAGS_NOCLEAR_FRAME 	64

/*
 * Control request fields.
 */
#define USB_REQ_TYPE                0
#define USB_REQ                     1
#define USB_REQ_VALUE_L             2
#define USB_REQ_VALUE_H             3
#define USB_REQ_INDEX_L             4
#define USB_REQ_INDEX_H             5
#define USB_REQ_LENGTH_L            6
#define USB_REQ_LENGTH_H            7
#define USB_REQ_DATA                8
#define USB_REQ_DIR(r)              ((r)&(1<<7))
#define USB_REQ_DATAOUT             0x00
#define USB_REQ_DATAIN              0x80
#define USB_REQ_KIND(r)             ((r)&(3<<5))
#define USB_REQ_VENDOR              (2<<5)
#define USB_REQ_STD                 0
#define USB_REQ_RECIP(r)            ((r)&31)
#define USB_REQ_DEVICE              0x00
#define USB_REQ_IFACE               0x01
#define USB_REQ_ENDPOINT            0x02
#define USB_DATAIN                  0x80
#define USB_DATAOUT                 0x00

/*
 * CCD camera control commands.
 */
#define SXUSB_GET_FIRMWARE_VERSION  255
#define SXUSB_ECHO                  0
#define SXUSB_CLEAR_PIXELS          1
#define SXUSB_READ_PIXELS_DELAYED   2
#define SXUSB_READ_PIXELS           3
#define SXUSB_SET_TIMER             4
#define SXUSB_GET_TIMER             5
#define SXUSB_RESET                 6
#define SXUSB_SET_CCD               7
#define SXUSB_GET_CCD               8
#define SXUSB_SET_STAR2K            9
#define SXUSB_WRITE_SERIAL_PORT     10
#define SXUSB_READ_SERIAL_PORT      11
#define SXUSB_SET_SERIAL            12
#define SXUSB_GET_SERIAL            13
#define SXUSB_CAMERA_MODEL          14
#define SXUSB_LOAD_EEPROM           15
#define SXUSB_GETSET_COOLER         30

#define SXUSB_MAIN_CAMERA_INDEX     0
#define SXUSB_GUIDE_CAMERA_INDEX    1

struct t_sxccd_params
{
    USHORT hfront_porch;
    USHORT hback_porch;
    USHORT width;
    USHORT vfront_porch;
    USHORT vback_porch;
    USHORT height;
    float  pix_width;
    float  pix_height;
    USHORT color_matrix;
    BYTE   bits_per_pixel;
    BYTE   num_serial_ports;
    BYTE   extra_caps;
    BYTE   vclk_delay;
};

struct t_sxccd_cooler
{
    float tempDegC;
    bool  on;
};

static void sxCommandSetup(UCHAR setup_data[8],USHORT command)
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAOUT;
    setup_data[USB_REQ         ] = command;
    setup_data[USB_REQ_VALUE_L ] = 0;
    setup_data[USB_REQ_VALUE_H ] = 0;
    setup_data[USB_REQ_INDEX_L ] = 0;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 0;
    setup_data[USB_REQ_LENGTH_H] = 0;
}

static void sxResetWriteData(UCHAR setup_data[8])
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAOUT;
    setup_data[USB_REQ         ] = SXUSB_RESET;
    setup_data[USB_REQ_VALUE_L ] = 0;
    setup_data[USB_REQ_VALUE_H ] = 0;
    setup_data[USB_REQ_INDEX_L ] = 0;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 0;
    setup_data[USB_REQ_LENGTH_H] = 0;
}

static void sxGetCameraParamsWriteData(USHORT camIndex, UCHAR setup_data[17])
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAIN;
    setup_data[USB_REQ         ] = SXUSB_GET_CCD;
    setup_data[USB_REQ_VALUE_L ] = 0;
    setup_data[USB_REQ_VALUE_H ] = 0;
    setup_data[USB_REQ_INDEX_L ] = camIndex;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 17;
    setup_data[USB_REQ_LENGTH_H] = 0;
}

static void sxGetCameraParamsReadData(const UCHAR setup_data[17], struct t_sxccd_params *params)
{
    params->hfront_porch = setup_data[0];
    params->hback_porch = setup_data[1];
    params->width = setup_data[2] | (setup_data[3] << 8);
    params->vfront_porch = setup_data[4];
    params->vback_porch = setup_data[5];
    params->height = setup_data[6] | (setup_data[7] << 8);
    params->pix_width = (setup_data[8] | (setup_data[9] << 8)) / 256.0;
    params->pix_height = (setup_data[10] | (setup_data[11] << 8)) / 256.0;
    params->color_matrix = setup_data[12] | (setup_data[13] << 8);
    params->bits_per_pixel = setup_data[14];
    params->num_serial_ports = setup_data[15];
    params->extra_caps = setup_data[16];
    params->vclk_delay = 0; // ??
}

static void sxClearPixelsWriteData(USHORT camIndex, USHORT flags,  UCHAR setup_data[8])
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAOUT;
    setup_data[USB_REQ         ] = SXUSB_CLEAR_PIXELS;
    setup_data[USB_REQ_VALUE_L ] = flags;
    setup_data[USB_REQ_VALUE_H ] = flags >> 8;
    setup_data[USB_REQ_INDEX_L ] = camIndex;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 0;
    setup_data[USB_REQ_LENGTH_H] = 0;
}

static void sxExposePixelsWriteData(USHORT camIndex, USHORT flags, USHORT xoffset, USHORT yoffset, USHORT width, USHORT height, USHORT xbin, USHORT ybin, ULONG msec,UCHAR setup_data[22])
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAOUT;
    setup_data[USB_REQ         ] = SXUSB_READ_PIXELS_DELAYED;
    setup_data[USB_REQ_VALUE_L ] = flags;
    setup_data[USB_REQ_VALUE_H ] = flags >> 8;
    setup_data[USB_REQ_INDEX_L ] = camIndex;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 14;
    setup_data[USB_REQ_LENGTH_H] = 0;
    setup_data[USB_REQ_DATA + 0] = xoffset & 0xFF;
    setup_data[USB_REQ_DATA + 1] = xoffset >> 8;
    setup_data[USB_REQ_DATA + 2] = yoffset & 0xFF;
    setup_data[USB_REQ_DATA + 3] = yoffset >> 8;
    setup_data[USB_REQ_DATA + 4] = width & 0xFF;
    setup_data[USB_REQ_DATA + 5] = width >> 8;
    setup_data[USB_REQ_DATA + 6] = height & 0xFF;
    setup_data[USB_REQ_DATA + 7] = height >> 8;
    setup_data[USB_REQ_DATA + 8] = xbin;
    setup_data[USB_REQ_DATA + 9] = ybin;
    setup_data[USB_REQ_DATA + 10] = msec;
    setup_data[USB_REQ_DATA + 11] = msec >> 8;
    setup_data[USB_REQ_DATA + 12] = msec >> 16;
    setup_data[USB_REQ_DATA + 13] = msec >> 24;
}

static void sxCoolerWriteData(UCHAR setup_data[8],float tempDegC,bool on)
{
    const uint16_t tempDegK = floor((273 + tempDegC) * 10);
    
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAOUT;
    setup_data[USB_REQ         ] = SXUSB_GETSET_COOLER;
    setup_data[USB_REQ_VALUE_L ] = tempDegK & 0x00ff;
    setup_data[USB_REQ_VALUE_H ] = (tempDegK >> 8) & 0x00ff;
    setup_data[USB_REQ_INDEX_L ] = on;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 0;
    setup_data[USB_REQ_LENGTH_H] = 0;
}

static void sxCoolerReadData(const UCHAR response[3],struct t_sxccd_cooler* params)
{
    params->tempDegC = (response[1] << 8 | response[0])/10.0 - 273;
    params->on = response[2] != 0;
}

@implementation SXCCDIOResetCommand

- (NSData*)toDataRepresentation {
    uint8_t buffer[8];
    sxResetWriteData(buffer);
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

@end

@implementation SXCCDIOEchoCommand

@synthesize data = _data,response;

- (id)initWithData:(NSData*)data {
    self = [super init];
    if (self){
        self.data = data;        
    }
    return self;
}

- (NSData*)toDataRepresentation {
    
    uint8_t buffer[8];
    sxCommandSetup(buffer,SXUSB_ECHO);
    buffer[6] = [self.data length];
    buffer[7] = 0;

    NSMutableData* request = [NSMutableData dataWithLength:sizeof(buffer) + [self.data length]];
    if ([request mutableBytes]){
        memcpy([request mutableBytes], buffer, sizeof(buffer));
        memcpy([request mutableBytes] + sizeof(buffer), [self.data bytes], [self.data length]);
    }
    
    return request;
}

- (NSInteger) readSize {
    return [self.data length];
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    self.response = data;
    return nil;
}

@end

@implementation SXCCDIOGetParamsCommand

@synthesize params = _params;

- (NSData*)toDataRepresentation {
    uint8_t buffer[8];
    sxGetCameraParamsWriteData(SXUSB_MAIN_CAMERA_INDEX,buffer);
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSInteger) readSize {
    return 17;
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    
    NSError* error = nil;
    
    struct t_sxccd_params params;
    sxGetCameraParamsReadData([data bytes],&params);
    
    _params = [[SXCCDParams alloc] init];
    _params.horizFrontPorch = params.hfront_porch;
    _params.horizBackPorch = params.hback_porch;
    _params.width = params.width;
    _params.vertFrontPorch = params.vfront_porch;
    _params.vertBackPorch = params.vback_porch;
    _params.height = params.height;
    _params.pixelWidth = params.pix_width;
    _params.pixelHeight = params.pix_height;
    _params.colourMatrix = params.color_matrix;
    _params.bitsPerPixel = params.bits_per_pixel;
    _params.serialPortCount = params.num_serial_ports;
    _params.capabilities = params.extra_caps;
    _params.vertClockDelay = params.vclk_delay;

//    NSLog(@"(1) hfront_porch: %d, hback_porch: %d, width: %d, vfront_porch: %d, vback_porch: %d, height: %d, pix_width: %f, pix_height: %f, color_matrix: %d, bits_per_pixel: %d, num_serial_ports: %d, extra_caps: %d, vclk_delay: %d",
//          params.hfront_porch,params.hback_porch,params.width,params.vfront_porch,params.vback_porch,
//          params.height,params.pix_width,params.pix_height,params.color_matrix, params.bits_per_pixel,
//          params.num_serial_ports,params.extra_caps,params.vclk_delay);
//    
//    NSLog(@"capabilities: STAR2000_PORT: %d, COMPRESSED_PIXEL_FORMAT: %d, EEPROM: %d, INTEGRATED_GUIDER_CCD: %d",(params.extra_caps & 1) != 0,(params.extra_caps & (1 << 1)) != 0,(params.extra_caps & (1 << 2)) != 0,(params.extra_caps & (1 << 3)) != 0);
    
    return error;
}

@end

@implementation SXCCDIOFlushCommand

- (NSData*)toDataRepresentation {
    uint8_t buffer[8];
    sxClearPixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,8,buffer);
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

@end

@implementation SXCCDIOExposeCommand

@synthesize ms, params, readPixels, pixels = _pixels;

- (NSData*)toDataRepresentation {
    uint8_t buffer[22];
    sxExposePixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,SXCCD_EXP_FLAGS_FIELD_BOTH,self.params.origin.x,self.params.origin.y,self.params.size.width,self.params.size.height,self.params.bin.width,self.params.bin.height,(uint32_t)self.ms,buffer);
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSInteger) readSize { // have the read as a separate command ?
    if (!self.readPixels){
        return 0;
    }
    return (self.params.size.width / self.params.bin.width) * (self.params.size.height / self.params.bin.height) * (self.params.bps/8); // only currently handling 16-bit bit might have to round so that 14 => 2
}

- (BOOL) allowsUnderrun {
    return self.readPixels; // as I seem to be reading 2 bytes less than requested, probably an arithmatic problem somewhere (check this is still the case)
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    _pixels = data;
    return nil;
}

@end

@implementation SXCCDIOReadCommand

@synthesize params, pixels = _pixels;

- (NSInteger) readSize {
    return (self.params.size.width / self.params.bin.width) * (self.params.size.height / self.params.bin.height) * (self.params.bps/8); // round so that 14 => 2
}

- (BOOL) allowsUnderrun {
    return YES;
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    _pixels = data;
    return nil;
}

@end

@implementation SXCCDIOCoolerCommand

@synthesize centigrade, on;

- (NSData*)toDataRepresentation {
    uint8_t buffer[8];
    sxCoolerWriteData(buffer,self.centigrade,self.on);
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSInteger) readSize {
    return 3;
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    
    NSError* error = nil;
    
    struct t_sxccd_cooler params;
    sxCoolerReadData([data bytes],&params);
    
    self.centigrade = params.tempDegC;
    self.on = params.on;
    
//    NSLog(@"data=%@, tempDegC=%f on=%d",data,params.tempDegC,params.on);
    
    return error;
}

@end



