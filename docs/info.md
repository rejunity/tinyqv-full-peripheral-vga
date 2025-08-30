<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# VGA adapter for TinyQV

Author: ReJ aka Renaldas Zioma

Peripheral index: nn

## What it does

TODO: Explain what your peripheral does and how it works

## Register map

| Address | Name    | Access | Description                                                      |
|---------|---------|--------|------------------------------------------------------------------|
| 0x00    | PIXDAT0 | W      | Pixel data (1-bit per pixel)   0..31                             |
| 0x04    | PIXDAT1 | W      | Pixel data (1-bit per pixel)  32..63                             |
| 0x08    | PIXDAT2 | W      | Pixel data (1-bit per pixel)  64..xx                             |
| 0x0C    | PIXDAT3 | W      | Pixel data (1-bit per pixel)  xx..xx                             |
| 0x10    | PIXDAT4 | W      | Pixel data (1-bit per pixel)  xx..xx                             |
| 0x14    | PIXDAT5 | W      | Pixel data (1-bit per pixel)  xx..xx                             |
| 0x18    | PIXDAT6 | W      | Pixel data (1-bit per pixel)  xx..xx                       		|
| 0x1C    | PIXDAT7 | W      | Pixel data (1-bit per pixel) 224..255                            |
| 0x20    | ????  	| ?      | ???									                       		|
| 0x24    | ????  	| ?      | ???									                            |
| 0x30	  | BGCOLOR | W	     | Background color: xxBBGGRR (default 010000, dark blue)			|
| 0x31	  | FGCOLOR	| W		 | Foreground color: xxBBGGRR (default 001011, golden yellow)		|

| Address | Name    | Access | Description                                                      |
|---------|-------------|--------|--------------------------------------------------------------|
| 0x00    | WAIT_HBLANK | R      | Block CPU until Horizontal BLANK                             |
| 0x04    | WAIT_PIXEL0 | R      | Block CPU until the 1st pixel of the buffer is being displayed. |
| 0x3F	  | VGA         | R	     | VGA status: interrupt (bit 0), vsync (bit 1), hsync (bit 2). Clears interrupt on read. |

## How to test

TODO: Explain how to use your project

## External hardware

Tiny VGA Pmod
