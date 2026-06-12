//
// jag.c 
//

#include "font.h"
#include "gpures.h"

extern int vidmem[];
extern int image[];

unsigned char *jagscreen;

unsigned char shift[] = { 7, 6, 5, 4, 3, 2, 1, 0 };
int TextSize, TextColor;

void DrawCharLine (int charloc, int screenloc);
void DrawChar (int x, int y, char ch);
void DrawString (int x, int y, const char *str);
void SetPallete(void);

//
// HACK: Put string constants into .data instead of .rodata
//  because that causes issues trying to make an a.out
//
__section(.data)
const char a_string[] = "Atari Jaguar";
__section(.data)
const char g_string[] = "GPU in Main!";

#define SETBG(c) *(short *)(0xF00058) = c;

extern short bgcol;

void _main(void) {

  SetPallete();

  GPU_blit_and_wait((int)&image, (int)&vidmem, 320*200/4);

  jagscreen = (unsigned char *)&vidmem;

  TextColor = 1;
  TextSize = 1;

  DrawString(10,10,a_string /*"Atari Jaguar"*/);

  TextColor = 1;
  TextSize  = 3;

  DrawString(10,100,g_string /*"GPU in Main!"*/);

  while(1) {
    GPU_wait_vblank();
    SETBG(bgcol); bgcol++;
  }
}

void DrawCharLine (int charloc, int screenloc)
{
  int xcnt;
  int xsize;

  for (xcnt = 0; xcnt < F_WIDTH; xcnt++) {
    if (((textfont[charloc] >> shift[xcnt]) & 0x1)) {
      for (xsize = 0; xsize < TextSize; xsize++)
            jagscreen[screenloc++] = TextColor;
    }
    else {
      for (xsize = 0; xsize < TextSize; xsize++) {
            /*if (!Transparency)
              jagscreen[screenloc++] = 0;
            else
              jagscreen[screenloc++] = 1;*/
              screenloc++;
      }
    }
  }
}

void DrawChar (int x, int y, char ch)
{
  int ycnt, charloc, screenloc;
  int ysize;
  int count;

  /*charloc = ch * F_CHARSIZE;*/
  charloc = 0;
  count = F_CHARSIZE;
  while (count--) charloc += ch;

  /*screenloc = (y * T_XREZ) + x ;*/
  screenloc = 0;
  count = T_XREZ;
  while (count--) screenloc += y;
  screenloc += x;

  for (ycnt = 0; ycnt < F_HEIGHT; ycnt++) {
    for (ysize = 1; ysize <= TextSize; ysize++) {
      DrawCharLine (charloc, screenloc);
      screenloc += T_XREZ;
    }
    charloc++;
  }
}

void DrawString (int x, int y, const char *str)
{
  int cnt;

  for (cnt = 0; str[cnt] != 0; cnt++) {
    DrawChar (x, y, str[cnt]);
    x += (F_WIDTH * TextSize);
  }
}

void SetPallete(void) {
  
  //
  // Set the palette, which is saved after the image data in an
  //  image converted with `tga2cry -f cry8`
  //

  unsigned short *add = (unsigned short *)0xf00400;
  unsigned short *pal = (unsigned short *)&image[64000/4];

  // The first word after the image data is the number of colors
  //  in the palette
  short count = *pal++;

  while (count--) {
    // REALLY set that palette value, because if the RELEASE bit is
    //  set on any BITMAP object in the current OP list, writing into
    //  the CLUT can fail
    do { *add = *pal; } while (*add != *pal);
    add++;
    pal++;
  }
}

