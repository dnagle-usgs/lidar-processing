
// test very basic stuff on a variety of structs
ut_section, "depth_correct structs";

data = array(GEO, 5);
data.depth = indgen(0:-400:-100);
depth_correct, data, 0, -1, verbose=0;
ut_ok, "allof(data.depth == -100)";
ut_ok, "noneof(data.elevation)";
ut_ok, "noneof(data.north)";
ut_ok, "noneof(data.east)";

data = array(GEO, 5);
data.depth = indgen(0:-400:-100);
depth_correct, data, 1, 0.01, verbose=0;
ut_ok, "allof(data.depth == [0, -99, -199, -299, -399])";
ut_ok, "noneof(data.elevation)";
ut_ok, "noneof(data.north)";
ut_ok, "noneof(data.east)";

data = array(VEG__, 5);
data.elevation = indgen(0:4);
data.lelv = 0;
depth_correct, data, 0, 1, verbose=0;
ut_ok, "allof(data.elevation == indgen(0:4))";
ut_ok, "allof(data.lelv == indgen(0:4))";
ut_ok, "noneof(data.north)";
ut_ok, "noneof(data.east)";
ut_ok, "noneof(data.lnorth)";
ut_ok, "noneof(data.least)";

data = array(VEG__, 5);
data.elevation = indgen(0:4);
data.lelv = 0;
depth_correct, data, 1, -1, verbose=0;
ut_ok, "allof(data.elevation == indgen(0:4))";
ut_ok, "allof(data.lelv == -100)";
ut_ok, "noneof(data.north)";
ut_ok, "noneof(data.east)";
ut_ok, "noneof(data.lnorth)";
ut_ok, "noneof(data.least)";

// test some more complicated math
ut_section, "depth_correct math";

data = array(GEO, 5);
data.depth = -100 * indgen(0:4);
depth_correct, data, 2.5, -0.005, verbose=0;
ut_ok, "allof(data.depth == -250 * indgen(0:4))";

data.depth = -100 * [5,10,15,20,25];
depth_correct, data, 2.98, -0.005, verbose=0;
ut_ok, "allof(data.depth == [-1490,-2980,-4470,-5960,-7450])";
