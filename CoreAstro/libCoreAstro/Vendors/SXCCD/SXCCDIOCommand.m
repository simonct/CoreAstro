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
#define SXCCD_CAPS_COOLER               0x10
#define SXCCD_CAPS_SHUTTER              0x20

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
#define SXCCD_EXP_FLAGS_NOCLEAR_REGISTER  128

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
#define SXUSB_OPEN_SHUTTER          32

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

static void sxLatchPixelsWriteData(USHORT camIndex, USHORT flags, USHORT xoffset, USHORT yoffset, USHORT width, USHORT height, USHORT xbin, USHORT ybin, UCHAR setup_data[18])
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAOUT;
    setup_data[USB_REQ         ] = SXUSB_READ_PIXELS;
    setup_data[USB_REQ_VALUE_L ] = flags;
    setup_data[USB_REQ_VALUE_H ] = flags >> 8;
    setup_data[USB_REQ_INDEX_L ] = camIndex;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 10;
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
}

static void sxReadPixelsWriteData(USHORT camIndex, USHORT flags, USHORT xoffset, USHORT yoffset, USHORT width, USHORT height, USHORT xbin, USHORT ybin,UCHAR setup_data[18])
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAOUT;
    setup_data[USB_REQ         ] = SXUSB_READ_PIXELS;
    setup_data[USB_REQ_VALUE_L ] = flags;
    setup_data[USB_REQ_VALUE_H ] = flags >> 8;
    setup_data[USB_REQ_INDEX_L ] = camIndex;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 10;
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

static void sxSetSTAR2000WriteData(BYTE star2k,UCHAR setup_data[8])
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR | USB_REQ_DATAOUT;
    setup_data[USB_REQ         ] = SXUSB_SET_STAR2K;
    setup_data[USB_REQ_VALUE_L ] = star2k;
    setup_data[USB_REQ_VALUE_H ] = 0;
    setup_data[USB_REQ_INDEX_L ] = 0;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 0;
    setup_data[USB_REQ_LENGTH_H] = 0;
    
}

static void sxSetShutterWriteData(UCHAR setup_data[8],USHORT open)
{
    setup_data[USB_REQ_TYPE    ] = USB_REQ_VENDOR;
    setup_data[USB_REQ         ] = SXUSB_OPEN_SHUTTER;
    setup_data[USB_REQ_VALUE_L ] = 0;
    setup_data[USB_REQ_VALUE_H ] = open ? 0x80 : 0x40;
    setup_data[USB_REQ_INDEX_L ] = 0;
    setup_data[USB_REQ_INDEX_H ] = 0;
    setup_data[USB_REQ_LENGTH_L] = 0;
    setup_data[USB_REQ_LENGTH_H] = 0;
}

static void sxSetShutterReadData(const UCHAR setup_data[2],USHORT* state)
{
    *state = setup_data[0] | (setup_data[1] << 8);
}

uint8_t* sxDerotateM26CBuffer(const long lineLength,const long lineCount,uint8_t* workingBuffer)
{
    if (!workingBuffer){
        return NULL;
    }
    
    uint8_t* outputBuffer = NULL;
    
    const long inputLength = lineLength * lineCount * 2;
    if (inputLength > 0){
        
        outputBuffer = malloc(inputLength);
        if (outputBuffer){
            
            const long lineBytes = 2 * lineLength;

            // derotate by copying from the height*width working buffer to the width*height output buffer
            for (long x = lineLength - 1; x >= 0; --x){
                
                const uint8_t* input = workingBuffer + (2 * (lineLength - x)); // move right to left along the input
                uint8_t* output = outputBuffer + inputLength - ((lineLength - x) * 2 * lineCount); // move bottom to top on the output
                
                // copy one column from the input to one row on the output
                for (long y = 0; y < lineCount; ++y){
                    *(uint16_t*)output = *(uint16_t*)input;
                    assert(output >= outputBuffer);
                    output += 2;
                    input += lineBytes; // move down one line
                }
            }
        }
    }
    
    return outputBuffer;
}

// try swapping field1Pixels and field2Pixels to see if there's any different in the final image
static uint8_t* sxReconstructM26CFields1x1(const uint8_t* field2Pixels,const uint8_t* field1Pixels,const long lineLength,const long lineCount)
{
    const long inputLength = lineLength * lineCount * 2;
    const long lineBytes = 2 * lineLength;
    const long lineBytesx2 = 2 * lineBytes;
    const long lineBytesx3 = 3 * lineBytes;
    const long lineBytesx4 = 4 * lineBytes;
    
    uint8_t* outputBuffer = NULL;
    uint8_t* workingBuffer = malloc(inputLength);
    if (workingBuffer){
        
        // set output pointers to output buffer
        uint8_t* outputPtr1 = workingBuffer + lineBytesx2; // starts at line[3]
        uint8_t* outputPtr3 = workingBuffer; // line[1] - 4 // ** originally lineBytes - 4
        uint8_t* outputPtr2 = workingBuffer + inputLength - lineBytesx3; // line[3898] + 4 // ** originally + 4
        uint8_t* outputPtr4 = workingBuffer + inputLength - lineBytes; // line[3900] + 4 ** buffer overrun ** // ** originally + 4
        
        // set input pointers to field 1
        const uint8_t* inputPtr1 = field1Pixels;
        const uint8_t* inputPtr2 = field1Pixels + 2;
        const uint8_t* inputPtr3 = field1Pixels + 4;
        const uint8_t* inputPtr4 = field1Pixels + 6;
        
        // process 1 field's worth of alternate lines
        long i = 0;
        for (long y = 0; y < lineCount; y += 4){
            
            // process a single output line
            for (long x = 0; x < lineLength; x += 2, i += 4){
                
                assert(outputPtr1 - workingBuffer < lineLength * lineCount * 2);
                assert(outputPtr2 - workingBuffer < lineLength * lineCount * 2);
                assert(outputPtr3 >= workingBuffer);
                assert(outputPtr4 >= workingBuffer);
                
                ((uint16_t*)outputPtr1)[x] = ((uint16_t*)inputPtr3)[i]; // green
                ((uint16_t*)outputPtr2)[x] = ((uint16_t*)inputPtr4)[i]; // blue
                ((uint16_t*)outputPtr3)[x] = ((uint16_t*)inputPtr1)[i]; // green
                ((uint16_t*)outputPtr4)[x] = ((uint16_t*)inputPtr2)[i]; // blue
            }
            
            // move outputPtr[1,3] down 4 rows
            outputPtr1 += lineBytesx4;
            outputPtr3 += lineBytesx4;
            
            // move outputPtr[2,4] up 4 rows
            outputPtr2 -= lineBytesx4;
            outputPtr4 -= lineBytesx4;
        }
        
        // reset output pointers to output buffer
        outputPtr1 = workingBuffer + 2; // starts at line[1] + 2
        outputPtr3 = workingBuffer + lineBytesx2 - 2; // starts at line[3] - 2
        outputPtr2 = workingBuffer + inputLength - lineBytesx3 + 2; // line[3898] + 2
        outputPtr4 = workingBuffer + inputLength - lineBytes + 2; // line[3900] + 2 ** buffer overrun **
        
        // reset input pointers to field 1
        inputPtr1 = field2Pixels;
        inputPtr2 = field2Pixels + 2;
        inputPtr3 = field2Pixels + 4;
        inputPtr4 = field2Pixels + 6;
        
        // process 1 field's worth of alternate lines
        i = 0;
        for (long y = 0; y < lineCount; y += 4){
            
            // process a single output line
            for (long x = 0; x < lineLength; x += 2, i += 4){
                
                assert(outputPtr1 - workingBuffer < lineLength * lineCount * 2);
                assert(outputPtr2 - workingBuffer < lineLength * lineCount * 2);
                assert(outputPtr3 >= workingBuffer);
                assert(outputPtr4 >= workingBuffer);
                
                ((uint16_t*)outputPtr1)[x] = ((uint16_t*)inputPtr3)[i]; // green
                ((uint16_t*)outputPtr2)[x] = ((uint16_t*)inputPtr4)[i]; // red
                ((uint16_t*)outputPtr3)[x] = ((uint16_t*)inputPtr1)[i]; // green
                ((uint16_t*)outputPtr4)[x] = ((uint16_t*)inputPtr2)[i]; // red
            }
            
            // move outputPtr[1,3] down 4 rows
            outputPtr1 += lineBytesx4;
            outputPtr3 += lineBytesx4;
            
            // move outputPtr[2,4] up 4 rows
            outputPtr2 -= lineBytesx4;
            outputPtr4 -= lineBytesx4;
        }
        
        outputBuffer = sxDerotateM26CBuffer(lineLength, lineCount, workingBuffer);
        
        free(workingBuffer);

        // normalise...
    }

    return outputBuffer;
}

static uint8_t* sxReconstructM26CFields2x2(const uint8_t* field1Pixels,const uint8_t* field2Pixels,const long lineLength,const long lineCount)
{
    const long inputLength = lineLength * lineCount * 2;
    const long lineBytes = 2 * lineLength;
    const long lineBytesx2 = 2 * lineBytes;
//    const long lineBytesx3 = 3 * lineBytes;

    uint8_t* outputBuffer = NULL;
    uint8_t* workingBuffer = malloc(inputLength);
    if (workingBuffer){
        
        uint8_t* outputPtr1 = workingBuffer + lineBytes + 2; // + 4;
        uint8_t* outputPtr2 = workingBuffer + (lineCount * lineBytes) - lineBytes; // (lineLength*4) + 2;

        const uint8_t* inputPtr1 = field1Pixels;
        const uint8_t* inputPtr2 = field1Pixels + 2;
        
        long i = 0;
        for (long y = 0; y < lineCount/2; ++y){
            for (long x = 0; x < lineLength; x += 2, i += 2){
                ((uint16_t*)outputPtr1)[x] = ((uint16_t*)inputPtr1)[i];
                ((uint16_t*)outputPtr2)[x] = ((uint16_t*)inputPtr2)[i];
            }
            outputPtr1 += lineBytesx2;
            outputPtr2 -= lineBytesx2;
        }
        
        outputPtr1 = workingBuffer + 2; //  + 2 + 4;
        outputPtr2 = workingBuffer + (lineCount * lineBytes) - lineBytesx2; // + 4;
        
        inputPtr1 = field2Pixels;
        inputPtr2 = field2Pixels + 2;
        
        i = 0;
        for (long y = 0; y < lineCount/2; ++y){
            for (long x = 0; x < lineLength; x += 2, i += 2){
                ((uint16_t*)outputPtr1)[x] = ((uint16_t*)inputPtr1)[i];
                ((uint16_t*)outputPtr2)[x] = ((uint16_t*)inputPtr2)[i];
            }
            outputPtr1 += lineBytesx2;
            outputPtr2 -= lineBytesx2;
        }
        
        outputBuffer = sxDerotateM26CBuffer(lineLength, lineCount, workingBuffer);
        
        free(workingBuffer);
    }
    
    return outputBuffer;
}

static uint8_t* sxReconstructM26CFields4x4(const uint8_t* field1Pixels,const uint8_t* field2Pixels,const long lineLength,const long lineCount)
{
    return nil;
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

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: params=%@>",NSStringFromClass([self class]),self.params];
}

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
    
    _params = [[SXCCDProperties alloc] init];
    _params.horizFrontPorch = params.hfront_porch;
    _params.horizBackPorch = params.hback_porch;
    _params.width = params.width;
    _params.vertFrontPorch = params.vfront_porch;
    _params.vertBackPorch = params.vback_porch;
    _params.height = params.height;
    _params.pixelSize = CGSizeMake(params.pix_width, params.pix_height);
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

- (id)init
{
    self = [super init];
    if (self) {
        self.field = kSXCCDIOFieldBoth;
    }
    return self;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: field=%ld, noWipe=%d>",NSStringFromClass([self class]),self.field,self.noWipe];
}

- (NSData*)toDataRepresentation {
    uint8_t buffer[8];
    USHORT flags = 0;
    if (self.noWipe){
        flags = SXCCD_EXP_FLAGS_NOWIPE_FRAME;
    }
    else {
        switch (self.field) {
            default:
            case kSXCCDIOFieldBoth:
                flags = SXCCD_EXP_FLAGS_FIELD_BOTH|SXCCD_EXP_FLAGS_NOCLEAR_REGISTER;
                break;
            case kSXCCDIOFieldEven:
                flags = SXCCD_EXP_FLAGS_FIELD_EVEN|SXCCD_EXP_FLAGS_NOCLEAR_REGISTER;
                break;
            case kSXCCDIOFieldOdd:
                flags = SXCCD_EXP_FLAGS_FIELD_ODD|SXCCD_EXP_FLAGS_NOCLEAR_REGISTER;
                break;
        }
    }
    sxClearPixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,flags,buffer);
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

@end

@interface SXCCDIOExposeCommand ()
@property (nonatomic,strong) NSData* pixels;
@end

@implementation SXCCDIOExposeCommand

@synthesize ms, params, readPixels, pixels = _pixels;

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: field=%ld, readPixels=%d, latchPixels=%d, ms=%ld, params=%@>",
            NSStringFromClass([self class]),self.field,self.readPixels,self.latchPixels,(long)self.ms,NSStringFromCASExposeParams(self.params)];
}

- (NSData*)toDataRepresentation {

    USHORT flags = 0;
    switch (self.field) {
        default:
        case kSXCCDIOFieldBoth:
            flags = SXCCD_EXP_FLAGS_FIELD_BOTH;
            break;
        case kSXCCDIOFieldEven:
            flags = SXCCD_EXP_FLAGS_FIELD_EVEN;
            break;
        case kSXCCDIOFieldOdd:
            flags = SXCCD_EXP_FLAGS_FIELD_ODD;
            break;
    }
    
    const NSInteger height = (self.field == kSXCCDIOFieldBoth) ? self.params.size.height : self.params.size.height/2;
    
    if (self.latchPixels){
        
        uint8_t buffer[18];
        sxLatchPixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,flags,self.params.origin.x,self.params.origin.y,self.params.size.width,height,self.params.bin.width,self.params.bin.height,buffer);
        
        return [NSData dataWithBytes:buffer length:sizeof(buffer)];
    }
    else {
        
        uint8_t buffer[22];
        sxExposePixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,flags,self.params.origin.x,self.params.origin.y,self.params.size.width,height,self.params.bin.width,self.params.bin.height,(uint32_t)self.ms,buffer);
        
        return [NSData dataWithBytes:buffer length:sizeof(buffer)];
    }
}

- (NSInteger) readSize { // have the read as a separate command ?
    if (!self.readPixels){
        return 0;
    }
    return (self.params.size.width / self.params.bin.width) * (self.params.size.height / self.params.bin.height) * (self.params.bps/8); // only currently handling 16-bit bit might have to round so that 14 => 2
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    _pixels = [self postProcessPixels:data];
    return nil;
}

- (NSData*)postProcessPixels:(NSData*)pixels {
    // default is to do nothing
    return pixels;
}

@end

@implementation SXCCDIOExposeCommandM25C

- (BOOL)allowsUnderrun {
    return YES; // for reasons I have yet to figure out I occasionally get 1 row less than I asked for
}

- (NSData*)toDataRepresentation {
    
    if (self.params.bin.width == 3 && self.params.bin.height == 3){
        NSLog(@"SXCCDIOExposeCommandM25C: Replacing 3x3 binning with 4x4");
        CASExposeParams params = self.params;
        params.bin = CASSizeMake(4, 4);
        self.params = params;
    }
    
    const NSUInteger binX = self.params.bin.width;
    const NSUInteger binY = self.params.bin.height;
    const NSUInteger width = 2 * self.params.size.width;
    const NSUInteger height = self.params.size.height / 2;
    const NSUInteger originX = 2 * self.params.origin.x;
    const NSUInteger originY = self.params.origin.y / 2;

    if (self.latchPixels){
        
        uint8_t buffer[18];
        sxLatchPixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,SXCCD_EXP_FLAGS_FIELD_BOTH,originX,originY,width,height,binX,binY,buffer);
        return [NSData dataWithBytes:buffer length:sizeof(buffer)];
    }
    else {
        
        uint8_t buffer[22];
        sxExposePixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,SXCCD_EXP_FLAGS_FIELD_BOTH,originX,originY,width,height,binX,binY,(uint32_t)self.ms,buffer);
        return [NSData dataWithBytes:buffer length:sizeof(buffer)];
    }
}

- (NSData*)postProcessPixels:(NSData*)pixels {
    
    if ([pixels length]){
        
        // sxReconstructM25CFields()
        
        NSMutableData* rearrangedPixels = [NSMutableData dataWithLength:[pixels length]];
        if ([rearrangedPixels length]){
            
            uint16_t* pixelsPtr = (uint16_t*)[pixels bytes];
            uint16_t* rearrangedPixelsPtr = (uint16_t*)[rearrangedPixels bytes];
            
            if (pixelsPtr && rearrangedPixelsPtr){
                
                const size_t width = self.params.size.width/self.params.bin.width;
                
                size_t height = self.params.size.height/self.params.bin.height;
                if ([pixels length] < width * height * sizeof(uint16_t)){
                    height = [pixels length] / (width * sizeof(uint16_t));
                    NSLog(@"Reset height to %ld after receiving %ld bytes",height,[pixels length]);
                }
                
                size_t i = 0;
                for (size_t y = 0; y < height; y += 2){
                    for (size_t x = 0; x < width; x += 1){
                        rearrangedPixelsPtr[x + (y * width)] = pixelsPtr[i++];
                        rearrangedPixelsPtr[x + ((y+1) * width)] = pixelsPtr[i++];
                    }
                }
                
                memcpy((void*)[pixels bytes], [rearrangedPixels bytes], [pixels length]);
            }
        }
    }
    
    return pixels;
}

@end

@implementation SXCCDIOExposeCommandM26C

- (NSData*)toDataRepresentation {
    
    // todo; limit binning to 1, 2 & 4
    
    USHORT flags = 0;
    switch (self.field) {
        default:
        case kSXCCDIOFieldBoth:
            flags = SXCCD_EXP_FLAGS_FIELD_BOTH;
            break;
        case kSXCCDIOFieldEven:
            flags = SXCCD_EXP_FLAGS_FIELD_EVEN;
            break;
        case kSXCCDIOFieldOdd:
            flags = SXCCD_EXP_FLAGS_FIELD_ODD;
            break;
    }
    
    // note that we're swapping width and height on the params sent to the M26C
    const NSInteger height = (self.field == kSXCCDIOFieldBoth) ? self.params.size.width/2 : self.params.size.width/4;
    const NSInteger width = self.params.size.height * 2;
    
    NSInteger binx;
    NSInteger biny;
    if (self.params.bin.width == 4 && self.params.bin.height == 4){
        binx = 8;
        biny = 2;
    }
    else if (self.params.bin.width == 2 && self.params.bin.height == 2){
        binx = 4;
        biny = 1;
    }
    else {
        binx = 1;
        biny = 1;
    }
    
    if (self.latchPixels){
        
        uint8_t buffer[18];
        sxLatchPixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,flags,self.params.origin.x,self.params.origin.y,width,height,binx,biny,buffer);
        
        return [NSData dataWithBytes:buffer length:sizeof(buffer)];
    }
    else {
        
        uint8_t buffer[22];
        sxExposePixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,flags,self.params.origin.x,self.params.origin.y,width,height,binx,biny,(uint32_t)self.ms,buffer);
        
        return [NSData dataWithBytes:buffer length:sizeof(buffer)];
    }
}

- (NSData*)postProcessPixels:(NSData*)pixels {
    
//    NSString* filename = [NSString stringWithFormat:@"m26c%ldx%ld.pixels",self.params.bin.width,self.params.bin.height];
//    [pixels writeToFile:[@"/Users/simon/Desktop/" stringByAppendingPathComponent:filename] atomically:YES];
    
    const long lineCount = self.params.size.width/self.params.bin.width;
    const long lineLength = self.params.size.height/self.params.bin.height;

    if ([pixels length] == (lineCount * lineLength * 2)){
        
        const uint8_t* inputBuffer = [pixels bytes];
        const NSInteger inputLength = [pixels length];
        
        const uint8_t* field1Pixels = inputBuffer;
        const uint8_t* field2Pixels = inputBuffer + inputLength/2;

        uint8_t* outputBuffer = nil;
        
        if (self.params.bin.width == 1 && self.params.bin.height == 1){
            outputBuffer = sxReconstructM26CFields1x1(field1Pixels,field2Pixels,lineLength,lineCount);
        }
        else if (self.params.bin.width == 2 && self.params.bin.height == 2){
            outputBuffer = sxReconstructM26CFields2x2(field1Pixels,field2Pixels,lineLength,lineCount);
        }

        return outputBuffer ? [NSData dataWithBytesNoCopy:outputBuffer length:inputLength freeWhenDone:YES] : pixels;
    }
    
    return pixels;
}

@end

@implementation SXCCDIOExposeCommandInterlaced

- (id)init
{
    self = [super init];
    if (self) {
        self.field = kSXCCDIOFieldBoth;
    }
    return self;
}

- (NSInteger) readSize {
    NSInteger count = [super readSize];
    
    if (self.field != kSXCCDIOFieldBoth){
        count /= 2;
    }
    
//    NSLog(@"-[SXCCDIOExposeCommandInterlaced readSize]: %ld",count);

    return count;
}

- (NSError*)fromDataRepresentation:(NSData*)data {

//    NSLog(@"-[SXCCDIOExposeCommandInterlaced fromDataRepresentation]: %ld",[data length]);

    self.pixels = data; // don't post process as we're reading fields
    
    return nil;
}

- (NSData*)toDataRepresentation {
    
    if (self.params.bin.width == 3 && self.params.bin.height == 3){
        NSLog(@"SXCCDIOExposeCommandInterlaced: Replacing 3x3 binning with 4x4");
        CASExposeParams modParams = self.params;
        modParams.bin = CASSizeMake(4, 4);
        self.params = modParams;
    }
    
    return [super toDataRepresentation];
}

- (NSData*)postProcessPixels:(NSData*)pixels {
    
    if ([pixels length] && self.params.bin.width == 1 && self.params.bin.height == 1){
        
        NSMutableData* rearrangedPixels = [NSMutableData dataWithLength:[pixels length]];
        if ([rearrangedPixels length]){
            
            uint16_t* pixelsPtr = (uint16_t*)[pixels bytes];
            uint16_t* rearrangedPixelsPtr = (uint16_t*)[rearrangedPixels bytes];
            
            if (pixelsPtr && rearrangedPixelsPtr){
                
                const unsigned long width = self.params.size.width/self.params.bin.width;
                const unsigned long height = self.params.size.height/self.params.bin.height;
                const unsigned long count = (width * height);
                
                unsigned long i = 0;
                double evenAverage = 0, oddAverage = 0, finalOddAverage = 0;
                
                // copy even field, accumulating average pixel value
                for (unsigned long y = 0; y < height; y += 2){
                    for (unsigned long x = 0; x < width; x += 1){
                        const uint16_t p = pixelsPtr[i++];
                        rearrangedPixelsPtr[x + (y * width)] = p;
                        evenAverage += p;
                    }
                }
                evenAverage /= count/2;
                
                // copy odd field, accumulating average pixel value
                for (unsigned long y = 1; y < height; y += 2){
                    for (unsigned long x = 0; x < width; x += 1){
                        const uint16_t p = pixelsPtr[i++];
                        rearrangedPixelsPtr[x + (y * width)] = p;
                        oddAverage += p;
                    }
                }
                oddAverage /= count/2;

                // correct odd field intensity
                const float ratio = (evenAverage == 0) ? 0 : oddAverage/evenAverage;
                if (ratio != 0){
                    for (unsigned long y = 1; y < height; y += 2){
                        for (unsigned long x = 0; x < width; x += 1){
                            const uint16_t p = MAX(MIN(rearrangedPixelsPtr[x + (y * width)] / ratio, 65535), 0); // prevent zebraing (make configurable ? can be quite quite handy)
                            rearrangedPixelsPtr[x + (y * width)] = p;
                            finalOddAverage += p;
                        }
                    }
                }
                finalOddAverage /= count/2;
                
//                NSLog(@"even %f, odd %f, final %f",evenAverage,oddAverage,finalOddAverage);

                memcpy((void*)[pixels bytes], [rearrangedPixels bytes], [pixels length]);
            }
        }
    }
    
    return pixels;
}

@end

@implementation SXCCDIOReadCommand {
@protected
    NSData* _pixels;
}

@synthesize params, pixels = _pixels;

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: params=%@>",NSStringFromClass([self class]),NSStringFromCASExposeParams(self.params)];
}

- (NSInteger) readSize {
    return (self.params.size.width / self.params.bin.width) * (self.params.size.height / self.params.bin.height) * (self.params.bps/8); // round so that 14 => 2
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    _pixels = data;
    return nil;
}

@end

@implementation SXCCDIOReadFieldCommand

- (NSInteger) readSize {
    NSInteger count = [super readSize];
    if (self.field != kSXCCDIOFieldBoth){
        count /= 2;
    }
    return count;
}

- (NSData*)toDataRepresentation {
    
    uint8_t buffer[18];
    
    NSInteger fieldFlag = SXCCD_EXP_FLAGS_FIELD_ODD;
    NSInteger binX = self.params.bin.width;
    NSInteger binY = self.params.bin.height;
    const NSInteger height = self.params.size.height / 2;
    
    switch (self.field) {
        case kSXCCDIOFieldOdd:
            fieldFlag = SXCCD_EXP_FLAGS_FIELD_ODD;
            break;
        case kSXCCDIOFieldEven:
            fieldFlag = SXCCD_EXP_FLAGS_FIELD_EVEN;
            break;
        case kSXCCDIOFieldBoth:
            fieldFlag = SXCCD_EXP_FLAGS_FIELD_BOTH;
            binY /= 2;
            break;
    }
    
//    NSLog(@"SXCCDIOReadFieldCommand: field=%ld, height=%ld, binX=%ld, binY=%ld",self.field,height,binX,binY);
    
    sxReadPixelsWriteData(SXUSB_MAIN_CAMERA_INDEX,fieldFlag,self.params.origin.x,self.params.origin.y,self.params.size.width,height,binX,binY,buffer);
    
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    if (!_pixels){
        _pixels = data;
    }
    else {
        const NSInteger length = [_pixels length] + [data length];
        uint8_t* final = malloc(length);
        if (final){
            memcpy(final, [_pixels bytes], [_pixels length]);
            memcpy(final + [_pixels length], [data bytes], [data length]);
            _pixels = [NSData dataWithBytesNoCopy:final length:length freeWhenDone:YES];
        }
    }
    return nil;
}

@end

@implementation SXCCDIOCoolerCommand

@synthesize centigrade, on;

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: on=%d, centigrade=%f>",NSStringFromClass([self class]),self.on,self.centigrade];
}

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

@implementation SXCCDIOGuideCommand

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: direction=%d>",NSStringFromClass([self class]),self.direction];
}

- (NSData*)toDataRepresentation {
    uint8_t buffer[8];
    sxSetSTAR2000WriteData(self.direction,buffer);
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

@end

@implementation SXCCDIOShutterCommand

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: open=%d>",NSStringFromClass([self class]),self.open];
}

- (NSData*)toDataRepresentation {
    uint8_t buffer[8];
    sxSetShutterWriteData(buffer,self.open);
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSInteger) readSize {
    return 2;
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    
    NSError* error = nil;
    
    USHORT open = 0;
    sxSetShutterReadData([data bytes],&open);
    
    self.open = (open == 0x80);
    
    return error;
}

@end
