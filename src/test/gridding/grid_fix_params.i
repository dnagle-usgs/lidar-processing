save, ut, eq_ev="vv";

ut_section, "grid_fix_params, [10,20], [30,40], 10, SW";
xmin = xmax = ymin = ymax = xcount = ycount = [];
grid_fix_params, [10,20], [30,40], 10, xmin, xmax, ymin, ymax, xcount, ycount, xsnap="w", ysnap="s";
ut_eq, xmin, 10;
ut_eq, ymin, 30;
ut_eq, xmax, 30;
ut_eq, ymax, 50;
ut_eq, xcount, 2;
ut_eq, ycount, 2;

ut_section, "grid_fix_params, [10,20], [30,40], 10, SE";
xmin = xmax = ymin = ymax = xcount = ycount = [];
grid_fix_params, [10,20], [30,40], 10, xmin, xmax, ymin, ymax, xcount, ycount, xsnap="e", ysnap="s";
ut_eq, xmin, 0;
ut_eq, ymin, 30;
ut_eq, xmax, 20;
ut_eq, ymax, 50;
ut_eq, xcount, 2;
ut_eq, ycount, 2;

ut_section, "grid_fix_params, [10,20], [30,40], 10, NW";
xmin = xmax = ymin = ymax = xcount = ycount = [];
grid_fix_params, [10,20], [30,40], 10, xmin, xmax, ymin, ymax, xcount, ycount, xsnap="w", ysnap="n";
ut_eq, xmin, 10;
ut_eq, ymin, 20;
ut_eq, xmax, 30;
ut_eq, ymax, 40;
ut_eq, xcount, 2;
ut_eq, ycount, 2;

ut_section, "grid_fix_params, [10,20], [30,40], 10, NE";
xmin = xmax = ymin = ymax = xcount = ycount = [];
grid_fix_params, [10,20], [30,40], 10, xmin, xmax, ymin, ymax, xcount, ycount, xsnap="e", ysnap="n";
ut_eq, xmin, 0;
ut_eq, ymin, 20;
ut_eq, xmax, 20;
ut_eq, ymax, 40;
ut_eq, xcount, 2;
ut_eq, ycount, 2;
