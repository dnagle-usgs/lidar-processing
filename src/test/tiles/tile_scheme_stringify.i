save, ut, eq_ev="ev";
ut_section, "tile_scheme_stringify";

scheme = tile_scheme(tile_scheme_stringify("dt short noprefix"));
ut_eq, "scheme.type", "dt";
ut_eq, "scheme.path", "dt";
ut_eq, "scheme.dtprefix", 0;
ut_eq, "scheme.dtlength", "short";

// We probably won't ever want to mix qq and it but it serves as a worthwhile test
scheme = tile_scheme(tile_scheme_stringify(save(type="it", path="qq",
  qqprefix=0, dtprefix=1, dtlength="long")));
ut_eq, "scheme.type", "it";
ut_eq, "scheme.path", "qq";
ut_eq, "scheme.dtprefix", 1;
ut_eq, "scheme.qqprefix", 0;
ut_eq, "scheme.dtlength", "long";
