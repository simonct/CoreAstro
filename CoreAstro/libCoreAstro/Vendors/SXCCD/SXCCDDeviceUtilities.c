//
//  SXCCDDeviceUtilities.c
//  SX IO
//
//  Created by Simon Taylor on 10/24/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#include "SXCCDDeviceUtilities.h"
#include <stdlib.h>
#include <assert.h>

static uint8_t* sxDerotateM26CBuffer(const long lineLength,const long lineCount,uint8_t* workingBuffer)
{
    if (!workingBuffer){
        return NULL;
    }
    
    uint8_t* outputBuffer = NULL;
    
    const long inputLength = lineLength * lineCount * 2;
    if (inputLength > 0){
        
        outputBuffer = calloc(inputLength,1);
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
uint8_t* sxReconstructM26CFields1x1(const uint8_t* field2Pixels,const uint8_t* field1Pixels,const long lineLength,const long lineCount)
{
    const long inputLength = lineLength * lineCount * 2;
    const long lineBytes = 2 * lineLength;
    const long lineBytesx2 = 2 * lineBytes;
    const long lineBytesx3 = 3 * lineBytes;
    const long lineBytesx4 = 4 * lineBytes;
    
    uint8_t* outputBuffer = NULL;
    uint8_t* workingBuffer = calloc(inputLength,1);
    if (workingBuffer){
        
        // set output pointers to output buffer
        uint8_t* outputPtr1 = workingBuffer + lineBytesx2;
        uint8_t* outputPtr3 = workingBuffer;
        uint8_t* outputPtr2 = workingBuffer + inputLength - lineBytesx3;
        uint8_t* outputPtr4 = workingBuffer + inputLength - lineBytes;
        
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
        outputPtr1 = workingBuffer + 2;
        outputPtr3 = workingBuffer + lineBytesx2 - 2;
        outputPtr2 = workingBuffer + inputLength - lineBytesx3 + 2;
        outputPtr4 = workingBuffer + inputLength - lineBytes + 2;
        
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

uint8_t* sxReconstructM26CFields2x2(const uint8_t* field1Pixels,const uint8_t* field2Pixels,const long lineLength,const long lineCount)
{
    const long inputLength = lineLength * lineCount * 2;
    const long lineBytes = 2 * lineLength;
    const long lineBytesx2 = 2 * lineBytes;
    
    uint8_t* outputBuffer = NULL;
    uint8_t* workingBuffer = calloc(inputLength,1);
    if (workingBuffer){
        
        uint8_t* outputPtr1 = workingBuffer + lineBytes + 2;
        uint8_t* outputPtr2 = workingBuffer + (lineCount * lineBytes) - lineBytes;
        
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
        
        outputPtr1 = workingBuffer + 2;
        outputPtr2 = workingBuffer + (lineCount * lineBytes) - lineBytesx2;
        
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

uint8_t* sxReconstructM26CFields4x4(const uint8_t* field1Pixels,const uint8_t* field2Pixels,const long lineLength,const long lineCount)
{
    const long inputLength = lineLength * lineCount * 2;
    const long lineBytes = 2 * lineLength;
    
    uint8_t* outputBuffer = NULL;
    uint8_t* workingBuffer = calloc(inputLength,1);
    if (workingBuffer){
        
        uint8_t* outputPtr1 = workingBuffer;
        uint8_t* outputPtr2 = workingBuffer + (lineCount * lineBytes) - lineBytes;
        
        const uint8_t* inputPtr1 = field1Pixels;
        const uint8_t* inputPtr2 = field1Pixels + 2;
        
        long i = 0;
        for (long y = 0; y < lineCount/2; ++y){
            for (long x = 0; x < lineLength; x += 1, i += 2){
                ((uint16_t*)outputPtr1)[x] = ((uint16_t*)inputPtr1)[i];
                ((uint16_t*)outputPtr2)[x] = ((uint16_t*)inputPtr2)[i];
            }
            outputPtr1 += 2*lineBytes;
            outputPtr2 -= 2*lineBytes;
        }
        
        outputBuffer = sxDerotateM26CBuffer(lineLength, lineCount, workingBuffer);
        
        free(workingBuffer);
    }
    
    return outputBuffer;
}
