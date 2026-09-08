
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>


int main(int argc, const char **argv) {
	
	if (argc < 1) {
		fprintf(stderr, "No filename specified\n");
		exit(EXIT_FAILURE);
	}

    size_t size = 205;
	
	FILE *ffont = fopen(argv[1], "rb");
	uint8_t font[size];
	
	if (fread(font, 1, sizeof(font), ffont) < sizeof(font)) exit(EXIT_FAILURE);
	fclose(ffont);
	
	
	uint8_t message[10] = { 0, 10, 11, 12, 13, 15 };
	uint8_t len = 6;
	
	
   // pixel = 0
   // bit = temp[0]
   // if (bit & (1 << y)) pixel = color
   // bit = temp[1]
   // if (bit & (1 << y)) pixel = color | (color << 4)
      
	uint8_t bitmask = 0x1;
	
	for (int row = 0; row < 7; row++) {
	    size_t count = 0;
	       
	    while (count < len) {	  
			uint8_t letter = message[count];

		   	for (int col = 0; col < 5; col++) {
			    putc(font[letter * 5 + col] & bitmask ? '*' : ' ', stdout);
		    }
		    count++;
		    putc(' ', stdout);
		}   
		       
		bitmask <<= 1;
	    puts("");
	}
}