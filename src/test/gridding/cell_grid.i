ut_section, "cell_grid, method=counts, xsnap=w, ysnap=s";

// 0, .25, .5, ..., 1.75, 2
x = indgen(0:8)/4.;

g = cell_grid(x, x, x, cell=1, method="counts", xsnap="w", ysnap="s");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,2,2]", "ev";
//[[4,0], 4
// [0,4]  4
//  4 4
ut_eq, "pr1(short(*g.zgrid))", "[[4,0],[0,4]]", "ev";

// .5, .75, 1, ..., 2.25, 2.5
x = indgen(0:8)/4.+.5;

g = cell_grid(x, x, x, cell=1, method="counts", xsnap="w", ysnap="s");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,3,3]", "ev";
// 2x 0,0; 4x 1,1; 3x 2,2
//[[2,0,0],  2
// [0,4,0],  4
// [0,0,3]]  3
//  2 4 3
ut_eq, "pr1(short(*g.zgrid))", "[[2,0,0],[0,4,0],[0,0,3]]", "ev";

// 2.5, ..., .5
y = x(::-1);

g = cell_grid(x, y, x, cell=1, method="counts", xsnap="w", ysnap="s");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,3,3]", "ev";
// 2x 0,2; 1x 1,2; 3x 1,1; 1x 2,1; 2x 2,0
//[[0,0,2],  2
// [0,3,1],  4
// [2,1,0]]  3
//  2 4 3
ut_eq, "pr1(short(*g.zgrid))", "[[0,0,2],[0,3,1],[2,1,0]]", "ev";

g = cell_grid(y, x, x, cell=1, method="counts", xsnap="w", ysnap="s");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,3,3]", "ev";
// 2x 2,0; 1x 2,1; 3x 1,1; 1x 1,2; 2x 0,2
//[[0,0,2],  2
// [0,3,1],  4
// [2,1,0]]  3
//  2 4 3
ut_eq, "pr1(short(*g.zgrid))", "[[0,0,2],[0,3,1],[2,1,0]]", "ev";

// =============================================================================
ut_section, "cell_grid, method=counts, xsnap=e, ysnap=n";

// 0, .25, .5, ..., 1.75, 2
x = indgen(0:8)/4.;

g = cell_grid(x, x, x, cell=1, method="counts", xsnap="w", ysnap="s");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,2,2]", "ev";
//[[4,0], 4
// [0,4]  4
//  4 4
ut_eq, "pr1(short(*g.zgrid))", "[[4,0],[0,4]]", "ev";

// .5, .75, 1, ..., 2.25, 2.5
x = indgen(0:8)/4.+.5;

g = cell_grid(x, x, x, cell=1, method="counts", xsnap="e", ysnap="n");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
// 2x 0,0; 4x 1,1; 3x 2,2
//[[3,0,0],  3
// [0,4,0],  4
// [0,0,2]]  2
//  3 4 2
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,3,3]", "ev";
ut_eq, "pr1(short(*g.zgrid))", "[[3,0,0],[0,4,0],[0,0,2]]", "ev";

// =============================================================================
ut_section, "cell_grid, method=counts, xsnap=e, ysnap=s";

// 0, .25, .5, ..., 1.75, 2
x = indgen(0:8)/4.;

g = cell_grid(x, x, x, cell=1, method="counts", xsnap="e", ysnap="s");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,2,2]", "ev";
// 3x 0,0; 1x 0,1; 3x 1,1
//[[3,0]  3
// [1,3]] 4
//  4 3
ut_eq, "pr1(short(*g.zgrid))", "[[3,0],[1,3]]", "ev";

// .5, .75, 1, ..., 2.25, 2.5
x = indgen(0:8)/4.+.5;

g = cell_grid(x, x, x, cell=1, method="counts", xsnap="e", ysnap="s");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
// 2x 0,0; 1x 0,1; 3x 1,1; 1x 1,2; 2x 2,2
//[[2,0,0],  3
// [1,3,0],  4
// [0,1,2]]  2
//  2 4 3
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,3,3]", "ev";
ut_eq, "pr1(short(*g.zgrid))", "[[2,0,0],[1,3,0],[0,1,2]]", "ev";

// =============================================================================
ut_section, "cell_grid, method=counts, xsnap=w, ysnap=n";

// 0, .25, .5, ..., 1.75, 2
x = indgen(0:8)/4.;

g = cell_grid(x, x, x, cell=1, method="counts", xsnap="w", ysnap="n");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,2,2]", "ev";
// 3x 0,0; 1x 1,0; 3x 1,1
//[[3,1]  4
// [0,3]] 3
/// 3 4
ut_eq, "pr1(short(*g.zgrid))", "[[3,1],[0,3]]", "ev";

// .5, .75, 1, ..., 2.25, 2.5
x = indgen(0:8)/4.+.5;

g = cell_grid(x, x, x, cell=1, method="counts", xsnap="w", ysnap="n");
ut_eq, "g.xmin", 0, "ev";
ut_eq, "g.ymin", 0, "ev";
ut_eq, "g.cell", 1, "ev";
ut_eq, "g.nodata", 0, "ev";
// 2x 0,0; 1x 1,0; 3x 1,1; 1x 2,1; 2x 2,2
//[[2,1,0],  3
// [0,3,1],  4
// [0,0,2]]  2
//  2 4 3
ut_eq, "pr1(dimsof(*g.zgrid))", "[2,3,3]", "ev";
ut_eq, "pr1(short(*g.zgrid))", "[[2,1,0],[0,3,1],[0,0,2]]", "ev";

