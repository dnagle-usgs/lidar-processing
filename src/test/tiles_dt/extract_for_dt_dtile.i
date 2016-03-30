ut_section, "extract_for_dt_tile: dt";

tile = "e124_n2346_15";

ut_eq, "extract_for_dt_tile(124000, 2346000, 15, tile, buffer=0)", 1, "ev";

ut_eq, "extract_for_dt_tile(123999.99, 2345000, 15, tile, buffer=0)", [], "ev";
ut_eq, "extract_for_dt_tile(124000, 2345000, 15, tile, buffer=0)", 1, "ev";
ut_eq, "extract_for_dt_tile(125999.99, 2345000, 15, tile, buffer=0)", 1, "ev";
ut_eq, "extract_for_dt_tile(126000, 2345000, 15, tile, buffer=0)", [], "ev";

ut_eq, "extract_for_dt_tile(125000, 2344000, 15, tile, buffer=0)", [], "ev";
ut_eq, "extract_for_dt_tile(125000, 2344000.01, 15, tile, buffer=0)", 1, "ev";
ut_eq, "extract_for_dt_tile(125000, 2346000, 15, tile, buffer=0)", 1, "ev";
ut_eq, "extract_for_dt_tile(125000, 2346000.01, 15, tile, buffer=0)", [], "ev";

ut_eq, "extract_for_dt_tile(125000, 2345000, 14, tile, buffer=0)", [], "ev";
ut_eq, "extract_for_dt_tile(125000, 2345000, 16, tile, buffer=0)", [], "ev";

ut_section, "extract_for_dt_tile: it";

tile = "i_e120_n2340_15";

ut_eq, "extract_for_dt_tile(120000, 2340000, 15, tile, buffer=0)", 1, "ev";

ut_eq, "extract_for_dt_tile(119999.99, 2335000, 15, tile, buffer=0)", [], "ev";
ut_eq, "extract_for_dt_tile(120000, 2335000, 15, tile, buffer=0)", 1, "ev";
ut_eq, "extract_for_dt_tile(129999.99, 2335000, 15, tile, buffer=0)", 1, "ev";
ut_eq, "extract_for_dt_tile(130000, 2335000, 15, tile, buffer=0)", [], "ev";

ut_eq, "extract_for_dt_tile(125000, 2330000, 15, tile, buffer=0)", [], "ev";
ut_eq, "extract_for_dt_tile(125000, 2330000.01, 15, tile, buffer=0)", 1, "ev";
ut_eq, "extract_for_dt_tile(125000, 2340000, 15, tile, buffer=0)", 1, "ev";
ut_eq, "extract_for_dt_tile(125000, 2340000.01, 15, tile, buffer=0)", [], "ev";

ut_eq, "extract_for_dt_tile(125000, 2335000, 14, tile, buffer=0)", [], "ev";
ut_eq, "extract_for_dt_tile(125000, 2335000, 16, tile, buffer=0)", [], "ev";

ut_section, "extract_for_dt_tile: buffer";

tile = "e124_n2346_15";

ut_eq, "extract_for_dt_tile(123899.99, 2345000, 15, tile, buffer=100)", [], "ev";
ut_eq, "extract_for_dt_tile(123900, 2345000, 15, tile, buffer=100)", 1, "ev";
ut_eq, "extract_for_dt_tile(126099.99, 2345000, 15, tile, buffer=100)", 1, "ev";
ut_eq, "extract_for_dt_tile(126100, 2345000, 15, tile, buffer=100)", [], "ev";

ut_eq, "extract_for_dt_tile(125000, 2343900, 15, tile, buffer=100)", [], "ev";
ut_eq, "extract_for_dt_tile(125000, 2343900.01, 15, tile, buffer=100)", 1, "ev";
ut_eq, "extract_for_dt_tile(125000, 2346100, 15, tile, buffer=100)", 1, "ev";
ut_eq, "extract_for_dt_tile(125000, 2346100.01, 15, tile, buffer=100)", [], "ev";
