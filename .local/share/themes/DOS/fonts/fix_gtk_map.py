#!/usr/bin/env python3
from fontTools.ttLib import TTFont

def fix_dos_unicode_map(input_path, output_path):
    font = TTFont(input_path)
    
    # Access best Unicode character map table
    cmap = font.getBestCmap()
    
    # 1. Find the internal glyph names for standard quotes (") and space ( )
    quote_glyph = cmap.get(0x0022)  # '"'
    space_glyph = cmap.get(0x0020)  # ' '
    
    if not quote_glyph or not space_glyph:
        print("[!] Could not find basic ascii quotes or space in font.")
        return

    # 2. Map GTK's smart quotes (“ ”) directly to the standard double quote glyph
    # 3. Map GTK's non-breaking space (NBSP) directly to the standard space glyph
    for table in font['cmap'].tables:
        if table.isUnicode():
            table.cmap[0x201C] = quote_glyph  # Left double quote “
            table.cmap[0x201D] = quote_glyph  # Right double quote ”
            table.cmap[0x2018] = quote_glyph  # Single quote ‘
            table.cmap[0x2019] = quote_glyph  # Single quote ’
            table.cmap[0x00A0] = space_glyph  # Non-breaking space (fixes 'á')

    # Save output font cleanly without FontForge or re-encoding mangling
    font.save(output_path)
    print(f"[+] Successfully mapped missing GTK unicode slots in '{output_path}'!")

if __name__ == "__main__":
    # Works on Perfect DOS, Flexi IBM, or any CP437-based TTF file
    fix_dos_unicode_map("Perfect DOS VGA 437.ttf", "Perfect_DOS_VGA_GTK_Fixed.ttf")
