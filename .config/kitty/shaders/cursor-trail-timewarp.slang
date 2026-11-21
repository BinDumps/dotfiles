#language slang 2026
import kitty_custom_shader_types;

static const float MIN_LAG   = 0.3;    // trail lag (cells) before it kicks in
static const float MAX_LEN   = 300.0;  // cap on smear length, in cells
static const float ROW_BAND  = 0.5;    // half-height of the smeared band, in cells (0.5 = exactly the cursor's row)
static const float ALLOW_VERTICAL = 0.0; // 1 = also smear vertical jumps, confined to COL_BAND
static const float COL_BAND  = 3.0;    // half-width of the band for vertical jumps, in cells
static const float BLOCK     = 0.12;   // slice thickness across the sweep, fraction of a cell, DEFAULT: 0.12
static const float HOLD_MIN  = 1.5;    // streak length range at the far end, in cells
static const float HOLD_MAX  = 5.0;    // DEFAULT: 9.0
static const float NEAR_HOLD = 0.2;    // streak length near the cursor, as a fraction of far-end length
static const float WOBBLE    = 0.35;   // slice wobble across the sweep, in cells
static const float WAVE_FREQ = 0.6;    // wobble frequency along the sweep

float hash(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

public float4 fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    if (d.cursor_trail_state < 0.5) return color;

    float4 edge = d.cursor_trail_edge;                    // x=left y=right z=top w=bottom
    float2 cell = float2(edge.y - edge.x, edge.z - edge.w);
    float2 head = float2(edge.x + edge.y, edge.z + edge.w) * 0.5;

    // cheap early-out: skip every pixel outside the cursor's row (or column band if enabled)
    float2 dh = abs(t.pos - head) / cell;
    if (dh.y > ROW_BAND && (ALLOW_VERTICAL < 0.5 || dh.x > COL_BAND)) return color;

    float4 cx = d.cursor_trail_corners_x;
    float4 cy = d.cursor_trail_corners_y;
    float2 mid = float2(dot(cx, float4(0.25)), dot(cy, float4(0.25)));

    float2 lagc = (head - mid) / cell;
    float lagLen = length(lagc);
    if (lagLen < MIN_LAG) return color;

    // sweep axis = dominant direction of travel
    bool horiz = abs(lagc.x) > abs(lagc.y);
    if (!horiz && ALLOW_VERTICAL < 0.5) return color;
    if (horiz && dh.y > ROW_BAND) return color;
    if (!horiz && dh.x > COL_BAND) return color;

    float2 ax = horiz ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 ot = float2(ax.y, ax.x);
    float sc = horiz ? cell.x : cell.y;
    float oc = horiz ? cell.y : cell.x;

    float s  = dot(t.pos, ax);
    float sh = dot(head, ax);
    float o  = dot(t.pos, ot);
    float toward = dot(head - mid, ax) > 0.0 ? 1.0 : -1.0;   // direction of travel

    // smear covers the full span of the trail, from the cursor back to its trailing end
    float4 ca = horiz ? cx : cy;
    float lo = min(min(ca.x, ca.y), min(ca.z, ca.w));
    float hi = max(max(ca.x, ca.y), max(ca.z, ca.w));
    float trailing = toward > 0.0 ? lo : hi;
    float len = min(abs(sh - trailing) / sc + 0.5, MAX_LEN);

    float behind = -(s - sh) * toward / sc;                  // cells behind the cursor
    if (behind < 0.5) return color;

    // slices across the sweep, each with its own random streak length
    float g = oc * BLOCK;
    float blk = floor(o / g);
    float jump = hash(floor(head / cell));                   // different pattern per jump
    float r1 = hash(float2(blk, jump * 91.0));
    float r2 = hash(float2(blk + 17.0, jump * 53.0));
    float r3 = hash(float2(blk + 41.0, jump * 29.0));

    float lenS = len * lerp(0.75, 1.1, r2);                  // ragged far edge
    float swept = smoothstep(0.5, 1.0, behind) * (1.0 - smoothstep(lenS * 0.85, lenS, behind));
    if (swept < 0.001) return color;

    // sample-and-hold along the sweep: short streaks near the cursor, long far away
    float u = saturate(behind / len);
    float H = max(lerp(HOLD_MIN, HOLD_MAX, r1) * lerp(NEAR_HOLD, 1.0, u), 0.05);
    float sa = sh - toward * floor(behind / H) * H * sc;

    float wob = sin(behind * WAVE_FREQ + r3 * 6.2831 - lagLen * 4.0) * WOBBLE * oc * u;
    float oq = (blk + 0.5) * g + wob;

    float4 smear = t.backbuffer.Sample(ax * sa + ot * oq);
    return lerp(color, smear, swept);
}
