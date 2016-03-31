save, ut, eq_ev="ev";

ut_section, "_batch_retile_scan: 4 points in exactly one cell";

tile = "e124_n1370_15";
xyz = [
  [124002, 1368002, 0.],
  [124005, 1368012, 0.],
  [124003, 1368009, 0.],
  [124012, 1368022, 0.]
];
data = xyz2data(xyz, FS);
scan = _batch_retile_scan(data, tile=tile, remove_buffers=1, zone=15);
ut_eq, "scan.zone", 15;
ut_eq, "scan.coverage.xmin", 124000;
ut_eq, "scan.coverage.ymin", 1368000;
ut_eq, "scan.coverage.cell", 25;
ut_eq, "scan.coverage.nodata", 0;
ut_eq, "pr1(dimsof(*scan.coverage.zgrid))", "[2,1,1]";
ut_eq, "(*scan.coverage.zgrid)(1,1)", 4;

ut_section, "_batch_retile_scan: 1 pt in one cell, 3 pts in adjacent, same tile";

tile = "e124_n1370_15";
xyz = [
  [124032, 1368002, 0.],
  [124005, 1368012, 0.],
  [124003, 1368009, 0.],
  [124012, 1368022, 0.]
];
data = xyz2data(xyz, FS);
scan = _batch_retile_scan(data, tile=tile, remove_buffers=1, zone=15);
ut_eq, "scan.coverage.xmin", 124000;
ut_eq, "scan.coverage.ymin", 1368000;
ut_eq, "scan.coverage.cell", 25;
ut_eq, "scan.coverage.nodata", 0;
ut_eq, "pr1(dimsof(*scan.coverage.zgrid))", "[2,2,1]";
ut_eq, "(*scan.coverage.zgrid)(1,1)", 3;
ut_eq, "(*scan.coverage.zgrid)(2,1)", 1;


// Test case input: 1 point in one cell, 3 points in adjacent cell, only latter
// are in tile
ut_section, "_batch_retile_scan: 1 pt in one cell, 3 pts in adjacent, only latter in tile";

tile = "e124_n1370_15";
xyz = [
  [123992, 1368002, 0.],
  [124005, 1368012, 0.],
  [124003, 1368009, 0.],
  [124012, 1368022, 0.]
];
data = xyz2data(xyz, FS);
scan = _batch_retile_scan(data, tile=tile, remove_buffers=1, zone=15);
ut_eq, "scan.coverage.xmin", 124000;
ut_eq, "scan.coverage.ymin", 1368000;
ut_eq, "scan.coverage.cell", 25;
ut_eq, "scan.coverage.nodata", 0;
ut_eq, "pr1(dimsof(*scan.coverage.zgrid))", "[2,1,1]";
ut_eq, "(*scan.coverage.zgrid)(1,1)", 3;

ut_section, "_batch_retile_scan: border points, remove_buffers=1";

tile = "e124_n1370_15";
xyz = [
  [124000, 1369000, 0.], // west  - keep
  [125000, 1370000, 0.], // north - keep
  [125000, 1368000, 0.], // south - drop
  [126000, 1369000, 0.]  // east  - drop
];
// result should be bounded by:
//   124000, 1368975
//   125025, 1370000
data = xyz2data(xyz, FS);
scan = _batch_retile_scan(data, tile=tile, remove_buffers=1, zone=15);
ut_eq, "scan.coverage.xmin", 124000;
ut_eq, "scan.coverage.ymin", 1368975;
ut_eq, "scan.coverage.cell", 25;
ut_eq, "scan.coverage.nodata", 0;
ut_eq, "pr1(dimsof(*scan.coverage.zgrid))", "[2,41,41]";
ut_eq, "(*scan.coverage.zgrid)(*)(sum)", 2;

ut_section, "_batch_retile_scan: border points, remove_buffers=0";

tile = "e124_n1370_15";
xyz = [
  [124000, 1369000, 0.],
  [125000, 1368000, 0.],
  [125000, 1370000, 0.],
  [126000, 1369000, 0.]
];
// result should be bounded by:
//   124000, 1367975
//   126025, 1370000
data = xyz2data(xyz, FS);
scan = _batch_retile_scan(data, tile=tile, remove_buffers=0, zone=15);
ut_eq, "scan.coverage.xmin", 124000;
ut_eq, "scan.coverage.ymin", 1367975;
ut_eq, "scan.coverage.cell", 25;
ut_eq, "scan.coverage.nodata", 0;
ut_eq, "pr1(dimsof(*scan.coverage.zgrid))", "[2,81,81]";
ut_eq, "(*scan.coverage.zgrid)(*)(sum)", 4;
