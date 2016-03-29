dtkeys = ["type", "path", "dtlength", "dtprefix"];
qqkeys = ["type", "path", "qqprefix"];

ut_section, "tile_scheme: text parsing";

scheme = tile_scheme("dt");
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "dt", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.dtlength", "long", "ev";

scheme = tile_scheme("it");
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "it", "ev";
ut_eq, "scheme.path", "it", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.dtlength", "long", "ev";

scheme = tile_scheme("it/dt prefix short");
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "it/dt", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.dtlength", "short", "ev";

scheme = tile_scheme("dt:it/dt noprefix long");
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "it/dt", "ev";
ut_eq, "scheme.dtprefix", 0, "ev";
ut_eq, "scheme.dtlength", "long", "ev";

scheme = tile_scheme("dt:it prefix=1 length=long");
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "it", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.dtlength", "long", "ev";

// We probably wouldn't actually want to do it/dt/dt but it serves as a variety
// for a test case
scheme = tile_scheme("it/dt/dt prefix=0 length=short");
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "it/dt/dt", "ev";
ut_eq, "scheme.dtprefix", 0, "ev";
ut_eq, "scheme.dtlength", "short", "ev";

scheme = tile_scheme("qq");
ut_ok, "allof(scheme(*,qqkeys))";
ut_eq, "scheme.type", "qq", "ev";
ut_eq, "scheme.path", "qq", "ev";
ut_eq, "scheme.qqprefix", 0, "ev";

scheme = tile_scheme("qq prefix");
ut_ok, "allof(scheme(*,qqkeys))";
ut_eq, "scheme.type", "qq", "ev";
ut_eq, "scheme.path", "qq", "ev";
ut_eq, "scheme.qqprefix", 1, "ev";

ut_section, "tile_scheme: object handling";

scheme = tile_scheme(save(type="dt"));
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "dt", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.dtlength", "long", "ev";

scheme = tile_scheme(save(type="it"));
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "it", "ev";
ut_eq, "scheme.path", "it", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.dtlength", "long", "ev";

scheme = tile_scheme(save(type="it/dt", prefix=1, length="short"));
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "it/dt", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.dtlength", "short", "ev";

scheme = tile_scheme(save(type="dt", path="it/dt", prefix=0, length="long"));
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "it/dt", "ev";
ut_eq, "scheme.dtprefix", 0, "ev";
ut_eq, "scheme.dtlength", "long", "ev";

scheme = tile_scheme(save(type="dt", path="it", dtprefix=1, dtlength="long"));
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "it", "ev";
ut_eq, "scheme.dtprefix", 1, "ev";
ut_eq, "scheme.dtlength", "long", "ev";

// We probably wouldn't actually want to do it/dt/dt but it serves as a variety
// for a test case
scheme = tile_scheme(save(type="dt", path="it/dt/dt", prefix=0, length="short"));
ut_ok, "allof(scheme(*,dtkeys))";
ut_eq, "scheme.type", "dt", "ev";
ut_eq, "scheme.path", "it/dt/dt", "ev";
ut_eq, "scheme.dtprefix", 0, "ev";
ut_eq, "scheme.dtlength", "short", "ev";

scheme = tile_scheme(save(type="qq"));
ut_ok, "allof(scheme(*,qqkeys))";
ut_eq, "scheme.type", "qq", "ev";
ut_eq, "scheme.path", "qq", "ev";
ut_eq, "scheme.qqprefix", 0, "ev";

scheme = tile_scheme(save(type="qq", prefix=1));
ut_ok, "allof(scheme(*,qqkeys))";
ut_eq, "scheme.type", "qq", "ev";
ut_eq, "scheme.path", "qq", "ev";
ut_eq, "scheme.qqprefix", 1, "ev";

scheme = tile_scheme(save(type="qq", prefix=0));
ut_ok, "allof(scheme(*,qqkeys))";
ut_eq, "scheme.type", "qq", "ev";
ut_eq, "scheme.path", "qq", "ev";
ut_eq, "scheme.qqprefix", 0, "ev";

scheme = tile_scheme(save(type="qq", qqprefix=1));
ut_ok, "allof(scheme(*,qqkeys))";
ut_eq, "scheme.type", "qq", "ev";
ut_eq, "scheme.path", "qq", "ev";
ut_eq, "scheme.qqprefix", 1, "ev";

ut_section, "tile_scheme: precedence";

scheme = tile_scheme("dt", opts=save(type="qq"));
ut_eq, "scheme.type", "qq", "ev";

scheme = tile_scheme("dt", defaults=save(type="qq"));
ut_eq, "scheme.type", "dt", "ev";

scheme = tile_scheme(save(type="dt", length="short", dtlength="long"));
ut_eq, "scheme.dtlength", "long", "ev";

scheme = tile_scheme(save(type="dt", length="long", dtlength="short"));
ut_eq, "scheme.dtlength", "short", "ev";

scheme = tile_scheme(save(type="dt", prefix=1, dtprefix=0));
ut_eq, "scheme.dtprefix", 0, "ev";

scheme = tile_scheme(save(type="dt", prefix=0, dtprefix=1));
ut_eq, "scheme.dtprefix", 1, "ev";

scheme = tile_scheme(save(type="qq", prefix=1, qqprefix=0));
ut_eq, "scheme.qqprefix", 0, "ev";

scheme = tile_scheme(save(type="qq", prefix=0, qqprefix=1));
ut_eq, "scheme.qqprefix", 1, "ev";

ut_section, "tile_scheme: opts";

scheme = tile_scheme("dt dtlength=short dtprefix=0",
  opts=save(dtlength=[], dtprefix=[]));
ut_eq, "scheme.dtlength", "short", "ev";
ut_eq, "scheme.dtprefix", 0, "ev";
