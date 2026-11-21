#language slang 2026
import kitty_custom_shader_types;

// ---- tweakables (override from the pipeline file with `var`) ----
static const float SHIFT_CELLS = 2.0;   // max sideways slice shift, in cell widths
static const float SPLIT_CELLS = 0.8;   // RGB split distance, in cell widths
static const float BAND_ROWS   = 4.0;   // glitch bands per cell height
static const float BLOCK_SIZE  = 0.5;   // pixel-block size, as a fraction of a cell
static const float PAD         = 1.5;   // how far around the trail it reaches, in cells
static const float SENSITIVITY = 3.0;   // trail lag (in cells) at which the effect is full strength

float hash(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

public float4 fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    if (d.cursor_trail_state < 0.5) return color;

    float4 edge = d.cursor_trail_edge;                    // x=left y=right z=top w=bottom
    float2 cell = float2(edge.y - edge.x, edge.z - edge.w);
    float2 head = float2(edge.x + edge.y, edge.z + edge.w) * 0.5;

    float4 cx = d.cursor_trail_corners_x;
    float4 cy = d.cursor_trail_corners_y;
    float2 tail = float2(dot(cx, float4(0.25)), dot(cy, float4(0.25)));

    // how far the trail still lags behind the cursor, in cells
    float2 lag = head - tail;
    float lagCells = length(lag / cell);
    float intensity = smoothstep(0.05, SENSITIVITY, lagCells);
    if (intensity < 0.001) return color;
    float2 dir = lagCells > 1e-4 ? normalize(lag) : float2(1.0, 0.0);

    // bounding box of trail quad + cursor, padded and feathered
    float2 bmin = float2(min(min(cx.x, cx.y), min(cx.z, cx.w)), min(min(cy.x, cy.y), min(cy.z, cy.w)));
    float2 bmax = float2(max(max(cx.x, cx.y), max(cx.z, cx.w)), max(max(cy.x, cy.y), max(cy.z, cy.w)));
    bmin = min(bmin, float2(edge.x, edge.w));
    bmax = max(bmax, float2(edge.y, edge.z));
    float2 lo = bmin - cell * PAD;
    float2 hi = bmax + cell * PAD;
    float2 dEdge = min(t.pos - lo, hi - t.pos) / (cell * PAD);
    float w = saturate(min(dEdge.x, dEdge.y)) * intensity;
    if (w < 0.01) return color;

    // per-frame seed: lag changes every frame, so the glitch pattern jitters
    float frameSeed = floor(lagCells * 16.0);

    // 1) horizontal band shifts
    float band = floor((t.pos.y / cell.y) * BAND_ROWS);
    float bandOn = step(0.45, hash(float2(band, frameSeed)));
    float shift = (hash(float2(band + 13.0, frameSeed)) - 0.5) * 2.0 * SHIFT_CELLS * cell.x;
    float2 p = t.pos;
    p.x += shift * bandOn * w;

    // 2) patchy pixelation
    float2 g = cell * BLOCK_SIZE;
    float2 blk = floor(p / g);
    float blockOn = step(0.6, hash(blk + frameSeed));
    if (blockOn * w > 0.3) p = (blk + 0.5) * g;

    // 3) RGB split along the direction of travel
    float2 off = dir * SPLIT_CELLS * cell * w;
    float4 c = t.backbuffer.Sample(p);
    float r = t.backbuffer.Sample(p + off).r;
    float b = t.backbuffer.Sample(p - off).b;
    return float4(r, c.g, b, c.a);
}
