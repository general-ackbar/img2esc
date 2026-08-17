//
//  ImageOps.h
//  PeriPageA6
//
//  Created by Jonatan Yde on 02/04/2023.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#define clamp(z) ( (z > 255) ? 255 : ( (z < 0) ? 0 : z) )

#define CLAMP(x, low, high) ({\
__typeof__(x) __x = (x); \
__typeof__(low) __low = (low);\
__typeof__(high) __high = (high);\
__x > __high ? __high : (__x < __low ? __low : __x);\
})


NS_ASSUME_NONNULL_BEGIN

@interface ImageOps : NSObject

typedef NS_ENUM(NSInteger, ImageAlignment)
{
    AlignmnentLeft,
    AlignmnentCenter,
    AlignmnentRight
};

typedef NS_ENUM(NSInteger, PrintScale)
{
    ScaleModeResize,
    ScaleModeShrinkOnly,
};


typedef NS_ENUM(NSInteger, DitherMode)
{
    FloydSteinberg,
    Bayer,
    Halftone,
    None
};

+(NSBitmapImageRep *) invertColorsOf:(NSBitmapImageRep *)sourceRep;
+(NSBitmapImageRep *) ditheredRepresentationOf:(NSBitmapImageRep *)sourceRep;
+(NSBitmapImageRep *) ditheredBayerRepresentationOf:(NSBitmapImageRep *)sourceRep;
+(NSBitmapImageRep *) binaryRepresentationOf:(NSBitmapImageRep *)sourceRep;
+(NSBitmapImageRep*) resize:(NSBitmapImageRep*) sourceRep to:(NSSize) newSize;
+(NSBitmapImageRep *) enlargeCanvasOf:(NSBitmapImageRep *)sourceRep to:(NSSize)canvasSize align:(ImageAlignment)alignment;
+(NSData *)rasterDataFrom:(NSBitmapImageRep *)bitmap;
+(NSBitmapImageRep *) crop:(NSBitmapImageRep *)sourceRep to:(NSRect)rect;
//+(NSBitmapImageRep *) crop:(NSBitmapImageRep *)sourceRep to:(NSSize)canvasSize align:(ImageAlignment)alignment;
+(NSData*) columnDataFrom:(NSBitmapImageRep *)bitmap;
+(NSBitmapImageRep *)lightenGrayscale:(NSBitmapImageRep *)imageRep byFactor:(CGFloat)factor;
+(NSBitmapImageRep *)halftoneFrom:(NSBitmapImageRep *)sourceRep;
+(float)calculateBrightness:(NSBitmapImageRep *)bitmap;
@end

NS_ASSUME_NONNULL_END
