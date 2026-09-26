#!/usr/bin/env python3
import copy
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen

def parse_bdf_glyphs(bdf_path):
    """Parses a BDF file and returns a map of unicode -> pixel grid matrix."""
    glyphs = {}
    current_code = None
    bitmap = []
    in_bitmap = False
    bbx = (8, 16, 0, 0) # default width, height, xoff, yoff
    
    with open(bdf_path, 'r', encoding='latin-1', errors='ignore') as f:
        for line in f:
            parts = line.strip().split()
            if not parts:
                continue
            if parts[0] == 'ENCODING':
                current_code = int(parts[1])
            elif parts[0] == 'BBX':
                bbx = [int(p) for p in parts[1:]]
            elif parts[0] == 'BITMAP':
                in_bitmap = True
                bitmap = []
            elif parts[0] == 'ENDCHAR':
                in_bitmap = False
                if current_code is not None and current_code > 0:
                    glyphs[current_code] = {'bitmap': bitmap, 'bbx': bbx}
                current_code = None
            elif in_bitmap:
                bitmap.append(parts[0])
    return glyphs

def build_vector_glyph(bdf_entry, upm=2048, cell_height=16):
    """Converts a BDF pixel grid into a vector TTF pixel-box glyph."""
    pen = TTGlyphPen(None)
    scale = upm // cell_height
    
    bitmap = bdf_entry['bitmap']
    
    for row_idx, hex_row in enumerate(bitmap):
        val = int(hex_row, 16)
        bits = f"{val:0{len(hex_row)*4}b}"
        
        y = (cell_height - 1 - row_idx) * scale
        
        for col_idx, bit in enumerate(bits):
            if bit == '1':
                x = col_idx * scale
                # Draw a square pixel contour
                pen.moveTo((x, y))
                pen.lineTo((x + scale, y))
                pen.lineTo((x + scale, y + scale))
                pen.lineTo((x, y + scale))
                pen.closePath()
                
    return pen.glyph()

def merge_bdf_to_ttf(target_path, bdf_path, output_path):
    target = TTFont(target_path)
    bdf_glyphs = parse_bdf_glyphs(bdf_path)
    
    target_glyf = target['glyf']
    target_hmtx = target['hmtx']
    target_cmap = target.getBestCmap()
    upm = target['head'].unitsPerEm
    
    # 1. Alias GTK special symbols to standard ASCII equivalents
    quote_glyph = target_cmap.get(0x0022)
    space_glyph = target_cmap.get(0x0020)
    dash_glyph = target_cmap.get(0x002D)
    
    for table in target['cmap'].tables:
        if table.isUnicode():
            if quote_glyph:
                table.cmap[0x201C] = quote_glyph  # “
                table.cmap[0x201D] = quote_glyph  # ”
            if space_glyph:
                table.cmap[0x00A0] = space_glyph  # NBSP
            if dash_glyph:
                table.cmap[0x2013] = dash_glyph  # En-dash '–' (fixes 'ù')
                table.cmap[0x2014] = dash_glyph  # Em-dash '—'

    # 2. Vectorize and inject missing BDF glyphs (Cyrillic, extended Unicode)
    injected_count = 0
    advance_width = target_hmtx[target_cmap[0x0061]][0] # Copy 'a' width
    
    for code, bdf_data in bdf_glyphs.items():
        if code not in target_cmap and code > 32:
            new_glyph_name = f"uni{code:04X}"
            
            # Generate vector box contours
            vector_glyph = build_vector_glyph(bdf_data, upm=upm)
            
            target_glyf[new_glyph_name] = vector_glyph
            target_hmtx[new_glyph_name] = (advance_width, 0)
            
            for table in target['cmap'].tables:
                if table.isUnicode():
                    table.cmap[code] = new_glyph_name
            
            injected_count += 1

    target.save(output_path)
    print(f"[+] Successfully injected {injected_count} BDF glyphs into '{output_path}'!")

if __name__ == "__main__":
    # Ensure filenames match your local files
    merge_bdf_to_ttf("PxPlus_IBM_VGA8.ttf", "uni_vga.bdf", "PxPlus_VGA8_Extended.ttf")
