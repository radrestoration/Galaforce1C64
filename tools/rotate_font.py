"""Convert the BBC 5-column font (object/O.SPFONT) into C64 character rows.

usage: rotate_font.py <in> <out>
"""
import sys


def transpose_bbc_to_c64(input_path, output_path):
    source = open(input_path, "rb").read()
    output = bytearray()  # Glyph 0 is the real font's own digit "0" (see
                          # src/CHARP.asm's DATA layout) - space is real
                          # glyph 38, not a synthetic slot 0.

    for offset in range(0, len(source), 5):
        columns = source[offset:offset + 5]
        if len(columns) < 5:
            break
        for row in range(8):
            value = 0
            for column_index, column in enumerate(columns):
                value |= ((column >> row) & 1) << (7 - column_index)
            output.append(value)

    open(output_path, "wb").write(output)


if __name__ == "__main__":
    transpose_bbc_to_c64(sys.argv[1], sys.argv[2])
