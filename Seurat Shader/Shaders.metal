//
//  Shaders.metal
//  Seurat Shader
//
//  10 shaders ported from RetroArch slang-shaders:
//  0=None  1=CRT-Lottes  2=CRT-Royale  3=Scanlines  4=VHS
//  5=EasyMode  6=FakeLottes  7=CRT-Pi  8=Caligari  9=CRT-Geom
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct ShaderParams {
    uint  shaderIndex;
    float time;
    float p0, p1, p2, p3, p4, p5, p6, p7;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                             constant float4 *vertices [[buffer(0)]]) {
    VertexOut out;
    float4 v    = vertices[vertexID];
    out.position = float4(v.xy, 0.0, 1.0);
    out.texCoord = float2(v.z, v.w);
    return out;
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

float2 barrel(float2 uv, float wx, float wy) {
    float2 p = uv * 2.0 - 1.0;
    p *= float2(1.0 + p.y*p.y*wx, 1.0 + p.x*p.x*wy);
    return p * 0.5 + 0.5;
}

bool oob(float2 uv) {
    return uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
}

float3 lin(float3 c)  { return pow(clamp(c,0.,1.), float3(2.2)); }
float3 srgb(float3 c) { return pow(clamp(c,0.,1.), float3(1.0/2.2)); }

// ─── 0: Passthrough ──────────────────────────────────────────────────────────
float4 s_none(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    return tex.sample(s, uv);
}

// ─── 1: CRT-Lottes ───────────────────────────────────────────────────────────
// p0=warpX(0.031)  p1=warpY(0.041)  p2=maskDark(0.25)  p3=bloom(0.08)
float4 s_lottes(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 w = barrel(uv, sp.p0, sp.p1);
    if (oob(w)) return float4(0,0,0,1);
    float3 c = lin(tex.sample(s, w).rgb);
    // scanlines
    float sc = sin(w.y * float(tex.get_height()) * M_PI_F);
    c *= 0.72 + 0.28 * sc * sc;
    // RGB aperture mask
    float mx = fract(w.x * float(tex.get_width()) / 3.0);
    float md = sp.p2;
    float3 mask = (mx < 0.333) ? float3(1,md,md) : (mx < 0.666) ? float3(md,1,md) : float3(md,md,1);
    c *= mix(float3(1), mask, 0.5);
    // bloom
    float step = 1.5 / float(tex.get_width());
    float3 bl = (tex.sample(s,w+float2(-step,0)).rgb + tex.sample(s,w).rgb + tex.sample(s,w+float2(step,0)).rgb)/3.0;
    c += lin(bl) * sp.p3;
    return float4(srgb(c), 1);
}

// ─── 2: CRT-Royale (Kurozumi) ────────────────────────────────────────────────
// p0=warpX(0.025)  p1=warpY(0.035)  p2=maskDark(0.08)  p3=maskStrength(0.7)
float4 s_royale(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 w = barrel(uv, sp.p0, sp.p1);
    if (oob(w)) return float4(0,0,0,1);
    float3 c = lin(tex.sample(s, w).rgb);
    float sc = sin(w.y * float(tex.get_height()) * M_PI_F);
    c *= 0.6 + 0.4 * sc * sc;
    // Trinitron grille
    float mx = fract(w.x * float(tex.get_width()) / 3.0);
    float md = sp.p2;
    float3 mask = (mx < 0.333) ? float3(1,md,md) : (mx < 0.666) ? float3(md,1,md) : float3(md,md,1);
    c *= mix(float3(1), mask, sp.p3);
    // halation
    float st = 2.0/float(tex.get_width());
    float3 gl = (tex.sample(s,w+float2(-st,0)).rgb + tex.sample(s,w).rgb + tex.sample(s,w+float2(st,0)).rgb)/3.0;
    c += lin(gl) * 0.06;
    // vignette
    float2 vig = w*2.0-1.0; c *= 1.0 - dot(vig,vig)*0.15;
    c = pow(clamp(c,0.,1.), float3(1.0/2.4)) * 1.05;
    return float4(clamp(c,0.,1.), 1);
}

// ─── 3: Scanlines ────────────────────────────────────────────────────────────
// p0=strength(0.35) — 0=flat, 0.6=very dark scanlines
float4 s_scanlines(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float3 c = tex.sample(s, uv).rgb;
    float sc = sin(uv.y * float(tex.get_height()) * M_PI_F);
    return float4(c * ((1.0 - sp.p0) + sp.p0 * sc * sc), 1);
}

// ─── 4: VHS/Composite ────────────────────────────────────────────────────────
// p0=chromaShift(0.003)  p1=wobble(0.002)  p2=saturation(0.85)
float4 s_vhs(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float wb = sin(uv.y * 80.0 + sp.time * 4.0) * sp.p1;
    float r = tex.sample(s, uv + float2(wb + sp.p0, 0)).r;
    float g = tex.sample(s, uv + float2(wb,         0)).g;
    float b = tex.sample(s, uv + float2(wb - sp.p0, 0)).b;
    float3 c = float3(r,g,b);
    float sc = sin(uv.y * float(tex.get_height()) * M_PI_F);
    c *= 0.75 + 0.25 * sc * sc;
    float luma = dot(c, float3(0.299,0.587,0.114));
    return float4(mix(float3(luma), c, sp.p2), 1);
}

// ─── 5: EasyMode (brightness-adaptive scanlines + staggered RGB mask) ─────────
// p0=maskDark(0.7)  p1=gamma(1.8)
float4 s_easymode(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()); float H = float(tex.get_height());
    float2 pix = uv * float2(W, H) - 0.5;
    float2 tc  = (floor(pix) + 0.5) / float2(W, H);
    float2 d   = fract(pix);
    // S-curve sharpening
    float cx = 0.5 - sqrt(max(0.0, 0.25 - (d.x - step(0.5,d.x))*(d.x - step(0.5,d.x)))) * sign(0.5-d.x);
    float cy = 0.5 - sqrt(max(0.0, 0.25 - (d.y - step(0.5,d.y))*(d.y - step(0.5,d.y)))) * sign(0.5-d.y);
    float dx = 1.0/W, dy = 1.0/H;
    float3 c0 = mix(tex.sample(s,tc).rgb,          tex.sample(s,tc+float2(dx,0)).rgb,  cx);
    float3 c1 = mix(tex.sample(s,tc+float2(0,dy)).rgb, tex.sample(s,tc+float2(dx,dy)).rgb, cx);
    float3 c  = pow(mix(c0, c1, cy), float3(2.0));
    float luma   = dot(float3(0.2126,0.7152,0.0722), c);
    float bright = (max(c.r,max(c.g,c.b)) + luma) * 0.5;
    float beam   = clamp(bright * 1.5, 1.5, 1.5);
    float sw     = 1.0 - pow(cos(uv.y * 2.0 * M_PI_F * H) * 0.5 + 0.5, beam);
    float3 c2 = c; c *= sw; c = mix(c, c2, clamp(bright, 0.35, 0.65));
    float mask = sp.p0;
    float2 mf = floor(uv * float2(W,H));
    int dn = int(fmod(mf.x, 3.0));
    float3 mw = (dn==0) ? float3(1,mask,mask) : (dn==1) ? float3(mask,1,mask) : float3(mask,mask,1);
    c *= mw;
    return float4(pow(clamp(c*1.2, 0., 1.), float3(1.0/sp.p1)), 1);
}

// ─── 6: FakeLottes (sine scanlines + 4-mode shadow mask + curvature) ─────────
// p0=warpX(0.031)  p1=warpY(0.041)
float4 s_fakelottes(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()); float H = float(tex.get_height());
    float2 w = barrel(uv, sp.p0, sp.p1);
    if (oob(w)) return float4(0,0,0,1);
    float3 c = pow(tex.sample(s, w).rgb, float3(2.5));
    // sine scanlines
    float2 omega = float2(M_PI_F * W, 2.0 * M_PI_F * H);
    c *= 0.95 + dot(float2(0.0, 0.4) * sin(w * omega), float2(1,1));
    // shadow mask (aperture grille mode)
    float3 mk = float3(0.5);
    float fx = fract(w.x * W * 0.333333);
    if      (fx < 0.333) mk.r = 1.5;
    else if (fx < 0.666) mk.g = 1.5;
    else                 mk.b = 1.5;
    c *= mk;
    return float4(pow(clamp(c,0.,1.), float3(1.0/2.2)), 1);
}

// ─── 7: CRT-Pi (multisampled scanlines + trinitron mask + barrel) ────────────
// p0=distX(0.10)  p1=distY(0.15)
float4 s_crtpi(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()); float H = float(tex.get_height());
    // Distort
    float2 co = uv - 0.5;
    float rsq = co.x*co.x + co.y*co.y;
    float2 dist = float2(sp.p0, sp.p1);
    co += co * (dist * rsq);
    co *= 1.0 - 0.23 * dist;
    if (abs(co.x) >= 0.5 || abs(co.y) >= 0.5) return float4(0,0,0,1);
    float2 tc = co + 0.5;
    // Sub-pixel scanline (multisampled)
    float ty = floor(tc.y * H) + 0.5;
    float dy = tc.y * H - ty;
    float fw = (H / W) * 0.333;
    float sw  = max(1.0 - dy*dy*6.0,          0.12);
    float sw1 = max(1.0 - (dy-fw)*(dy-fw)*6.0, 0.12);
    float sw2 = max(1.0 - (dy+fw)*(dy+fw)*6.0, 0.12);
    float scan = (sw + sw1 + sw2) * 0.333 * 1.5;
    float2 stc = float2(tc.x, (ty) / H);
    float3 c = tex.sample(s, stc).rgb * scan;
    // Trinitron mask
    float wm = fract(uv.x * W * 0.333333);
    float3 mk = float3(0.70);
    if      (wm < 0.333) mk.r = 1.0;
    else if (wm < 0.666) mk.g = 1.0;
    else                 mk.b = 1.0;
    return float4(clamp(c * mk, 0., 1.), 1);
}

// ─── 8: Caligari (phosphor spot bleeding — soft pixel glow) ──────────────────
// p0=brightness(1.45)  p1=hSpread(0.9)  p2=vSpread(0.65)
float4 s_caligari(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::nearest, address::clamp_to_edge);
    float W = float(tex.get_width()); float H = float(tex.get_height());
    float2 coords = uv * float2(W, H);
    float2 pc = floor(coords) + 0.5;
    float2 tc = pc / float2(W, H);
    float4 c = pow(tex.sample(s, tc), float4(2.4));
    float dx = coords.x - pc.x;
    float hs = max(sp.p1, 0.01);
    // horizontal phosphor spot
    float hw0 = dx / hs; hw0 = clamp(hw0, -1., 1.); hw0 = 1.-hw0*hw0; hw0=hw0*hw0;
    c *= hw0;
    float2 nb = dx > 0.0 ? float2(1.0/W, 0) : float2(-1.0/W, 0);
    float dx2 = dx > 0.0 ? 1.0-dx : 1.0+dx;
    float hw1 = dx2 / hs; hw1 = clamp(hw1,-1.,1.); hw1=1.-hw1*hw1; hw1=hw1*hw1;
    float4 cn = pow(tex.sample(s, tc+nb), float4(2.4));
    c += cn * hw1;
    // vertical phosphor spot
    float dy = coords.y - pc.y;
    float vs = max(sp.p2, 0.01);
    float vw0 = dy / vs; vw0 = clamp(vw0,-1.,1.); vw0=1.-vw0*vw0; vw0=vw0*vw0;
    c *= vw0;
    float2 nv = dy > 0.0 ? float2(0, 1.0/H) : float2(0, -1.0/H);
    float dy2 = dy > 0.0 ? 1.0-dy : 1.0+dy;
    float vw1 = dy2 / vs; vw1=clamp(vw1,-1.,1.); vw1=1.-vw1*vw1; vw1=vw1*vw1;
    float4 cv = pow(tex.sample(s, tc+nv), float4(2.4));
    c += cv * float4(vw1*hw0);
    float4 cnv = pow(tex.sample(s, tc+nb+nv), float4(2.4));
    c += cnv * float4(vw1*hw1);
    c *= sp.p0;
    return clamp(pow(c, float4(1.0/2.2)), 0., 1.);
}

// ─── 9: CRT-Geom (full spherical curvature + corner rounding + Lanczos) ──────
// p0=curvature/R(2.0)  p1=corner(0.03)  p2=maskAmt(0.3)
float4 s_geom(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()); float H = float(tex.get_height());
    // Spherical distortion (simplified from cgwg's crt-geom)
    float2 uvc = uv * 2.0 - 1.0;
    float d = 1.5, R = sp.p0;
    float2 sa = float2(0.0), ca = float2(1.0);
    float A = dot(uvc,uvc) + d*d;
    float B = 2.0*(R*(dot(uvc,sa)-d*ca.x*ca.y)-d*d);
    float C = d*d + 2.0*R*d*ca.x*ca.y;
    float t = (-B - sqrt(max(B*B-4.0*A*C,0.0))) / (2.0*A);
    float2 pt = (t*uvc - (-R)*sa) / R;
    float2 poc = pt / ca;
    float2 tang = sa/ca;
    float A2 = dot(tang,tang)+1.0, B2 = -2.0*dot(poc,tang), C2 = dot(poc,poc)-1.0;
    float a = (-B2+sqrt(max(B2*B2-4.0*A2*C2,0.0)))/(2.0*A2);
    float2 uv2 = (pt - a*sa)/ca;
    float r2 = R*acos(clamp(a,-1.,1.));
    float sr = max(sin(r2/R), 1e-5);
    uv2 = uv2 * r2 / sr;
    float2 xy = uv2 * float2(1.0/1.0, 1.0/0.75) * 0.5 + 0.5;
    if (oob(xy)) return float4(0,0,0,1);
    // Corner rounding
    float2 cco = min(xy, 1.0-xy) * float2(1.0, 0.75);
    float cr = max(sp.p1, 0.001);
    float2 cd = max(float2(cr) - cco, float2(0));
    float corner = clamp((cr - length(cd)) * 1000.0, 0.0, 1.0);
    // Lanczos2 horizontal filter
    float2 one = 1.0 / float2(W, H);
    float2 ratio = xy * float2(W, H);
    float2 uvr = fract(ratio);
    float2 xysnap = (floor(ratio) + 0.5) / float2(W, H);
    float4 co2 = M_PI_F * float4(1.0+uvr.x, uvr.x, 1.0-uvr.x, 2.0-uvr.x);
    co2 = max(abs(co2), 1e-5);
    co2 = 2.0*sin(co2)*sin(co2*0.5)/(co2*co2);
    co2 /= dot(co2, float4(1));
    float3 col  = clamp((float4(pow(tex.sample(s,xysnap+float2(-one.x,0)).rgb,float3(2.4)),1)*co2.x
                        +float4(pow(tex.sample(s,xysnap).rgb,float3(2.4)),1)*co2.y
                        +float4(pow(tex.sample(s,xysnap+float2(one.x,0)).rgb,float3(2.4)),1)*co2.z
                        +float4(pow(tex.sample(s,xysnap+float2(2*one.x,0)).rgb,float3(2.4)),1)*co2.w).rgb,0.,1.);
    float3 col2 = clamp((float4(pow(tex.sample(s,xysnap+float2(-one.x,one.y)).rgb,float3(2.4)),1)*co2.x
                        +float4(pow(tex.sample(s,xysnap+float2(0,one.y)).rgb,float3(2.4)),1)*co2.y
                        +float4(pow(tex.sample(s,xysnap+one).rgb,float3(2.4)),1)*co2.z
                        +float4(pow(tex.sample(s,xysnap+float2(2*one.x,one.y)).rgb,float3(2.4)),1)*co2.w).rgb,0.,1.);
    // Scanlines
    float4 sw1 = float4(2.0+2.0*pow(float4(col,1),float4(4.0)));
    float4 sw2 = float4(2.0+2.0*pow(float4(col2,1),float4(4.0)));
    float wy1 = exp(-pow(float4(uvr.y/0.3),sw1).r);
    float wy2 = exp(-pow(float4((1.0-uvr.y)/0.3),sw2).r);
    float3 rgb = clamp((col*wy1 + col2*wy2) * corner, 0., 1.);
    // Dot mask
    float2 mp = fract(uv * float2(W,H) / float2(W,H) * float2(W,H));
    float fx = fract(mp.x * 0.333333);
    float3 dm = (fx<0.333)?float3(1,.3,.3):(fx<0.666)?float3(.3,1,.3):float3(.3,.3,1);
    rgb *= mix(float3(1), dm, sp.p2);
    return float4(pow(rgb, float3(1.0/2.2)), 1);
}

// ─── 10: CRT-Mattias (Gaussian bloom + crawling scanlines + noise + curvature) ─
// p0=noiseAmt(0.04)  p1=scanSpeed(3.5)
float4 s_mattias(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    // Curve
    float2 st = uv - 0.5;
    float2 c = st * 2.0; c *= 1.1;
    c.x *= 1.0 + pow(abs(c.y)/5.0, 2.0);
    c.y *= 1.0 + pow(abs(c.x)/4.0, 2.0);
    float2 w = c*0.5 + 0.5; w = w*0.92+0.04;
    if (oob(w)) return float4(0,0,0,1);
    // 5x5 Gaussian blur with per-channel offset (chroma)
    auto fetch = [&](float2 p) { return pow(tex.sample(s,p).rgb, float3(2.2)); };
    float ox = 1.5/W, oy = 1.5/H;
    float3 col = float3(0);
    float2 offsets[5] = {float2(-2*ox,-2*oy),float2(-ox,-oy),float2(0,0),float2(ox,oy),float2(2*ox,2*oy)};
    float wts[5] = {0.0366,0.1465,0.2420,0.1465,0.0366};
    for (int i=0;i<5;i++) for (int j=0;j<5;j++)
        col += fetch(w+float2(offsets[i].x,offsets[j].y))*wts[i]*wts[j];
    col = clamp(col*0.4+0.6*col*col,0.,1.);
    // Vignette
    float vig = pow(16.0*w.x*w.y*(1-w.x)*(1-w.y),0.3);
    col *= vig;
    // Crawling scanlines
    float scan = clamp(0.35+0.15*sin(sp.p1*sp.time+uv.y*H*1.5),0.,1.);
    col *= pow(scan,0.9);
    // Noise
    float sn = fract(sin(dot(uv+0.0001*sp.time,float2(12.9898,78.233)))*43758.5453);
    col -= sn*sp.p0;
    col = pow(clamp(col,0.,1.),float3(0.45));
    return float4(col,1);
}

// ─── 11: CRT-Frutbunn (Gaussian blur + vignette + cos scanlines + curvature) ──
// p0=curvature(0.935)  p1=scanStrength(0.25)
float4 s_frutbunn(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    float2 st = uv - 0.5;
    float d = length(st*0.5*st*0.5);
    float2 w = st*(d+sp.p0);
    if (abs(w.x)>0.5||abs(w.y)>0.5) return float4(0,0,0,1);
    w += 0.5;
    // 3x3 Gaussian
    float b = 1.0/W;
    float3 col = tex.sample(s,float2(w.x-b,w.y-b)).rgb*0.077847
               + tex.sample(s,float2(w.x,  w.y-b)).rgb*0.123317
               + tex.sample(s,float2(w.x+b,w.y-b)).rgb*0.077847
               + tex.sample(s,float2(w.x-b,w.y  )).rgb*0.123317
               + tex.sample(s,float2(w.x,  w.y  )).rgb*0.195346
               + tex.sample(s,float2(w.x+b,w.y  )).rgb*0.123317
               + tex.sample(s,float2(w.x-b,w.y+b)).rgb*0.077847
               + tex.sample(s,float2(w.x,  w.y+b)).rgb*0.123317
               + tex.sample(s,float2(w.x+b,w.y+b)).rgb*0.077847;
    // Vignette
    float l = 1.0 - min(1.0, d*9.0);
    col *= l;
    // Scanlines
    float sc = 2.5 + H * (1.0/H);
    float j = cos((w.y-0.5)*H*sc)*sp.p1;
    col = col - col*j;
    // Border
    float m = min(1.0, 200.0*max(0.0, 1.0-2.0*max(abs(w.x-0.5),abs(w.y-0.5))));
    col *= m;
    return float4(clamp(col,0.,1.),1);
}

// ─── 12: CRT-cgwg-fast (Lanczos filter + beam width + magenta/green mask) ─────
float4 s_cgwg(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    float2 ratio = uv * float2(W,H);
    float2 uvr = fract(ratio);
    float dx = 1.0/W, dy = 1.0/H;
    float2 tc = (floor(ratio)+0.5)/float2(W,H);
    // Lanczos4 horizontal
    float4 co = float4(1+uvr.x,uvr.x,1-uvr.x,2-uvr.x)*M_PI_F + 0.005;
    co = sin(co)*sin(co*0.5)/(co*co);
    co /= dot(co,float4(1));
    float3 c0 = clamp((float4(tex.sample(s,tc+float2(-dx,0)).rgb,1)*co.x
                      +float4(tex.sample(s,tc).rgb,1)*co.y
                      +float4(tex.sample(s,tc+float2(dx,0)).rgb,1)*co.z
                      +float4(tex.sample(s,tc+float2(2*dx,0)).rgb,1)*co.w).rgb,0.,1.);
    float3 c1 = clamp((float4(tex.sample(s,tc+float2(-dx,dy)).rgb,1)*co.x
                      +float4(tex.sample(s,tc+float2(0,dy)).rgb,1)*co.y
                      +float4(tex.sample(s,tc+float2(dx,dy)).rgb,1)*co.z
                      +float4(tex.sample(s,tc+float2(2*dx,dy)).rgb,1)*co.w).rgb,0.,1.);
    // Beam weights
    float3 wid  = 2.0*pow(c0,float3(4))+2.0;
    float3 wid2 = 2.0*pow(c1,float3(4))+2.0;
    c0 = pow(c0,float3(2.7)); c1 = pow(c1,float3(2.7));
    float3 w1 = exp(-pow(uvr.y    *rsqrt(0.5*wid )*wid ,wid ))/(0.1320*wid +0.392);
    float3 w2 = exp(-pow((1-uvr.y)*rsqrt(0.5*wid2)*wid2,wid2))/(0.1320*wid2+0.392);
    float3 res = c0*w1*3.33 + c1*w2*3.33;
    // Magenta/green mask
    float3 mk = (fmod(uv.x*W,2.0)<1.0)?float3(1,0.7,1):float3(0.7,1,0.7);
    return float4(pow(clamp(mk*res,0.,1.),float3(0.4545)),1);
}

// ─── 13: CRT-Simple (gaussian beam scanlines + dot mask + distortion) ─────────
// p0=distX(0.12)  p1=distY(0.18)
float4 s_simple(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    // Distortion
    float2 co = uv - 0.5;
    float rsq = co.x*co.x + co.y*co.y;
    co += co*(float2(sp.p0,sp.p1)*rsq);
    co *= 1.0-0.23*float2(sp.p0,sp.p1);
    if (abs(co.x)>=0.5||abs(co.y)>=0.5) return float4(0,0,0,1);
    float2 w = co + 0.5;
    float2 rs = w*float2(W,H) - 0.5;
    float2 uvr = fract(rs);
    float2 snap = (floor(rs)+0.5)/float2(W,H);
    float4 c0 = pow(tex.sample(s,snap),float4(2.4));
    float4 c1 = pow(tex.sample(s,snap+float2(0,1.0/H)),float4(2.4));
    float4 wid  = 2.0+2.0*pow(c0,float4(4));
    float4 wid2 = 2.0+2.0*pow(c1,float4(4));
    float4 sw1 = 1.4*exp(-pow(float4(uvr.y  /0.3)*rsqrt(0.5*wid ),wid ))/(0.6+0.2*wid);
    float4 sw2 = 1.4*exp(-pow(float4((1-uvr.y)/0.3)*rsqrt(0.5*wid2),wid2))/(0.6+0.2*wid2);
    float3 res = (c0*sw1+c1*sw2).rgb;
    float dm = mix(0.7, 1.0, fract(uv.x*W*0.5));
    return float4(pow(clamp(res,0.,1.),float3(1.0/2.2)),1);
}

// ─── 14: CRT-Sines (sharp-bilinear + sine scanlines + chroma shift + mask) ────
// p0=chromaPixels(0.5)  p1=scanStrength(1.0)
float4 s_sines(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    // Sharp bilinear
    float2 texel = uv*float2(W,H);
    float2 tf = floor(texel);
    float2 fr = fract(texel)-0.5;
    float2 tc2 = (tf + 0.5 + clamp(fr/fwidth(fr)*0.5,-0.5,0.5))/float2(W,H);
    // Chroma ghost
    float px = sp.p0/W;
    float3 col = float3(
        tex.sample(s,tc2+float2(px,0)).r,
        tex.sample(s,tc2).g,
        tex.sample(s,tc2-float2(px,0)).b);
    col = pow(col,float3(2.4));
    // Scanlines
    float lum = dot(col,float3(0.3,0.6,0.1));
    float scl = mix(0.75,0.4,lum) * sp.p1;
    col *= scl*sin(fract(uv.y*H)*M_PI_F)+(1.0-scl);
    // Mask
    float msk = mix(0.3,0.6,lum);
    float mx = abs(sin(uv.x*W*M_PI_F*0.5));
    col = mix(col*mx, col, lum*0.7);
    // Brightness boost
    col *= mix(1.45,1.3,lum);
    return float4(pow(clamp(col,0.,1.),float3(1.0/2.25)),1);
}

// ─── 15: Gizmo-CRT (subpixel RGB shift + brightness scanlines + noise) ────────
// p0=distX(0.10)  p1=distY(0.15)
float4 s_gizmo(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    // Barrel distortion
    float2 co = uv - 0.5;
    float rsq = co.x*co.x+co.y*co.y;
    co += co*(float2(sp.p0,sp.p1)*rsq);
    co *= 1.0-0.23*float2(sp.p0,sp.p1);
    if (abs(co.x)>=0.5||abs(co.y)>=0.5) return float4(0,0,0,1);
    float2 w = co+0.5;
    // Subpixel RGB horizontal shift (aperture grille simulation)
    float spread = 0.333/W;
    float r = tex.sample(s, w+float2(spread*2,0)).r;
    float g = tex.sample(s, w+float2(spread,  0)).g;
    float b = tex.sample(s, w).b;
    float3 col = float3(r,g,b);
    // Brightness-dependent scanlines
    float brightness = 0.5/0.5*0.05;
    float scale2 = (H/H)*0.5;
    float fy = fract(uv.y*H)-0.5;
    float dim = brightness*scale2*(abs(1.5*(1.0-col)*abs(abs(fy)-0.5))).x;
    col -= dim;
    // Gold noise
    float PHI = 1.61803398875;
    float sn = fract(tan(distance(uv*PHI,uv)*fract(sp.time*0.025))*uv.x);
    col = clamp(col + sn/32.0 - 1.0/64.0, 0., 1.);
    return float4(col,1);
}

// ─── 16: ZFast-CRT (composite convergence + sine scanlines + mask + curvature)
// p0=warpX(0.03)  p1=warpY(0.05)  p2=flicker(0.01)
float4 s_zfast(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    // Warp
    float2 uvc = uv*2.0-1.0;
    uvc *= float2(1.0+(uvc.y*uvc.y)*sp.p0, 1.0+(uvc.x*uvc.x)*sp.p1);
    float2 w = uvc*0.5+0.5;
    float2 corn = min(w,1.0-w);
    if (corn.x<0.00001||corn.y<0.0) return float4(0,0,0,1);
    // Snap to scanline
    float OGL2Pos = w.y*H;
    float cent = floor(OGL2Pos)+0.5;
    float yc = mix(w.y, cent/H, 0.6);
    float bx = 0.85/(W*2.0), by = 0.10/(H*2.0);
    float flick = sin(sp.time*2.0)*sp.p2;
    float3 c1 = flick + tex.sample(s,float2(w.x+bx,yc-by)).rgb;
    float3 c2 = 0.5*tex.sample(s,float2(w.x,yc)).rgb;
    float3 c3 = flick + tex.sample(s,float2(w.x-bx,yc+by)).rgb;
    float3 col = float3(c1.r*0.5+c2.r, c1.g*0.25+c2.g+c3.g*0.25, c2.b+c3.b*0.5);
    // Saturation
    float lum = dot(col,float3(0.22,0.71,0.07));
    col = mix(float3(lum),col,1.0);
    // Scanlines
    float SCAN = mix(0.4,0.3,max(max(col.r,col.g),col.b));
    col *= SCAN*sin(fract(OGL2Pos)*M_PI_F)+1.0-SCAN;
    col *= SCAN*sin(fract(1.0-OGL2Pos)*M_PI_F)+1.0-SCAN;
    // Mask
    float mask = 1.0 + float(fract(uv.x*W*0.5)<0.5)*(-0.3);
    col = mix(mask*col, col, dot(col,float3(0.1)));
    // Corner kill
    if (corn.x*100.0<1.0) col = float3(0);
    return float4(clamp(col,0.,1.),1);
}

// ─── 17: Yeetron (per-pixel scanline dimming + RGB channel weighting) ──────────
float4 s_yeetron(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    float2 pixPos = floor(uv*float2(W,H));
    float intPos = fract((pixPos.y*3.0+pixPos.x)*0.166667);
    float3 intensity = float3(1.2,0.9,0.9);
    float3 scanRGB = (intPos<0.333)?intensity.xyz:(intPos<0.666)?intensity.zxy:intensity.yzx;
    float scanA = clamp(abs(sin(uv.y*H*M_PI_F))+0.25,0.5,1.0);
    float2 pp = fract(uv*float2(W,H))-0.5;
    float2 inv = -uv*float2(W,H)+(floor(uv*float2(W,H))+0.5);
    float2 ntp = float2(clamp(-abs(inv.x*0.5)+1.5,0.8,1.25), clamp(-abs(inv.y*2.0)+1.25,0.5,1.0));
    float2 cm = float2(ntp.x*ntp.y, ntp.x*((scanA+ntp.y)*0.5));
    float2 tp = ((pp-clamp(pp,-0.25,0.25))*2.0+floor(uv*float2(W,H))+0.5)/float2(W,H);
    float4 tc = tex.sample(s,tp);
    float3 bl = float3(scanA*tc.r, cm.x*tc.g, cm.y*tc.b);
    float3 col = scanRGB*bl;
    return float4(clamp(col,0.,1.),1);
}

// ─── 18: Yee64 (Gaussian pixel blur + scanline dimming + RGB weighting) ───────
float4 s_yee64(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float W = float(tex.get_width()), H = float(tex.get_height());
    float2 size2 = uv*float2(W,H);
    float2 exp2 = fract(size2)-0.5;
    float4 factor = float4(
        pow(2.0,pow(-1.0-exp2.x,2.0)*(-3.0)),
        pow(2.0,pow( 1.0-exp2.x,2.0)*(-3.0)),
        pow(2.0,pow(-2.0-exp2.x,2.0)*(-3.0)),
        pow(2.0,pow( 2.0-exp2.x,2.0)*(-3.0)));
    float f2 = pow(2.0,pow(exp2.x,2.0)*-3.0);
    float3 power = float3(
        pow(2.0,pow(exp2.y,    2.0)*-8.0),
        pow(2.0,pow(-exp2.y-1.0,2.0)*-8.0),
        pow(2.0,pow(-exp2.y+1.0,2.0)*-8.0));
    float2 pixPos = floor(uv*float2(W,H));
    float iPos = fract((pixPos.y*3.0+pixPos.x)*0.166667);
    float3 intensity = float3(1.2,0.9,0.9);
    float3 scanRGB = (iPos<0.333)?intensity.xyz:(iPos<0.666)?intensity.zxy:intensity.yzx;
    float b = 1.5;
    auto tc = [&](float2 off) { return tex.sample(s,(floor(size2+off)+0.5)/float2(W,H)).rgb*b; };
    float3 c0=tc(float2( 0,-1)); float3 c1=tc(float2( 1,-1));
    float3 c2=tc(float2(-2, 0)); float3 c3=tc(float2(-1, 0));
    float3 c4=tc(float2( 0, 0)); float3 c5=tc(float2( 1, 0)); float3 c6=tc(float2( 2, 0));
    float3 c7=tc(float2(-1, 1)); float3 c8=tc(float2( 0, 1)); float3 c9=tc(float2( 1, 1));
    float3 final =
        power.x*(c2+c3+c5+c4+c6)/(factor.z+factor.x+factor.y+f2+factor.w)+
        power.y*(c1+c7+c0)/(factor.y+factor.x+f2)+
        power.z*(c9+c8+c8)/(factor.y+factor.x+f2);
    return float4(clamp(scanRGB*final,0.,1.),1);
}

// ─── 19: Fluid Iridescence ───────────────────────────────────────────────────
// p0=speed(0.4)  p1=strength(0.025)  p2=scale(2.5)  p3=iridescence(0.8)
float4 s_fluid_iridescence(float2 uv, texture2d<float> tex, constant ShaderParams& sp) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float speed    = sp.p0;
    float strength = sp.p1;
    float scale    = sp.p2;
    float irid     = sp.p3;
    float t        = sp.time * speed;

    // fBm UV distortion — 4 octaves of sin/cos interference patterns.
    // Each octave's query point is offset by the accumulated displacement so
    // far, giving the characteristic turbulent self-folding quality.
    float2 p    = uv * scale;
    float2 disp = float2(0.0);
    float  amp  = 1.0;
    float  freq = 1.0;

    for (int i = 0; i < 4; i++) {
        float2 q = p * freq + float2(t * 0.31, t * 0.17);
        float2 r;
        r.x = sin(q.x * 1.7 + sin(q.y * 1.3 + t * 0.23))
            + sin(q.y * 0.9 + sin(q.x * 2.1 + t * 0.11));
        r.y = cos(q.x * 1.3 + cos(q.y * 1.7 + t * 0.19))
            + cos(q.y * 2.0 + cos(q.x * 0.8 + t * 0.27));

        // Feed accumulated displacement back into the next octave's origin.
        p    += r * 0.4;
        disp += r * amp;
        amp  *= 0.5;
        freq *= 2.1;
    }

    // Apply displacement to UV and sample.
    float2 warpedUV = uv + disp * (strength * 0.25);
    float3 c = tex.sample(s, clamp(warpedUV, 0.0, 1.0)).rgb;

    // Iridescence via YIQ hue rotation, preserving luma (Y channel).
    float Y = dot(c, float3( 0.299,  0.587,  0.114));
    float I = dot(c, float3( 0.596, -0.274, -0.321));
    float Q = dot(c, float3( 0.211, -0.523,  0.311));

    // Rotation angle driven by displacement magnitude and time, scaled by irid.
    float dispMag = length(disp) * 0.25;   // normalised ~0–1
    float angle   = (dispMag * M_PI_F + t * 0.5) * irid;
    float ca = cos(angle), sa = sin(angle);
    float Ir =  ca * I - sa * Q;
    float Qr =  sa * I + ca * Q;

    float3 result;
    result.r = Y + 0.956 * Ir + 0.621 * Qr;
    result.g = Y - 0.272 * Ir - 0.647 * Qr;
    result.b = Y - 1.106 * Ir + 1.703 * Qr;

    return float4(clamp(result, 0.0, 1.0), 1.0);
}

// ─── fragment_main dispatcher ─────────────────────────────────────────────────
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> videoTexture [[texture(0)]],
                              constant ShaderParams& sp [[buffer(1)]]) {
    switch (sp.shaderIndex) {
        case 1:  return s_lottes    (in.texCoord, videoTexture, sp);
        case 2:  return s_royale    (in.texCoord, videoTexture, sp);
        case 3:  return s_scanlines (in.texCoord, videoTexture, sp);
        case 4:  return s_vhs       (in.texCoord, videoTexture, sp);
        case 5:  return s_easymode  (in.texCoord, videoTexture, sp);
        case 6:  return s_fakelottes(in.texCoord, videoTexture, sp);
        case 7:  return s_crtpi     (in.texCoord, videoTexture, sp);
        case 8:  return s_caligari  (in.texCoord, videoTexture, sp);
        case 9:  return s_geom      (in.texCoord, videoTexture, sp);
        case 10: return s_mattias   (in.texCoord, videoTexture, sp);
        case 11: return s_frutbunn  (in.texCoord, videoTexture, sp);
        case 12: return s_cgwg      (in.texCoord, videoTexture, sp);
        case 13: return s_simple    (in.texCoord, videoTexture, sp);
        case 14: return s_sines     (in.texCoord, videoTexture, sp);
        case 15: return s_gizmo     (in.texCoord, videoTexture, sp);
        case 16: return s_zfast     (in.texCoord, videoTexture, sp);
        case 17: return s_yeetron   (in.texCoord, videoTexture, sp);
        case 18: return s_yee64              (in.texCoord, videoTexture, sp);
        case 19: return s_fluid_iridescence (in.texCoord, videoTexture, sp);
        default: return s_none              (in.texCoord, videoTexture, sp);
    }
}
