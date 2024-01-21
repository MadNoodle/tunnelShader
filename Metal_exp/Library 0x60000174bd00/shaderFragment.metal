#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float3 iResolution;           // viewport resolution (in pixels)
    float iTime;                  // shader playback time (in seconds)
    int iFrame;                   // shader playback frame
}__attribute__ ((aligned (16)));

struct Vertex {
    float4 position [[position]];
}__attribute__ ((aligned (16)));

vertex Vertex vertex_main(const device float2* inVertex [[buffer(0)]], unsigned int vertexID [[vertex_id]]) {
    Vertex out;
    out.position = float4(inVertex[vertexID].x, inVertex[vertexID].y, 0.0, 1.0);
    return out;
}

float3 path(float t) {
    return float3(sin(t * .3 + cos(t * .2) * .5) * 4., cos(t * .2) * 3., t);
}

float2x2 rot(float a) {
    float s = sin(a), c = cos(a);
    return float2x2(c, s, -s, c);
}

float hexagon(float2 p, float r) {
    const float3 k = float3(-0.866025404, 0.5, 0.577350269);
    p = abs(p);
    p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
    p -= float2(clamp(p.x, -k.z * r, k.z * r), r);
    return length(p) * sign(p.y);
}

float hex(float2 p) {
    if (p < -5) {
        p.x *= 0.57735*2.0;
        p.y+=fmod(floor(p.x),2.0)*0.5;
        p=abs((fmod(p,1.0) - 0.5));
        return abs(max(p.x*1.5 + p.y, p.y*2.0) - 1.0);
    } else {
        p.x *= 0.57735*8.0;
        p.y+=fmod(floor(p.x),2.0)*0.5;
        p=abs((fmod(p,1.0) - 0.5));
        return abs(max(p.x*1.5 + p.y, p.y*2.0) - 1.0);
    }
}


float3x3 lookat(float3 dir) {
    float3 up = float3(0., 1., 0.);
    float3 rt = normalize(cross(dir, up));
    return float3x3(rt, cross(rt, dir), dir);
}

float de(
         float3 p,
         constant Uniforms& uniforms,
         thread float& tcol,
         thread float& bcol,
         thread float& hexpos,
         thread float& fparam,
         float3 point,
         float3 hpos,
         thread float& hitbol
         ) {
    
             float3 pt = p - float3(path(p.z).xy, 0);
    float h = abs(hexagon(pt.xy, 3. + fparam));
    hexpos = hex(pt.yz);
    tcol = smoothstep(.0, .15, hexpos);
    h -= tcol * .1;
    float3 pp = p - hpos;
    pp = lookat(point) * pp;
//    pp.y -= abs(sin(uniforms.iTime)) * 3. + (fparam - (2. - fparam));
    pp.y = -5; // Put the ball out the screen
    float2x2 rotationMatrix = rot(-uniforms.iTime);
    pp.yz = float2(
        pp.y * rotationMatrix[0].x + pp.z * rotationMatrix[0].y,
        pp.y * rotationMatrix[1].x + pp.z * rotationMatrix[1].y
    );

    float bola = length(pp) - 1.;
    bcol = smoothstep(0., .5, hex(pp.xy * 3.));
    bola -= bcol * .1;
    float3 pr = p;
    pr.z = fmod(p.z, 6.) - 3.;
    float d = min(h, bola);
    if (d == bola) {
        tcol = 1.;
        hitbol = 1.;
    } else {
        hitbol = 0.;
        bcol = 1.;
        
    }
    return d * .5;
}

float3 normal(
              float3 p,
              constant Uniforms& uniforms,
              thread float& tcol,
              thread float& bcol,
              thread float& hexpos,
              thread float& fparam,
              float3 hpos,
              float3 point,
              thread float& hitbol
              ) {
    float2 e = float2(0., .005);
    return normalize(float3(
                            de(p + e.yxx, uniforms, tcol, bcol, hexpos, fparam, point, hpos, hitbol),
                            de(p + e.xyx, uniforms, tcol, bcol, hexpos, fparam, point, hpos, hitbol),
                            de(p + e.xxy, uniforms, tcol, bcol, hexpos, fparam, point, hpos, hitbol)) - de(p, uniforms, tcol, bcol, hexpos, fparam, point, hpos, hitbol));
}

float3 march(
             float3 from,
             float3 dir,
             constant Uniforms& uniforms,
             thread float& tcol,
             thread float& bcol,
             thread float& pt,
             thread float& hexpos,
             thread float& fparam
             ) {

    float3 odir = dir;
    float3 p = from, col = float3(0.);
    float d, td = 0.;
    float3 g = float3(0.);
    float3 hpos = path(uniforms.iTime + 3.);  // Calculate hpos here
    float3 point = normalize(path(uniforms.iTime + 2.) - hpos);
    float hitbol = 0.;  // Initialize hitbol
    for (int i = 0; i < 200; i++) {
        d = de(p, uniforms, tcol, bcol, hexpos, fparam, point, hpos, hitbol);
        if (d < .001 || td > 200.)
            break;
        p += dir * d;
        td += d;
        g += .1 / (.1 + d) * hitbol * abs(normalize(point));
    }
    hexpos = hex(p.yz);
    float hp = hexpos * (1. - hitbol);
    p -= dir * .01;
    float3 n = normal(p, uniforms, tcol, bcol, hexpos, fparam, point, hpos, hitbol);
    if (d < .001) {
        col = pow(max(0., dot(-dir, n)), 2.) * float3(.6, .7, .8) * tcol * bcol;
    }
    col += float(uniforms.iFrame);
    float3 pr = pt;
    dir = reflect(dir, n);
    td = 0.;
    for (int i = 0; i < 200; i++) {
        d = de(p, uniforms, tcol, bcol, hexpos, fparam, point, hpos, hitbol);
        if (d < .001 || td > 200.)
            break;
        p += dir * d;
        td += d;
        g += .1 / (.1 + d) * abs(normalize(point));
    }
    float zz = p.z;
    if (d < .001) {
        float3 refcol = pow(max(0., dot(-odir, n)), 2.) * float3(.6, .7, .8) * tcol * bcol;
        p = pr;
        p = abs(.5 - fract(p * .1));
       float m = 100.;
       for (int i = 0; i < 10; i++) {
           p = abs(p) / dot(p, p) - .8;
           m = min(m, length(p));
       }
       col = mix(col, refcol, m) - m * .3;
       col += step(.3, hp) * step(.9, fract(pr.z * .05 + uniforms.iTime * .5 + hp * .1)) * .7;
       col += step(.3, hexpos) * step(.9, fract(zz * .05 + uniforms.iTime + hexpos * .1)) * .3;
   }
   col += g * .03;
   float2x2 rotationMatrix = rot(odir.y * .5);
   col.r = col.r * rotationMatrix[0].x + col.b * rotationMatrix[0].y;
   col.b = col.r * rotationMatrix[1].x + col.b * rotationMatrix[1].y;
   return col;
}

fragment float4 fragment_main(Vertex in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]])
{
    // Setup canvas
    
    float2 uv = in.position.xy / uniforms.iResolution.xy - 1;
    uv.x *= uniforms.iResolution.x / uniforms.iResolution.y;
    
    // setup time animation
    float t = uniforms.iTime * 2.;
    float3 from = path(t);
       
    if (fmod(uniforms.iTime - 10., 20.) > 10.) {
        from = path(floor(t / 20.) * 20. + 10.);
        from.x += 2.;
    }
    
    // parameters
    
    float3 hpos = path(t + 3.);
    float tcol = 0;
    float bcol = 0;
    float fparam = 0;
    float hexpos = 0;
    float pt = 0;

    float3 adv = path(t + 2.);
    float3 dir = normalize(float3(uv, .7));
    float3 dd = normalize(adv - from);
    float3 point = normalize(adv - hpos);
    
    // rotation
    float2x2 rotationMatrix = rot(sin(uniforms.iTime) * .2);
    point.xz = float2(
        point.x * rotationMatrix[0].x + point.z * rotationMatrix[0].y,
        point.x * rotationMatrix[1].x + point.z * rotationMatrix[1].y
    );
    
    // camera
    dir = lookat(dd) * dir;
    
    // animation
    float3 col = march(from, dir, uniforms, tcol, bcol, pt, hexpos, fparam);
    col *= float3(1., .9, .8);
    return float4(col, 1.0);
}
