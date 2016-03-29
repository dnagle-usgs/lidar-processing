ut_section, "tile_scheme_stringify";

scheme = tile_scheme(tile_scheme_stringify("dt short noprefix"));
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "dt", "ev";
ut_eq, "scheme.dtprefix", 0, "ev";
ut_eq, "scheme.dtlength", "short", "ev";

// We probably won't ever want to mix qq and it but it serves as a worthwhile test
scheme = tile_scheme(tile_scheme_stringify(save(type="it", path="qq",
  qqprefix=0, dtprefix=1, dtlength="long")));
ut_eq, "scheme.type", "it", "ev";
ut_eq, "scheme.path", "qq", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.qqprefix", 0, "ev";
ut_eq, "scheme.dtlength", "long", "ev";
