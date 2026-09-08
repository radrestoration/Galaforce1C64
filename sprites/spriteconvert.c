#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>

//static const char *inputName  = "GALASCR_5800_5800.bin";
static const char *outputName = "sprite.ppm";

int main(int argc, const char *argv[])
{
  const int dimx = 160, dimy = 256;

  if (argc < 2) {
    fprintf(stderr, "Input name not specified\n");
    exit(EXIT_FAILURE);
  }

  const char *inputName = argv[1];

  FILE *in = fopen(inputName, "rb");

  if (!in) {
    fprintf(stderr, "Failed to open input file '%s' (%s)\n", inputName, strerror(errno));
    exit(EXIT_FAILURE);
  }

  FILE *out = fopen(outputName, "wb"); /* b - binary mode */

  if (!out) {
    fprintf(stderr, "Failed to open input file '%s' (%s)\n", outputName, strerror(errno));
    exit(EXIT_FAILURE);
  }

  (void) fprintf(out, "P6\n%d %d\n255\n", dimx, dimy);

  // 2 bpp
  // 0 = black
  // 1 = red
  // 2 = yellow
  // 3 = white

  const char cols[4][3] = {
    { 0, 0, 0},
    { 255, 0, 0},
    { 255, 255, 0 },
    { 255, 255, 255 }
  };

  bool done = false;

  for (int y = 0; y < dimy; y++)
  {
    // Arrangement is on character basis
    char data[dimx * 8 * 3];

    memset(data, 0, sizeof(data));


    for (int x = 0; x < dimx / 4; x++)
    {
      char byte;

      if (!done && fread(&byte, 1, 1, in) != 1) {
        fprintf(stderr, "Out of data at %d,%d\n", x, y);
        done = true;
      }

      /*if (done) {
        fwrite(cols[0], 1, 3, out);
        continue;
      }*/

      for (int pixel = 0; pixel < 4; pixel++)
      {
        int col;

        if (done)
          col = 0;
        else
          col = (byte & 0x01) | ((byte & 0x10) >> 3);

        //int col = done ? 0 : (byte & 0x03);

        int ch   = x / (64 / 2); // 32 pixels per 8x8 character
        //int cx   = x % 4;
        int row = y % 8;

        int offset = (row * dimx + ch + pixel) * 3;

        data[offset + 0] = cols[col][0];
        data[offset + 1] = cols[col][1];
        data[offset + 2] = cols[col][2];

        //fwrite(cols[col], 1, 3, out);

        byte >>= 1;
      }

//      static unsigned char color[3];
//      color[0] = i % 256;  /* red */
//      color[1] = j % 256;  /* green */
//      color[2] = (i * j) % 256;  /* blue */
  //    (void) fwrite(color, 1, 3, out);

    //  }
    }

    if ((y % 8) == 0) {
      fwrite(data, 1, sizeof(data), out);
      memset(data, 0, sizeof(data));
    }

  }
  (void) fclose(in);
  (void) fclose(out);
  return EXIT_SUCCESS;
}
