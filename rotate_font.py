"""Convert the BBC 5-column font into C64 character rows."""


def transpose_bbc_to_c64(input_path, output_path):
    source = open(input_path, "rb").read()
    output = bytearray(8)  # Character 0 is the blank space.

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


transpose_bbc_to_c64("object/O.SPFONT", "object/O.SPFONT_C64")
