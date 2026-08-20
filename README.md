# img2esc
 
**img2esc** - Prints a image on a generic Thermal printer from a Mac
 
## Synopsis
 
```
img2esc -i FILE (options)
```
 
## Description
 
`img2esc` convert and send bitmap images in the ESC format understood by a generic thermal printers. Capable of handling dithering, cutting, executing printer commands.
 
If no options are supplied, `img2esc` will select standard values.
 
## Options
 
| Option | Description |
| --- | --- |
| `-o (file)` | Output file or pipe (`-`). |
| `-w (width)` | Width should be divisible with 8. |
| `-m (mode)` | Output mode:<br>`0`: BitImage<br>`1`: Column<br>`2`: Define BitImage<br>`3`: Define NV BitImage<br>`8`: Column 8 bit<br>`16`: Column 24 bit |
| `-d (mode)` | Dither mode:<br>`0`: None (default)<br>`1`: FloydSteinberg<br>`2`: Bayer |
| `-e (command)` | Commands:<br>`lf -n <number>`<br>`cut`<br>`print`<br>`printnv -n <number>` |
| `-p (name)` | Printer (cups name). |
| `-x` | Invert image (default off). |
| `-c` | Cut after print (default off). |
 
## Examples
 
Converts the image `donkey.png` to black/white while applying FloydSteinberg dithering. Send it to the printer named "Epson-Thermal" and cut afterwards:
 
```
img2esc -i donkey.png -d 1 -p "Epson-Thermal" -c
```
 
Converts the image `donkey.png` to black/white. Send it to the printer named "Epson-Thermal" in a column 8-bit format (if the printer supports it):
 
```
img2esc -i donkey.png -m 8 -p "Epson-Thermal"
```