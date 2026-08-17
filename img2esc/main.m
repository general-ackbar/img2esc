//
//  main.m
//  img2esc
//
//  Created by Jonatan Yde on 12/02/2024.
//

#import <Foundation/Foundation.h>
#import "ImageOps.h"
#import <cups/cups.h>


#define MAX_WIDTH 576
#define ESC_CHAR 0x1B
#define GS 0x1D
static uint8_t LINE_FEED[] = {0x0A};
static uint8_t UNIDIRECTIONAL_MODE[] = {ESC_CHAR, 0x55, 1};                  //Doesn't seem to work
static uint8_t CUT_PAPER[] = {GS, 0x56, 0x00};
static uint8_t INIT_PRINTER[] = {ESC_CHAR, 0x40};                           //Doesn't seem to work
static uint8_t SELECT_BIT_IMAGE_MODE_24_DD[] = {0x1B, 0x2A, 33};
static uint8_t SELECT_BIT_IMAGE_MODE_8_DD[] = {0x1B, 0x2A, 1};
static uint8_t SET_LINE_SPACE_24[] = {ESC_CHAR, 0x33, 24};
static uint8_t SET_LINE_SPACE_8[] = {ESC_CHAR, 0x33, 8};


typedef NS_ENUM(NSInteger, DataMode)
{
    RasterBitImage = 0,
    ColumnBitImage = 1,
    DownloadBitImage = 2,
    DownloadNVBitImage = 3,
    Rows8bit = 8,
    Rows24bit = 24
};

NSData* rasterBitImageFrom(NSBitmapImageRep *bitmap, bool cut);
NSData *columnBitImageFrom(NSBitmapImageRep *bitmap, bool cut);
NSData* defineBitImageFrom(NSBitmapImageRep *bitmap);
NSData* defineNVBitImageFrom(NSBitmapImageRep *bitmap, int index);
NSData* bitImageRows8From(NSBitmapImageRep *bitmap, bool cut);
NSData* bitImageRows24From(NSBitmapImageRep *bitmap, bool cut);


void printHelp(void);
void sendCommand(void);
void sendToPrinter(const char *printerName, NSData* data);



int main(int argc, char * argv[]) {
    @autoreleasepool {
        // insert code here...
        
        
        NSString *inputFile;
        NSString *outputFile;
        int rowWidth = 0;
        PrintScale scale = ScaleModeShrinkOnly;
        ImageAlignment alignment = AlignmnentCenter;
        DitherMode dither = None;
        NSString *printer = nil;
        bool invert = NO;
        bool cut = false;
        DataMode dataMode = RasterBitImage;
        int cmdValueNumeric = 1;
        NSString *cmdStringValue;
        bool dryrun = false;
        int factor = 0;
        
        
        
        /*
         i = input file
         o = output file (esc format)
         w = width
         m = mode
         p = printer name (raw printer required)
         d = dither
         l = lightening factor
         z = test (dry run, do do anything)
         c = cut after print
         f = scale mode
         e = execute esc command
         */
        char c;
        while ((c = getopt (argc, argv, "i:o:w:m:p:d:n:e:l:xchfz")) != -1)
            switch (c)
        {
            case 'i':
                inputFile = [NSString stringWithFormat:@"%s", optarg];
                outputFile = [[inputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"esc"];
                break;
            case 'o':
                outputFile = [NSString stringWithFormat:@"%s", optarg];
                if( outputFile.pathExtension.length !=0 )
                    outputFile = [[outputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"esc"];
                else if(outputFile.pathExtension.length == 0 && ![outputFile isEqualToString:@"-"] )
                    outputFile = [outputFile stringByAppendingPathExtension:@"esc"];
                break;
            case 'w':
                rowWidth = atoi(optarg);
                break;
            case 'h':
                printHelp();
                return 0;
            case 'c':
                cut = YES;
                break;
            case 'f':
                scale = ScaleModeResize;
                break;
            case 'e':
                cmdStringValue = [NSString stringWithFormat:@"%s", optarg];
                break;
            case 'x':
                invert = YES;
                break;
            case 'd':
                if( [[[NSString stringWithFormat:@"%s", optarg] lowercaseString] isEqualToString:@"none"] )
                    dither = None;
                else if( [[[NSString stringWithFormat:@"%s", optarg] lowercaseString] isEqualToString:@"floyd"] )
                    dither = FloydSteinberg;
                else if( [[[NSString stringWithFormat:@"%s", optarg] lowercaseString] isEqualToString:@"bayer"] )
                    dither = Bayer;
                break;
            case 'p':
                printer = [NSString stringWithFormat:@"%s", optarg];
                break;
            case 'm':
                dataMode = atoi(optarg);
                break;
            case 'n':
                cmdValueNumeric = atoi(optarg);
                break;
            case 'l':
                factor = atoi(optarg);
                break;
            case 'z':
                dryrun = YES;
                break;
            case '?':
                if (optopt == 'i' || optopt == 'o' || optopt == 'w')
                    fprintf (stderr, "Option -%c requires an argument.\n", optopt);
                else if (isprint (optopt))
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf (stderr,
                             "Unknown option character `\\x%x'.\n",
                             optopt);
                return 1;
            default:
                abort ();
        }
        
        if(![outputFile isEqualToString:@"-"]) printf("img2esc version 0.1\n");
        
        //Parse -e switch if present
        if(cmdStringValue)
        {
            if(!printer)
            {
                printf("Error. Printer not specified (-p <printer name>\n");
                return 1;
            }
            if([[cmdStringValue lowercaseString]  isEqualToString:@"printnv"]) {
                uint8_t cmdData[4] = {0x1C, 0x70, (uint8_t)cmdValueNumeric, 0x48};
                sendToPrinter([printer cStringUsingEncoding:NSASCIIStringEncoding], [NSData dataWithBytes: cmdData length:sizeof(cmdData)]);
                printf("Requesting %s to print NV Bit Image no. %i\n", [printer cStringUsingEncoding:NSASCIIStringEncoding], cmdValueNumeric);
            }
            else if([[cmdStringValue lowercaseString]  isEqualToString:@"print"]) {
                uint8_t cmdData[3] = {GS, 0x2F, 0x48};
                sendToPrinter([printer cStringUsingEncoding:NSASCIIStringEncoding], [NSData dataWithBytes: cmdData length:sizeof(cmdData)]);
                printf("Requesting %s to print Bit Image\n", [printer cStringUsingEncoding:NSASCIIStringEncoding]);
            }

            else if([[cmdStringValue lowercaseString]  isEqualToString:@"cut"]) {
                sendToPrinter([printer cStringUsingEncoding:NSASCIIStringEncoding], [NSData dataWithBytes:CUT_PAPER length:sizeof(CUT_PAPER)]);
                printf("Requesting paper cut on printer %s\n", [printer cStringUsingEncoding:NSASCIIStringEncoding]);
            }
            else if([[cmdStringValue lowercaseString] isEqualToString:@"lf"]) {
                uint8_t cmdData[3] = {0x1B, 0x64, (uint8_t)cmdValueNumeric};
                sendToPrinter([printer cStringUsingEncoding:NSASCIIStringEncoding], [NSData dataWithBytes:cmdData length:sizeof(cmdData)] );
                printf("Requesting line feed on printer %s\n", [printer cStringUsingEncoding:NSASCIIStringEncoding]);
            }
            else if([[cmdStringValue lowercaseString] isEqualToString: @"linespace"]) {
                uint8_t cmdData[3] = {ESC_CHAR, 0x33, (uint8_t)cmdValueNumeric};
                sendToPrinter([printer cStringUsingEncoding:NSASCIIStringEncoding], [NSData dataWithBytes: cmdData length:sizeof(cmdData)] );
                printf("Setting line space to %i on printer %s\n", cmdValueNumeric, [printer cStringUsingEncoding:NSASCIIStringEncoding]);
            }
            else
            {
                printf("Command '%s' not recognized. Available commands are 'print, printnv, cut, lf, linespace'\n", [cmdStringValue cStringUsingEncoding:NSASCIIStringEncoding]);
            }
            return 0;
        }
        
        if(!inputFile)
        {
            printf("Usage: img2esc -i <file> [options] (-h for help)\n");
            return 1;
        }
               
    
        NSImage *img = [[NSImage alloc] initWithData:[NSData dataWithContentsOfFile:inputFile]];
        CGImageRef CGImage = [img CGImageForProposedRect:nil context:nil hints:nil];
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:CGImage];
        
        if(rowWidth == 0 || rowWidth > MAX_WIDTH)
            rowWidth = MAX_WIDTH;

        
        int h = ceilf(((float)rowWidth / (float)bitmap.pixelsWide) * bitmap.pixelsHigh);
        if(dataMode == Rows8bit)
        {
            h = h / 3;
            scale = ScaleModeResize;
        }
                
        //1: resize (rowWidth x (rowWidth / image_width * image_height))
        if(scale == ScaleModeResize || (scale == ScaleModeShrinkOnly && bitmap.pixelsWide > rowWidth))
            bitmap = [ImageOps resize:bitmap to:NSMakeSize(rowWidth,  h )];
        else
            bitmap = [ImageOps enlargeCanvasOf:bitmap to:NSMakeSize(rowWidth, bitmap.pixelsHigh) align:alignment];
        
        //2: Convert to luma (L = R * 299/1000 + G * 587/1000 + B * 114/1000)
        bitmap = [bitmap bitmapImageRepByConvertingToColorSpace: [NSColorSpace genericGrayColorSpace] renderingIntent:NSColorRenderingIntentDefault];
        
        //3: Invert image
        if(invert)
            bitmap = [ImageOps invertColorsOf:bitmap];
        
        if(![outputFile isEqualToString:@"-"]) printf("The brightness of the image is: %.02f \n", [ImageOps calculateBrightness:bitmap]);
        
        if(factor > 0)
        {
            bitmap = [ImageOps lightenGrayscale:bitmap byFactor: factor/100.0];
            if(![outputFile isEqualToString:@"-"])
            {
                printf("Adjusting brightness with a factor %0.2f \n", factor/100.0);
                printf("The brightness level is now: %.02f \n", [ImageOps calculateBrightness:bitmap]);
            }
        }
        //4: Dither image if requested
        switch(dither)
        {
            case FloydSteinberg:
                bitmap = [ImageOps ditheredRepresentationOf:bitmap];
                break;
            case Bayer:
                bitmap = [ImageOps ditheredBayerRepresentationOf:bitmap];
                break;
            case Halftone:
                bitmap = [ImageOps halftoneFrom:bitmap ];
                break;
            case None:
                break;
        }
        
        //5: Convert (1-bit pixels, black and white, stored with one pixel per byte)
        bitmap = [ImageOps binaryRepresentationOf:bitmap];
        
        
        //6: combine bit data with esc commands
        NSData* data;
        if(dataMode == RasterBitImage)
            data = rasterBitImageFrom(bitmap, cut);
        else if(dataMode == ColumnBitImage)
            data = columnBitImageFrom(bitmap, cut);
        else if(dataMode == DownloadBitImage)
            data = defineBitImageFrom(bitmap);
        else if(dataMode == DownloadNVBitImage)
            data = defineNVBitImageFrom(bitmap, cmdValueNumeric);
        else if(dataMode == Rows8bit)
            data = bitImageRows8From(bitmap, cut);
        else if(dataMode == Rows24bit)
            data = bitImageRows24From(bitmap, cut);
        
        
        
        if(dryrun)
        {
            printf("Dry run on %s complete\n", [inputFile cStringUsingEncoding:NSASCIIStringEncoding]);
            return 0;
        }
        if(printer)
        {
            printf("Sending data to \"%s\"\n", [printer cStringUsingEncoding:NSASCIIStringEncoding]);
            sendToPrinter([printer cStringUsingEncoding:NSASCIIStringEncoding], data);
//            printf("Done\n");
            return 0;
        }
        
        if([outputFile isEqualToString:@"-"]){
            fwrite(data.bytes, data.length, 1, stdout );
            return 0;
        }
        
        NSError *err;
        [data writeToFile:outputFile options: NSDataWritingAtomic error:&err];
        if(!err)
            printf("Output saved as '%s'\n", [outputFile cStringUsingEncoding:NSASCIIStringEncoding]);
        else
            printf("Error wrting file: %s\n", [err.description cStringUsingEncoding:NSASCIIStringEncoding]);
    }
    return 0;
}

//ESC * (24 bit per column, double density)
NSData* bitImageRows24From(NSBitmapImageRep *bitmap, bool cut)
{
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendBytes:SET_LINE_SPACE_24 length:sizeof(SET_LINE_SPACE_24)];
    
    for(int y = 0; y < bitmap.pixelsHigh; y+=24)
    {
        [data appendBytes:SELECT_BIT_IMAGE_MODE_24_DD length:sizeof(SELECT_BIT_IMAGE_MODE_24_DD)];
        uint8_t lineHeader[] = {(uint8_t)(0x00ff & bitmap.pixelsWide), (uint8_t)((0xff00 & bitmap.pixelsWide ) >> 8)};
        [data appendBytes:lineHeader length:sizeof(lineHeader)];
        
        for (int x = 0; x < bitmap.pixelsWide; x++) {
           
            // for each stripe, recollect 3 bytes (3 bytes = 24 bits)
            uint8_t slices[] = {0, 0, 0};
            for (int yy = y, i = 0; yy < y + 24 && i < 3; yy += 8, i++) {
                uint8_t slice = 0;
                for (int b = 0; b < 8; b++) {
                    int yyy = yy + b;
                    if (yyy >= bitmap.pixelsHigh) {
                        continue;
                    }
                    bool v = ![[bitmap colorAtX:x y:yyy] whiteComponent];
                    slice |= (uint8_t) ((v ? 1 : 0) << (7 - b));
                }
                slices[i] = slice;
            }
             
            [data appendBytes:slices length:sizeof(slices)];
        }
        [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    }

    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    
    if(cut)
        [data appendBytes: CUT_PAPER length:sizeof(CUT_PAPER)];
        
    return [NSData dataWithData:data];
}

//ESC * (8 bit per column, double density)
NSData* bitImageRows8From(NSBitmapImageRep *bitmap, bool cut)
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
    [data appendBytes:SET_LINE_SPACE_8 length:sizeof(SET_LINE_SPACE_8)];
    for(int y = 0; y < bitmap.pixelsHigh; y+=8)
    {
        [data appendBytes: SELECT_BIT_IMAGE_MODE_8_DD length:sizeof(SELECT_BIT_IMAGE_MODE_8_DD)];
        uint8_t lineHeader[] = {(uint8_t)(0x00ff & bitmap.pixelsWide), (uint8_t)((0xff00 & bitmap.pixelsWide ) >> 8)};
        [data appendBytes:lineHeader length:sizeof(lineHeader)];
        
        for (int x = 0; x < bitmap.pixelsWide; x++) {
            uint8_t column = 0;
            for (int b = 0; b < 8; b++) {
                int yy = y + b;
                    
                if (yy >= bitmap.pixelsHigh) {
                    continue;
                }
                bool v = ![[bitmap colorAtX:x y:yy] whiteComponent];
                column |= (uint8_t) ((v ? 1 : 0) << (7 - b));
            }
            [data appendBytes:&column length:1];
        }
        [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    }
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    
    if(cut)
        [data appendBytes: CUT_PAPER length:sizeof(CUT_PAPER)];
    
    
    return [NSData dataWithData:data];
}

//Can't get this one to work
NSData* defineBitImageFrom(NSBitmapImageRep *bitmap)
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
    uint8_t x = ((bitmap.pixelsWide >> 3) & 0xff);
    uint8_t y = ((bitmap.pixelsHigh >> 3) & 0xff);
                        
    uint8_t header[4] = {GS, 0x2A, x, y };
    
    [data appendBytes:header  length:sizeof(header)];
    [data appendData:[ImageOps columnDataFrom:bitmap]];
    
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];

    return data;
}

NSData* defineNVBitImageFrom(NSBitmapImageRep *bitmap, int index)
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
    uint8_t xL = ((bitmap.pixelsWide >> 3) & 0xff);
    uint8_t xH = (((bitmap.pixelsWide >> 3) >>8) & 0xff);
    uint8_t yL = ((bitmap.pixelsHigh >> 3) & 0xff);
    uint8_t yH = (((bitmap.pixelsHigh >> 3) >> 8) & 0xff);

                        
    uint8_t header[7] = {0x1C, 0x71, (uint8_t)index, xL, xH, yL, yH};
    //uint8_t header[7] = {GS, 0x51, 0x20, 0x48, xL, xH, yL, yH};
    
    
    [data appendBytes:header  length:sizeof(header)];
    [data appendData:[ImageOps columnDataFrom:bitmap]];
    
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    
    return data;
}


/*
NSData* downloadRasterToPrinterFrom(NSBitmapImageRep *bitmap)
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
    //pL and pH specify the number of bytes following m as (pL + pH × 256).
    // Set graphics data: [Function 67] Define the NV graphics data (raster format)
    // 128(=8*16) dots wide and 120 dots tall with respect to key code "G1"
    //    GS ( L   pL  pH   m  fn   a kc1/Kc2  b  xL  xH  yL  yH   c
    long dataLength = data.length + 11;
    uint8_t xL = (bitmap.pixelsWide & 0xff);
    uint8_t xH = ((bitmap.pixelsWide >>8) & 0xff);
    uint8_t yL = (bitmap.pixelsHigh & 0xff);
    uint8_t yH = ((bitmap.pixelsHigh >> 8) & 0xff);
    uint8_t pL = (dataLength & 0xff);;
    uint8_t pH = ((dataLength >>8) & 0xff);;
                        
    uint8_t header[16] = {GS, 0x28, 0x4C, pL, pH, 0x30, 0x43, 0x30, 0x47, 0x31, 0x01, xL, xH, yL, yH, 0x31};
    
    [data appendBytes:header  length:sizeof(header)];
    [data appendData:[ImageOps bytesFrom:bitmap]];
    
    
    // Prints data that corresponds to key code "G1" at 1x1 size.
    // GS ( L   pL  pH   m  fn kc1/Kc2 x y
    //    GS "(L"   6   0  48  69  "G1"   1 1
    uint8_t footer[11] = {GS, 0x28, 0x4C, 0x06, 0x00, 0x30, 0x45, 0x47, 0x31, 0x01, 0x01};
    [data appendBytes:footer  length:sizeof(footer)];
    return data;
    
}
*/

//GS Q 0
NSData *columnBitImageFrom(NSBitmapImageRep *bitmap, bool cut)
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
    
    uint8_t header[8] = {
        GS,
        0x51,
        0x30,
        0x48,
        (bitmap.pixelsWide & 0xff),
        ((bitmap.pixelsWide >> 8) & 0xff),
        ((bitmap.pixelsHigh >> 3) & 0xff),
        (((bitmap.pixelsHigh >> 3)>>8) & 0xff)
    };
    
    [data appendBytes:&header length:sizeof(header)];
    [data appendData: [ImageOps columnDataFrom:bitmap] ];
    
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    
    if(cut)
        [data appendBytes: CUT_PAPER length:sizeof(CUT_PAPER)];
    
    return [NSData dataWithData:data];
}

//GS v 0
NSData *rasterBitImageFrom(NSBitmapImageRep *bitmap, bool cut)
{
    //Colors needs to be inverted
    NSMutableData *data = [[NSMutableData alloc] init];
    
    
    uint8_t header[8] = {
        GS,
        0x76,
        0x30,
        0x48,
        ((bitmap.pixelsWide >> 3) & 0xff),
        (((bitmap.pixelsWide >> 3)>>8) & 0xff),
        (bitmap.pixelsHigh & 0xff),
        ((bitmap.pixelsHigh >> 8) & 0xff)
    };
    
    [data appendBytes:&header length:sizeof(header)];
    [data appendData: [ImageOps rasterDataFrom:bitmap] ];
    
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    [data appendBytes: LINE_FEED length:sizeof(LINE_FEED)];
    
    if(cut)
        [data appendBytes: CUT_PAPER length:sizeof(CUT_PAPER)];
    
    return [NSData dataWithData:data];
}


void sendToPrinter(const char *printerName, NSData* data) {
    // Get the default printer if printerName is NULL
    if (printerName == NULL) {
        printerName = cupsGetDefault();
    }

    // Create a print job
    int jobId = cupsCreateJob(CUPS_HTTP_DEFAULT, printerName, "Job Title", 0, NULL);
    if (jobId == 0) {
        printf("Failed to create job\n");
        return;
    }

    // Start the document
    if (cupsStartDocument(CUPS_HTTP_DEFAULT, printerName, jobId, "Bit image", CUPS_FORMAT_RAW, 1) == 0) {
        printf("Failed to start document\n");
        return;
    }

    // Write the data at once
    cupsWriteRequestData(CUPS_HTTP_DEFAULT, [data bytes], [data length]);
    
    // Finish the document
    cupsFinishDocument(CUPS_HTTP_DEFAULT, printerName);
}

void printHelp(void)
{
    printf("usage : img2esc -i [input image] [options]\n"
            "option: -o (file)         output file or pipe ( \"-\" )\n"
            "        -w (width)        width should be divisable with 8\n"
            "        -m (mode)         output mode: \n"
            "                               0:  BitImage\n"
            "                               1:  Column\n"
            "                               2:  Define BitImage\n"
            "                               3:  Define NV BitImage\n"
            "                               8:  Colum 8 bit\n"
            "                               16: Colum 24 bit\n"
            "        -d (mode)         dither mode:\n"
            "                               0: None (default)\n"
            "                               1: FloydSteinberg\n"
            "                               2: Bayer\n"
            "        -e (command)      commands:\n"
            "                               'lf' -n <number> \n"
            "                               'cut'\n"
            "                               'print' \n"
            "                               'printnv' -n <number> \n"
            "        -p (name)          Printer (cups name)\n"
            "        -x                 Invert image (default off)\n"
            "        -c                 Cut after print (default off)\n"
    );
     
}
