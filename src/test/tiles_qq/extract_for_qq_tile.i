save, ut, eq_ev="ev";

ut_section, "extract_for_qq_tile: buffer=0";

tile = "47104h2c";
// QQ's SE corner is 47.9375N, 104.1875W
// Tiles are 1/16 degree in size: 0.0625
// Thus NW corner is 48.000N, 104.250N
// So minlon, maxlon, minlat, maxlat is: -104.25, -104.1875, 47.9375, 48
// Should include maxlon, minlat (southwest corner/sides)

// Complicated by the fact that this is in lat lon but we work in UTM. So we
// can't test exact boundaries, practically speaking.

// Thus round to nearest cm to give some tolerance.

// Center point is: -104.21875, 47.96875

// Key SW corner point: -104.1875, 47.9375
// In UTM: 558312.7390.., 5313122.2335.., zone 13
// Round down lon and round up lat
ut_eq, "extract_for_qq_tile(558312.73, 5313122.24, 13, tile, buffer=0)", 1;

// Check longitude against central latitude

// -104.25, 47.96875
// UTM 555980.2434.., 5313099.0809.. zone 13
ut_eq, "extract_for_qq_tile(555980.24, 5313099.08, 13, tile, buffer=0)", [];
ut_eq, "extract_for_qq_tile(555980.25, 5313099.08, 13, tile, buffer=0)", 1;
// -104.1875, 47.96875
// UTM 560645.2329.., 5313146.3313.., zone 13
ut_eq, "extract_for_qq_tile(560645.23, 5313146.33, 13, tile, buffer=0)", 1;
ut_eq, "extract_for_qq_tile(560645.24, 5313146.33, 13, tile, buffer=0)", [];

// Check latitude against central longitude

// -104.21875, 47.9375
// UTM 558347.9099, 5309648.9871, 13
ut_eq, "extract_for_qq_tile(558347.91, 5309648.98, 13, tile, buffer=0)", [];
ut_eq, "extract_for_qq_tile(558347.91, 5309648.99, 13, tile, buffer=0)", 1;

// -104.21875, 48
// UTM 558277.5507, 5316595.4986, 13
ut_eq, "extract_for_qq_tile(558277.55, 5316595.49, 13, tile, buffer=0)", 1;
ut_eq, "extract_for_qq_tile(558277.55, 5316595.50, 13, tile, buffer=0)", [];

ut_section, "extract_for_qq_tile: buffer=100";

// These are given more tolerance than the previous section intentionally,
// since adding a buffer to the UTM coordinates exactly does not really work
// correctly (it's close, but not exact).

// -104.25, 47.96875
// UTM 555980.2434, 5313099.0809, zone 13
// Buffer 555880.2434, 5313099.0809, zone 13
ut_eq, "extract_for_qq_tile(555880.2, 5313099.1, 13, tile, buffer=100)", [];
ut_eq, "extract_for_qq_tile(555880.3, 5313099.1, 13, tile, buffer=100)", 1;
// -104.1875, 47.96875
// UTM 560645.2329, 5313146.3313, zone 13
// Buffer 560745.2329, 5313146.3313
ut_eq, "extract_for_qq_tile(560745.2, 5313146.3, 13, tile, buffer=100)", 1;
ut_eq, "extract_for_qq_tile(560745.3, 5313146.3, 13, tile, buffer=100)", [];

// Check latitude against central longitude

// -104.21875, 47.9375
// UTM 558347.9099, 5309648.9871, 13
// Buffer 558347.9099, 5309548.9871, 13
ut_eq, "extract_for_qq_tile(558347.9, 5309548.9, 13, tile, buffer=100)", [];
ut_eq, "extract_for_qq_tile(558347.9, 5309549.0, 13, tile, buffer=100)", 1;

// -104.21875, 48
// UTM 558277.5507, 5316595.4986, 13
// Buffer 558277.5507, 5316695.4986, 13
ut_eq, "extract_for_qq_tile(558277.6, 5316695.4, 13, tile, buffer=100)", 1;
ut_eq, "extract_for_qq_tile(558277.6, 5316695.51, 13, tile, buffer=100)", [];
