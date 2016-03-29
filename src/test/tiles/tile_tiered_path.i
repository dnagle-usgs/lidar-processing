ut_section, "tile_tiered_path";

path = tile_tiered_path("t_e246_n1378_12", "it/dt short prefix");
ut_eq, path, "i_e240_n1380_12/t_e246_n1378_12";

path = tile_tiered_path("t_e246_n1378_12", save(path="-"));
ut_eq, path, string(0);

path = tile_tiered_path("t_e246_n1378_12", "dt:dt long noprefix");
ut_eq, path, "e246000_n1378000_12";

