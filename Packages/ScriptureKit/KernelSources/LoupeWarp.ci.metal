// The loupe's bend (LoupeLens.bend(at:)), as a Core Image warp kernel in Metal.
// Built into ScriptureUI/Kernels/LoupeWarp-<platform>.metallib by Scripts/build-kernels.sh;
// the libraries are checked in, since `swift build` cannot pass Core Image's kernel flags.
#include <CoreImage/CoreImage.h>

extern "C" { namespace coreimage {

/// Each place in the lens looks outward along the line from the centre by `reach` radii times
/// the bend: nothing inside `inner` of the radius, then rising with no step in it or its slope
/// to all of it at the rim.
float2 glassRim(float2 centre, float radius, float inner, float reach, destination dest) {
    float2 d = dest.coord() - centre;
    float r = length(d) / radius;
    float t = clamp((r - inner) / (1.0 - inner), 0.0, 1.0);
    float bend = t * t * t * (3.0 - 2.0 * t);
    return dest.coord() + d * (reach * bend / max(r, 0.0001));
}

}}
