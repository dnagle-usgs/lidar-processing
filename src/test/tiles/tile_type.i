ut_section, "tile_type";

ut_eq, "tile_type(\"t_e240_n2280_16\")", "dt", "ev";
ut_eq, "tile_type(\"t_e240000_n2280000_16\")", "dt", "ev";
ut_eq, "tile_type(\"e240_n2280_16\")", "dt", "ev";
ut_eq, "tile_type(\"e240000_n2280000_16\")", "dt", "ev";

ut_eq, "tile_type(\"i_e240_n2280_16\")", "it", "ev";
ut_eq, "tile_type(\"i_e240000_n2280000_16\")", "it", "ev";

ut_eq, "tile_type(\"47104h2c\")", "qq", "ev";
ut_eq, "tile_type(\"qq47104h2c\")", "qq", "ev";

ut_eq, "tile_type(\"abcde\")", string(0), "ev";
