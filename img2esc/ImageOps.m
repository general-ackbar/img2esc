//
//  ImageOps.m
//  PeriPageA6
//
//  Created by Jonatan Yde on 02/04/2023.
//

#import "ImageOps.h"

@implementation ImageOps


#pragma mark Image manipulation

+(NSBitmapImageRep *) invertColorsOf:(NSBitmapImageRep *)sourceRep
{
    long n = sourceRep.bitsPerPixel / 8;           // Bytes per pixel
    long w = sourceRep.pixelsWide;
    long h = sourceRep.pixelsHigh;
    long rowBytes = sourceRep.bytesPerRow;
    int i;
    
    
    NSBitmapImageRep *destinationRep = [[NSBitmapImageRep alloc]
                                        initWithBitmapDataPlanes:NULL
                                        pixelsWide:w
                                        pixelsHigh:h
                                        bitsPerSample:8
                                        samplesPerPixel:n
                                        hasAlpha:[sourceRep hasAlpha]
                                        isPlanar:NO
                                        colorSpaceName: sourceRep.colorSpaceName
                                        bytesPerRow:rowBytes
                                        bitsPerPixel: 0] ;
    
    unsigned char *srcData = [sourceRep bitmapData];
    unsigned char *destData = [destinationRep bitmapData];
    
    for ( i = 0; i < rowBytes * h; i++ )
        *(destData + i) = 255 - *(srcData + i);
    
    return destinationRep;
}

#define THRESHOLD 127
+(NSBitmapImageRep *) ditheredRepresentationOf:(NSBitmapImageRep *)sourceRep
{
    if( sourceRep==nil ) return nil;
    
    long numberOfRows = [sourceRep pixelsHigh];
    long numberOfCols = [sourceRep pixelsWide];
    unsigned char *bitmapDataSource = [sourceRep bitmapData];
    NSInteger dX = (sourceRep.bitsPerPixel/8);
        
    // change bitmapDataSource : use Error-Diffusion
    for( NSInteger row=0; row < numberOfRows-1; row++ ){
        long rowLength = row * sourceRep.bytesPerRow;
        
        
        for( NSInteger col = 0; col < numberOfCols-1; col+=(sourceRep.bitsPerPixel/8) ){
            long currentPos = rowLength + col;
            
            NSInteger origValue = bitmapDataSource[currentPos] ;
//            if(origValue < THRESHOLD )
//                origValue = (origValue + 10) * 1.75;
            NSInteger newValue = (origValue > 127 ) ? 255 : 0;
            NSInteger error = -(newValue - origValue);
            
            
            
            bitmapDataSource[currentPos] = newValue;
            bitmapDataSource[currentPos+dX] = clamp(bitmapDataSource[currentPos+dX] + (7*error/16));
            
            long nextRowPos = rowLength + col + sourceRep.bytesPerRow;
            bitmapDataSource[nextRowPos -dX] = clamp( bitmapDataSource[nextRowPos -dX] + (3*error/16) );
            bitmapDataSource[nextRowPos] = clamp( bitmapDataSource[nextRowPos] + (5*error/16) );
            bitmapDataSource[nextRowPos +dX] = clamp( bitmapDataSource[nextRowPos +dX] + (error/16) );
        }
    }
    
    return sourceRep;
}


const int BAYER_PATTERN_16X16[16][16] = {    //    16x16 Bayer Dithering Matrix.  Color levels: 256
                                                {      0, 191,  48, 239,  12, 203,  60, 251,   3, 194,  51, 242,  15, 206,  63, 254    },
                                                {    127,  64, 175, 112, 139,  76, 187, 124, 130,  67, 178, 115, 142,  79, 190, 127    },
                                                {     32, 223,  16, 207,  44, 235,  28, 219,  35, 226,  19, 210,  47, 238,  31, 222    },
                                                {    159,  96, 143,  80, 171, 108, 155,  92, 162,  99, 146,  83, 174, 111, 158,  95    },
                                                {      8, 199,  56, 247,   4, 195,  52, 243,  11, 202,  59, 250,   7, 198,  55, 246    },
                                                {    135,  72, 183, 120, 131,  68, 179, 116, 138,  75, 186, 123, 134,  71, 182, 119    },
                                                {     40, 231,  24, 215,  36, 227,  20, 211,  43, 234,  27, 218,  39, 230,  23, 214    },
                                                {    167, 104, 151,  88, 163, 100, 147,  84, 170, 107, 154,  91, 166, 103, 150,  87    },
                                                {      2, 193,  50, 241,  14, 205,  62, 253,   1, 192,  49, 240,  13, 204,  61, 252    },
                                                {    129,  66, 177, 114, 141,  78, 189, 126, 128,  65, 176, 113, 140,  77, 188, 125    },
                                                {     34, 225,  18, 209,  46, 237,  30, 221,  33, 224,  17, 208,  45, 236,  29, 220    },
                                                {    161,  98, 145,  82, 173, 110, 157,  94, 160,  97, 144,  81, 172, 109, 156,  93    },
                                                {     10, 201,  58, 249,   6, 197,  54, 245,   9, 200,  57, 248,   5, 196,  53, 244    },
                                                {    137,  74, 185, 122, 133,  70, 181, 118, 136,  73, 184, 121, 132,  69, 180, 117    },
                                                {     42, 233,  26, 217,  38, 229,  22, 213,  41, 232,  25, 216,  37, 228,  21, 212    },
                                                {    169, 106, 153,  90, 165, 102, 149,  86, 168, 105, 152,  89, 164, 101, 148,  85    }
                                            };

+(NSBitmapImageRep *) ditheredBayerRepresentationOf:(NSBitmapImageRep *)sourceRep
{
    int    col    = 0;
    int    row    = 0;
    
    if( sourceRep==nil ) return nil;
    
    long height = [sourceRep pixelsHigh];
    long width = [sourceRep pixelsWide];
    uint8_t *pixels = [sourceRep bitmapData];
    

    for( int y = 0; y < height-1; y++ )
    {
        row    = y & 15;    //    y % 16
        long rowLength = y * sourceRep.bytesPerRow;
        
        for( int x = 0; x < width-1; x++ )
        {
            col    = x & 15;    //    x % 16
            long currentPos = rowLength + x;
            
            /*
            const int    blue    = pixels[x * sourceRep.bytesPerRow + 0];
            const int    green    = pixels[x  * sourceRep.bytesPerRow+ 1];
            const int    red        = pixels[x  *sourceRep.bytesPerRow + 2];
             */
            //int    color    = ((red + green + blue)/3 < BAYER_PATTERN_16X16[col][row] ? 0 : 255);
            int currentColor = pixels[currentPos] ;
            
            int    color    = (currentColor < BAYER_PATTERN_16X16[col][row] ? 0 : 255);
            
            pixels[currentPos] = color;
            /*
            pixels[x * sourceRep.bytesPerRow + 0]    = color/255.0;    //    blue
            pixels[x * sourceRep.bytesPerRow + 1]    = color/255.0;    //    green
            pixels[x *sourceRep.bytesPerRow + 2]    = color/255.0;    //    red
             */
        }

        //pixels    += width * sourceRep.bytesPerRow;
    }
    
    return sourceRep;
}



+(NSBitmapImageRep *) binaryRepresentationOf:(NSBitmapImageRep *)sourceRep
{
    if( sourceRep==nil ) return nil;
    
    long numberOfRows = [sourceRep pixelsHigh];
    long numberOfCols = [sourceRep pixelsWide];
    
    NSBitmapImageRep *destinationRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:numberOfCols
                                                                               pixelsHigh:numberOfRows
                                                                            bitsPerSample:1
                                                                          samplesPerPixel:1
                                                                                 hasAlpha:NO
                                                                                 isPlanar:NO
                                                                           colorSpaceName:NSCalibratedWhiteColorSpace
                                                                             bitmapFormat:0
                                                                              bytesPerRow:0
                                                                             bitsPerPixel:0 ];
    
    unsigned char *bitmapDataSource = [sourceRep bitmapData];
    unsigned char *bitmapDataDest = [destinationRep bitmapData];
    
    // iterate over all pixels and copy binary representation
    long grayBPR = sourceRep.bytesPerRow;
    long binBPR = destinationRep.bytesPerRow;
    long pWide = destinationRep.pixelsWide;
    
    for( NSInteger row=0; row<numberOfRows; row++ ){
        unsigned char *rowDataSource = bitmapDataSource + row*grayBPR;
        unsigned char *rowDataDest = bitmapDataDest + row*binBPR;
        
        NSInteger destCol = 0;
        unsigned char bw = 0;
        for( NSInteger col = 0; col < pWide; ){
            unsigned char gray = rowDataSource[col];
            if( gray > 127 ) {bw |= (1<<(7-col%8)); };
            col++;
            if( (col%8 == 0) || (col==pWide) ){
                rowDataDest[destCol] = bw;
                bw = 0;
                destCol++;
            }
        }
    }
    return destinationRep;
}

+(NSBitmapImageRep*) resize:(NSBitmapImageRep*) sourceRep to:(NSSize) newSize
{
    
    NSImage *tmp = [[NSImage alloc] init];
    [tmp addRepresentation:sourceRep];
    if (! tmp.isValid) return nil;
    
    
    
    NSBitmapImageRep *destinationRep = [[NSBitmapImageRep alloc]
                                        initWithBitmapDataPlanes:NULL
                                        pixelsWide:newSize.width
                                        pixelsHigh:newSize.height
                                        bitsPerSample: 8
                                        samplesPerPixel:4
                                        hasAlpha:YES
                                        isPlanar:NO
                                        colorSpaceName:NSCalibratedRGBColorSpace
                                        bytesPerRow: 0
                                        bitsPerPixel:0];
    destinationRep.size = newSize;
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:destinationRep]];

    //White background is required
    [[NSColor whiteColor] setFill];
    [NSBezierPath fillRect:NSMakeRect(0, 0, newSize.width, newSize.height)];

    [tmp drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
     
    [NSGraphicsContext restoreGraphicsState];
    
    tmp = nil;
    return destinationRep;
}

+(NSBitmapImageRep *) enlargeCanvasOf:(NSBitmapImageRep *)sourceRep to:(NSSize)cropSize align:(ImageAlignment)alignment
{
    NSImage *tmp = [[NSImage alloc] init];
    [tmp addRepresentation:sourceRep];
        
    if (! tmp.isValid) return nil;

    NSBitmapImageRep *destinationRep = [[NSBitmapImageRep alloc]
                  initWithBitmapDataPlanes:NULL
                                pixelsWide:cropSize.width
                                pixelsHigh:cropSize.height
                             bitsPerSample:8
                           samplesPerPixel:4
                                  hasAlpha:YES
                                  isPlanar:NO
                            colorSpaceName:NSCalibratedRGBColorSpace
                               bytesPerRow:0
                              bitsPerPixel:0];
    destinationRep.size = cropSize;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:destinationRep]];
    
    //White background is required
    [[NSColor whiteColor] setFill];
    [NSBezierPath fillRect:NSMakeRect(0, 0, cropSize.width, cropSize.height)];

    
    NSPoint destPoint;
    switch(alignment)
    {
        case AlignmnentLeft:
            destPoint = NSMakePoint(0, (cropSize.height-sourceRep.pixelsHigh)/2);
            break;
        case AlignmnentCenter:
            destPoint = NSMakePoint((cropSize.width-sourceRep.pixelsWide)/2, (cropSize.height-sourceRep.pixelsHigh)/2);
            break;
        case AlignmnentRight:
            destPoint = NSMakePoint((cropSize.width-sourceRep.pixelsWide), (cropSize.height-sourceRep.pixelsHigh)/2);
            break;
        default:
            destPoint = NSZeroPoint;
            break;

    }
    
    NSRect srcRect = NSMakeRect(0,0, sourceRep.pixelsWide, sourceRep.pixelsHigh);
    [tmp drawAtPoint:destPoint fromRect: srcRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];

    tmp = nil;

    return destinationRep;
}

+(NSBitmapImageRep *) crop:(NSBitmapImageRep *)sourceRep to:(NSRect)rect
{
    NSImage *tmp = [[NSImage alloc] init];
    [tmp addRepresentation:sourceRep];
        
    if (! tmp.isValid) return nil;

    NSBitmapImageRep *destinationRep = [[NSBitmapImageRep alloc]
                  initWithBitmapDataPlanes:NULL
                                pixelsWide:rect.size.width
                                pixelsHigh:rect.size.height
                             bitsPerSample:8
                           samplesPerPixel:4
                                  hasAlpha:YES
                                  isPlanar:NO
                            colorSpaceName:NSCalibratedRGBColorSpace
                               bytesPerRow:0
                              bitsPerPixel:0];
    destinationRep.size = rect.size;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:destinationRep]];
    
    //White background is required
    [[NSColor whiteColor] setFill];
    [NSBezierPath fillRect:NSMakeRect(0, 0, rect.size.width, rect.size.height)];

    NSPoint destPoint = NSZeroPoint;
    
    [tmp drawAtPoint:destPoint fromRect: rect operation:NSCompositingOperationSourceOver fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];

    tmp = nil;

    return destinationRep;
}
+(NSData *)rasterDataFrom:(NSBitmapImageRep *)bitmap
{
    NSMutableData *imageBytes = [[NSMutableData alloc] init];
    unsigned char currentByte = 0x00;
    int bit = 0;
    
    for(int y = 0; y < bitmap.pixelsHigh;y++)
    {
        
        for(int x = 0; x < bitmap.pixelsWide; x++)
        {
            NSColor *current = [bitmap colorAtX:x y:y];
            
            if(current.whiteComponent == 1.0)
            {
                currentByte |= 1 << (7 - bit);
            }
            else
            {
                //currentByte = currentByte << 0x1;
                //printf("1"); //All black
            }
            
            bit++;
            if(bit > 7)
            {
                [imageBytes appendBytes:&currentByte length:1];
                currentByte = 0x0;
                //printf(" ");
                bit = 0;
            }
            
            
        }
        bit = 0;
    }
    
    return imageBytes;

}

+(NSData*) columnDataFrom:(NSBitmapImageRep *)bitmap
{
    NSMutableData *imageBytes = [[NSMutableData alloc] init];
    
    for (int x = 0; x < bitmap.pixelsWide; x++) {
           
        // for each stripe, recollect 3 bytes (3 bytes = 24 bits)
        int noOfBytesNeeded = (int)bitmap.pixelsHigh/8;
        uint8_t slices[noOfBytesNeeded];
        
        for (int y = 0, i = 0; y < bitmap.pixelsHigh && i < noOfBytesNeeded ; y += 8, i++) {
            uint8_t slice = 0;
            for (int b = 0; b < 8; b++) {
                int yy = y + b;
                if (yy >= bitmap.pixelsHigh) {
                    continue;
                }
                bool v = ![[bitmap colorAtX:x y:yy] whiteComponent];
                slice |= (uint8_t) ((v ? 1 : 0) << (7 - b));
            }
            slices[i] = slice;
        }
            
        [imageBytes appendBytes:slices length:sizeof(slices)];
    }
    
        
    return [NSData dataWithData:imageBytes];
}
+(float)calculateBrightness:(NSBitmapImageRep *)bitmap
{
    float values = 0;
    
    for (NSInteger y = 0; y < bitmap.pixelsHigh; y++) {
        for (NSInteger x = 0; x < bitmap.pixelsWide; x++) {
            // Calculate the pixel's address
            values += [bitmap colorAtX:x y:y].whiteComponent;
        }
    }
    
    return values / (bitmap.pixelsHigh*bitmap.pixelsWide);
}

+(NSBitmapImageRep *)lightenGrayscale:(NSBitmapImageRep *)bitmap byFactor:(CGFloat)factor {
    // Ensure the imageRep is non-nil and has 8 bits per sample, which is typical for grayscale images
    if (!bitmap || [bitmap bitsPerSample] != 8) {
        return nil;
    }
    
    NSInteger width = [bitmap pixelsWide];
    NSInteger height = [bitmap pixelsHigh];
    NSInteger bytesPerRow = [bitmap bytesPerRow];
    unsigned char *bitmapData = [bitmap bitmapData];

    for (NSInteger y = 0; y < height; y++) {
        for (NSInteger x = 0; x < width; x++) {
            // Calculate the pixel's address
            unsigned char *pixel = bitmapData + y * bytesPerRow + x;

            // Lighten the pixel
            NSInteger value = *pixel;
            value += factor * 255;
            if (value > 255) value = 255;
            
            *pixel = (unsigned char)value;
        }
    }
    return bitmap;
}

+(NSBitmapImageRep *)halftoneFrom:(NSBitmapImageRep *)sourceRep
{
    long height = [sourceRep pixelsHigh];
    long width = [sourceRep pixelsWide];
    
    CGContextRef outputContext =  CGBitmapContextCreate(0, width, height, 8, width, [NSColorSpace genericGrayColorSpace].CGColorSpace, kCGImageAlphaNone);
    
    //White background
    CGContextSetFillColorWithColor(outputContext, [[NSColor whiteColor] CGColor]);
    CGContextFillRect(outputContext, CGRectMake(0,0, width, height));
    
    
    CGContextSetFillColorWithColor(outputContext, [[NSColor blackColor] CGColor]);
    CGSize block = CGSizeMake(6, 6);
    
    for (int y = 0; y < height; y+= block.height)
    {
        for (int x = 0; x < width; x+= block.width)
        {
            
            CGRect sourceBlock = CGRectMake(x,y, block.width, block.height);
            
            NSImage *tmpImage = [[NSImage alloc] initWithSize:sourceBlock.size];
            [tmpImage lockFocus];
            
            [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
            [sourceRep drawInRect:CGRectMake(0, 0, block.width, block.height) fromRect:sourceBlock operation:NSCompositingOperationCopy fraction:1.0 respectFlipped:NO hints:nil];
            [tmpImage setSize:NSMakeSize(1, 1)];
            [tmpImage unlockFocus];
            
            NSColor *currentColor = [[NSBitmapImageRep imageRepWithData:[tmpImage TIFFRepresentation]] colorAtX:0 y:0];
                                    
            float grayscaleValue = (currentColor.redComponent + currentColor.blueComponent + currentColor.greenComponent) / 3;
                        
            float darkFraction = 1.0 - grayscaleValue;
            float outerArea = block.width * block.height;
            float innerArea = outerArea * darkFraction; // (add ? darkFraction : grayscaleValue);
            

            //Create a smaller block and use it to fill a circle of white so the overall percept«ion matches that of the greyscale value
                //The formula used is A = PI * r^2 -> r = sqrt(A/PI) -> d = r*2
            float circleDiameter = CLAMP( sqrtf(innerArea / M_PI) *2, 0, block.width );
            float deltaOrigin = (block.width - circleDiameter)/2;
            CGRect circleBlock = CGRectMake(x + deltaOrigin, y + deltaOrigin, circleDiameter, circleDiameter);
            CGContextFillEllipseInRect(outputContext, circleBlock);
        }
    }
    
    CGImageRef imageRef = CGBitmapContextCreateImage(outputContext);
    NSImage* image = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(width, height)];
    CFRelease(imageRef);
    CFRelease(outputContext);

    
    return [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
}

@end
