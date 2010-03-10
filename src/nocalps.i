local nocalps;
local nocalps_i;
/* DOCUMENT nocalps.i
   Sourcing this file will disable all C-ALPS functionality. For functionality
   that is implemented in both Yorick and C, the ALPS will fall back on the
   Yorick implementation. Functionality implemented only in C will be
   unavailable.

   This is only needed under a specific scenario. Yorick cannot dynamically
   update itself if a new version of the C-ALPS plugin is installed into Yorick
   while you have an ALPS session open. If this happens, all calls to C-ALPS
   functionality are likely to result in segmentation violations. Your best
   option in this scenario is to restart your ALPS session. However, if that is
   not immediately viable, you can source this file to avoid using C-ALPS
   functionality.
*/

calps_compatibility = [];
_ytriangulate = [];
triangulate = [];
_ydet = [];
_yplanar_params_from_pts = [];
_ycross_product_sign = [];
_yin_triangle = [];
_ytriangle_interp = [];
_ywrite_arc_grid = [];
_yin_box = [];
_ylevel_short_dips = [];
_yll2utm = [];
_yutm2ll = [];
calps_n88_interp_qfit2d = [];
calps_n88_interp_spline2d = [];
