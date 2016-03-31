//
//  main.cpp
//  pcl-test
//
//  Created by Simon Taylor on 29/11/2015.
//  Copyright © 2015 Simon Taylor. All rights reserved.
//

#include <iostream>
#include <pcl/Image.h>
#include "StarDetector.h"

int main(int argc, const char * argv[]) {
    
    pcl::Image image(256,256);
    pcl::DPoint point(256/2,256/2);
    
    float** channels = (float**)malloc(sizeof(float*));
    *channels = (float*)malloc(256*256*sizeof(float));
    
    image.ImportData(channels, image.Width(), image.Height());
    
    std::cout << "Width " << image.Width() << std::endl;
    std::cout << "Height " << image.Height() << std::endl;
    std::cout << "NumberOfPixels " << image.NumberOfPixels() << std::endl;

    pcl::StarDetector sd(image,0,point);
    if (sd){
        std::cout << "got a star" << std::endl;
    }
    else {
        std::cout << "no star" << std::endl;
    }
    
    return 0;
}
