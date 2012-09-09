/***************************************************************************\

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

\***************************************************************************/
#if TARGET_OS_MAC

#import <stdint.h>

#define DLL_EXPORT
#define USHORT      uint16_t
#define BYTE        int8_t
#define LONG        int32_t
#define ULONG       uint32_t
#define HANDLE      int32_t
#define UCHAR       uint8_t
#define DWORD       int32_t

extern uint32_t WriteFile(HANDLE, UCHAR*, ULONG, ULONG*, void*);
extern uint32_t ReadFile(HANDLE, UCHAR*, ULONG, ULONG*, void*);

#else

#ifdef __cplusplus
#define DLL_EXPORT                    extern "C" __declspec(dllexport)
#else
#define DLL_EXPORT                    __declspec(dllexport)
#endif

#endif

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
/*
 * Serial port queries.
 */
#define	SXCCD_SERIAL_PORT_AVAIL_OUTPUT	0
#define	SXCCD_SERIAL_PORT_AVAIL_INPUT	1
/*
 * Limits.
 */
#define	SXCCD_MAX_CAMS                 	2
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
/*
 * Prototypes.
 */

DLL_EXPORT void sxCommandSetup(UCHAR[8],USHORT command);

DLL_EXPORT void sxResetWriteData(UCHAR[8]);
DLL_EXPORT LONG sxReset(HANDLE sxHandle);

DLL_EXPORT void sxClearPixelsWriteData(USHORT flags, USHORT camIndex,UCHAR[8]);
DLL_EXPORT LONG sxClearPixels(HANDLE sxHandle, USHORT flags, USHORT camIndex);

DLL_EXPORT void sxLatchPixelsWriteData(USHORT flags, USHORT camIndex, USHORT xoffset, USHORT yoffset, USHORT width, USHORT height, USHORT xbin, USHORT ybin, UCHAR[18]);
DLL_EXPORT LONG sxLatchPixels(HANDLE sxHandle, USHORT flags, USHORT camIndex, USHORT xoffset, USHORT yoffset, USHORT width, USHORT height, USHORT xbin, USHORT ybin);

DLL_EXPORT void sxExposePixelsWriteData(USHORT flags, USHORT camIndex, USHORT xoffset, USHORT yoffset, USHORT width, USHORT height, USHORT xbin, USHORT ybin, ULONG msec,UCHAR[22]);
DLL_EXPORT LONG sxExposePixels(HANDLE sxHandle, USHORT flags, USHORT camIndex, USHORT xoffset, USHORT yoffset, USHORT width, USHORT height, USHORT xbin, USHORT ybin, ULONG msec);

DLL_EXPORT LONG sxReadPixels(HANDLE sxHandle, USHORT *pixels, ULONG count);

DLL_EXPORT void sxSetTimerWriteData(ULONG msec,UCHAR setup_data[12]);
DLL_EXPORT ULONG sxSetTimer(HANDLE sxHandle, ULONG msec);

DLL_EXPORT void sxGetTimerWriteData(UCHAR setup_data[8]);
DLL_EXPORT ULONG sxGetTimerReadData(const UCHAR setup_data[4]);
DLL_EXPORT ULONG sxGetTimer(HANDLE sxHandle);

DLL_EXPORT void sxGetCameraParamsWriteData(USHORT camIndex, UCHAR setup_data[17]);
DLL_EXPORT void sxGetCameraParamsReadData(const UCHAR setup_data[17], struct t_sxccd_params *params);
DLL_EXPORT ULONG sxGetCameraParams(HANDLE sxHandle, USHORT camIndex, struct t_sxccd_params *params);

DLL_EXPORT void sxSetSTAR2000WriteData(BYTE star2k,UCHAR setup_data[8]);
DLL_EXPORT ULONG sxSetSTAR2000(HANDLE sxHandle, BYTE star2k);

DLL_EXPORT ULONG sxSetSerialPort(HANDLE sxHandle, USHORT portIndex, USHORT property, ULONG value);
DLL_EXPORT USHORT sxGetSerialPort(HANDLE sxHandle, USHORT portIndex, USHORT property);
DLL_EXPORT ULONG sxWriteSerialPort(HANDLE sxHandle, USHORT camIndex, USHORT flush, USHORT count, BYTE *data);
DLL_EXPORT ULONG sxReadSerialPort(HANDLE sxHandle, USHORT camIndex, USHORT count, BYTE *data);

DLL_EXPORT void sxGetCameraModelWriteData(UCHAR setup_data[8]);
DLL_EXPORT USHORT sxGetCameraModelReadData(const UCHAR setup_data[2]);
DLL_EXPORT USHORT sxGetCameraModel(HANDLE sxHandle);

DLL_EXPORT ULONG sxReadEEPROM(HANDLE sxHandle, USHORT address, USHORT count, BYTE *data);
DLL_EXPORT ULONG sxGetFirmwareVersion(HANDLE sxHandle);
DLL_EXPORT int sxOpen(HANDLE *sxHandles);
DLL_EXPORT void sxClose(HANDLE sxHandle);
#ifdef SXCCD_DANGEROUS
DLL_EXPORT ULONG sxSetCameraParams(HANDLE sxHandle, USHORT camIndex, struct t_sxccd_params *params);
DLL_EXPORT ULONG sxSetCameraModel(HANDLE sxHandle, USHORT model);
DLL_EXPORT ULONG sxWriteEEPROM(HANDLE sxHandle, USHORT address, USHORT count, BYTE *data, USHORT admin_code);
#endif
