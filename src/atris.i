/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
/*
  Place to collect all yorick .i files that atris needs.
*/

write,"$Id$"

// Transmit somd time to sf_a
if ( is_void( last_somd) )
	last_somd = 0;

func send_sod_to_sf( somd ) {
	extern last_somd
	tkcmd, swrite(format="send_sod_to_sf %d", somd);
	last_somd = somd;
}

