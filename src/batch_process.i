func batch_process(typ, cmdfile, n, onlyplot=) {
  /* this function may be used to batch process several regions for a given data set. */
  /* amar nayegandhi (10/04/02)*/

  path = array(string, n);
  min_e = array(float, n);
  max_e = array(float,n);
  min_n = array(float, n);
  max_n = array(float, n);
  // open cmdfile
  f = open(cmdfile, "r");
  read, f, format="%s %f %f %f %f", path, min_e, max_e, min_n, max_n;
  close, f;

   pldj, min_e, min_n, min_e, max_n, color="green"
   pldj, min_e, min_n, max_e, min_n, color="green"
   pldj, max_e, min_n, max_e, max_n, color="green"
   pldj, max_e, max_n, min_e, max_n, color="green"
   if (onlyplot == 1) return

  for (i=1;i<=n;i++) {
     write, format = "Selecting Region %d of %d\n",i,n;
     q = gga_win_sel(2, win=6, llarr=[min_e(i), max_e(i), min_n(i), max_n(i)]);
     if (is_array(q)) {
      write, format = "Processing Region %d of %d\n",i,n;
      depth_all = make_bathy(latutm = 1, q = q, ext_bad_depth=1, ext_bad_att=1);
      ofn = split_path(path(i),0);
      write, format = "Writing Region %d of %d\n",i,n;
      write_bathy, ofn(1), ofn(2), depth_all;
     } else {
      write, "No Flightlines found in this block."
     }
  }


}
  
  

