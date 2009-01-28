/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */

require, "eaarl.i";
write, "$Id$";
/*
   Original: Amar Nayegandhi
   mbatch_process: Richard Mitchell
*/


func package_tile (q=, r=, typ=, min_e=, max_e=, min_n=, max_n= ) {

   path = swrite(format="/tmp/batch/jobs/job-t_e%6.0f_n%7.0f_%s.cmd", min_e, max_n, zone_s);
   save_vars(path, tile=1);
}

func save_vars (filename, tile=) {
   myi   = strchr( filename, '/', last=1);  // get filename only
   pt  = strpart( filename, 1:myi);
   fn  = strpart( filename, myi+1:0 );
   tfn = swrite(format="%s.%s", pt, fn);
   cmd = swrite(format="mv %s %s", tfn, filename);
   f = createb( tfn );
   if ( ! get_typ ) get_typ = 0;
   if ( tile == 1 ) {
      // info, get_typ;
      // info, auto;
      // save_dir;
      // zone_s;

      save,  f, user_pc_NAME;
      save,  f, q, r, min_e, max_e, min_n, max_n;
      save,  f, get_typ, typ, auto;
      save,  f, save_dir;
      save,  f, zone_s;
      save,  f, dat_tag, mdate;
      save,  f, iidx_path, indx_path, bool_arr, mtdt_path, mtdt_file;
      save,  f, i, n;
      save,  f, pbd;
      save,  f, update;
      // XYZZY - we need to save the batch_rcf parameters too!!
      if ( b_rcf == 1 ) {
         save,  f, b_rcf, buf, w, no_rcf, mode, merge, clean, rcfmode, write_merge;
      }
   }
   save,  f, pnav_filename;
   save,  f, tans, pnav, edb, edb_files;
   save,  f, data_path;
   save,  f, soe_day_start, eaarl_time_offset;
   save,  f, ops_conf;
   save,  f, curzone;
   close, f;
   // This makes sure the file is completely written before batcher.tcl has a chance
   // to grab it.
   system, cmd;
   return;
}

func get_tld_names( q ) {
   myrar = sel_region(q);
   // next line is an attempt to avoid problem seen when sel_region
   // returned [0,0] as first array value
   myrar = myrar(where(myrar>0));            // remove 0 indexes
   myedb = edb(myrar).file_number;           // get list of file numbers for region
   myedb = myedb(unique(myedb));             // get unique file numbers

   return ( edb_files(myedb).name );        // return list of names
 }

func unpackage_tile (fn=,host= ) {
   extern gga;
   if ( is_void(host) ) host="localhost"
   write, format="Unpackage_tile: %s %s\n", fn, host;
   f = openb(fn);
   restore, f;
   close, f;
   gga = pnav;
   write, format="Checking %s\n", host;
   if ( ! strmatch(host, "localhost") ) {
      afn  = swrite(format="%s.files", fn);
      af = open(afn, "w");
      write, af, format="%s\n", data_path;

     // Get list of edb_files just for this tile
     mytld = get_tld_names(q);
     for(myi=1; myi<=numberof(mytld); ++myi) {
         write, af, format="%s\n", mytld(myi);
     }
     // for(myi=1; myi<=numberof(myedb); ++myi) {
     //     write, af, format="%s\n", edb_files(myedb(myi)).name;
     // }

      close,af;
      cmd = swrite(format="/opt/eaarl/lidar-processing/src/check_for_tlds.pl %s %s", afn, host);
      write, cmd;
      system, cmd;
      write, format="Unpackage_Tile(%s): %s: done\n", host, cmd;
   }
   write, format="Unpackage_Tile(%s): %s: done\n", host, fn;
}

// An easier hook for someone restoring a previous session.
func load_vars(fn) {
  unpackage_tile, fn=fn  // this avoids returning an array to the cmdline
}

func call_process_tile( junk=, host= ) {
   // write, format="t_e%6.0f_n%7.0f_%s\n", min_e, max_n, zone_s;
   uber_process_tile,q=q, r=r, typ=typ, min_e=min_e, max_e=max_e, min_n=min_n, max_n=max_n, host=host;
}


func uber_process_tile (q=, r=, typ=, min_e=, max_e=, min_n=, max_n=, host= ) {
   extern ofn;
   if (is_array(r)) {

      // proceess_tile will return a 0 if the tile needs to be updated
      update = process_tile (q=q, r=r, typ=typ, min_e=min_e, max_e=max_e, min_n=min_n, max_n=max_n, update=update, host=host );

      mypath = ofn(1);
      if ( b_rcf ) {
         write, format="RCF Processing for %s\n", mypath;
         if ( ! strmatch(host, "localhost") ) {
            // Here we do need to make sure that we have all of the files
            // so they can be processed together.
            // XYZZY - This will result in errors from rsync when the
            // files don't exist on the server (probably most of the time)
            write, format="RCF: rsyncing %s:%s\n", host, mypath;
            cmd = swrite(format="rsync -PHaqR %s:%s /", host, mypath);
            write,  cmd;
            system, cmd;
            write, "rsync complete";
         }
         batch_rcf( mypath, buf=buf, w=w, no_rcf=no_rcf, mode=mode, merge=merge, clean=clean, rcfmode=rcfmode, onlyupdate=update, write_merge=write_merge );
      }

      if ( ! strmatch(host, "localhost") ) {
         write, format="FINISH: rsyncing %s to %s\n", mypath, host;
         cmd = swrite(format="rsync -PHaqR %s %s:/", mypath, host);
         write, cmd;
         system, cmd;
         write, "rsync complete";
      }

   } else {
      write, "No Flightlines found in this block."
   }
}

func process_tile (q=, r=, typ=, min_e=, max_e=, min_n=, max_n=, host=,update= ) {
   extern ofn;
   if ( is_void(host) ) host="localhost";
   // if (is_array(r)) {      // XYZZY - we don't need this check anymore - 2009-01-12, rwm
      if (get_typ) {
         typ=[]
         typ_idx = where(tile.min_e == min_e);
         if (is_array(typ_idx)) typ_idx2 = where(tile.max_n(typ_idx) == max_n);
         if (is_array(typ_idx2)) typ = [tile.typ(typ_idx(typ_idx2))](1);
         if (!typ) typ = typer(min_e, max_e, min_n, max_n, zone);
      }
      if (auto) {
         idx_e = long(10000 * long(min_e / 10000));
         idx_n = long(10000 * long(1+(max_n / 10000)));
         if ((max_n % 10000) == 0) idx_n = long(max_n);
         ofn = array(string, 2);
         ofn(1) = swrite(format="%si_e%d_n%d_%s/t_e%6.0f_n%7.0f_%s/",
            save_dir,
            idx_e, idx_n, zone_s,
            min_e, max_n, zone_s);
         ofn(2) = swrite(format="t_e%6.0f_n%7.0f_%s_%s_%s",
            min_e, max_n, zone_s,
            dat_tag, mdate);
         if (edf) ofn(2) = ofn(2) + ".edf";
         if (pbd) ofn(2) = ofn(2) + ".pbd";
         pofn = ofn(1) + ofn(2);


         // if update = 1, check to see if file exists
         if (update) {

            // Get files from server
            if ( ! strmatch(host, "localhost") ) {
               write, format="rsyncing %s:%s\n", host, ofn(1);
               cmd = swrite(format="rsync -PHaqR %s:%s /", host, ofn(1));
               write, cmd;
               system, cmd;
               write, "rsyncing finished";
            }

            if (typ == 0)
               new_file = split_path(pofn,0,ext=1)(1)+"_f.pbd";
            if (typ == 1)
               new_file = split_path(pofn,0,ext=1)(1)+"_b.pbd";
            if (typ == 2)
               new_file = split_path(pofn,0,ext=1)(1)+"_v.pbd";

            //does not work for typ=3
            new_file = [split_path(new_file, 0)](0); // only file name (removed path);
            scmd = swrite(format = "find %s -name '%s'",save_dir, new_file);
            nf = 0;
            s = array(string, 1);
            f=popen(scmd(1), 0);
            nf = read(f,format="%s", s );
            close, f;
            if (nf) {
               write, format="File %s already exists...\n", new_file;
               // continue; // RWM
               return update;
            }
            update=0;  // if the tile was updated, force rcf to process.
         }

         // if ( udpate ) {}
         mkdir, swrite(format="%si_e%d_n%d_%s", save_dir, idx_e, idx_n, zone_s);
         mkdir, swrite(format="%si_e%d_n%d_%s/t_e%6.0f_n%7.0f_%s", save_dir, idx_e, idx_n, zone_s, min_e, max_n, zone_s);
         indx_num = where(mtdt_path == swrite(format="%si_e%d_n%d_%s/", save_dir, idx_e, idx_n, zone_s));
         indx_number = indx_num(1);
         if (bool_arr(indx_number) != 1) {
            f = open(mtdt_file(indx_number),"a");
            bool_arr(indx_number) = 1
            write, f, "Batch Processing Begins"
            write, f, timestamp();
            write, f, format="   on %s by %s\n\n",user_pc_NAME(1),user_pc_NAME(2);
            if (!is_array(conf_file_lines)) write, f, format="PNAV FILE: %s\n",pnav_filename;
            if (typ == 1) {
               write, f, "Bathymetry Constants: "
               write, f, format="Laser: %f\n",bath_ctl.laser;
               write, f, format="Water: %f\n",bath_ctl.water;
               write, f, format="AGC  : %f\n",bath_ctl.agc;
               write, f, format="Threshold: %f\n",bath_ctl.thresh;
               write, f, format="Last : %d\n",bath_ctl.last;
            }
            if (is_array(conf_file_lines)) {
               write, f, "Conf File settings\n";
               write, f, format="    from file: %s\n",conf_file;
               write, f, format="EDB FILE:      %s\n",conf_file_lines(1);
               write, f, format="PNAV FILE:     %s\n",conf_file_lines(2);
               write, f, format="IMU FILE:      %s\n",conf_file_lines(3);
               write, f, format="OPS_CONF FILE: %s\n",conf_file_lines(6);
            }
            write, f, "\nops_conf constants: ";
            write, f, format="y_offset: %f\n",ops_conf.y_offset;
            write, f, format="x_offset: %f\n",ops_conf.x_offset;
            write, f, format="z_offset: %f\n",ops_conf.z_offset;
            write, f, format="roll_bias: %f\n",ops_conf.roll_bias;
            write, f, format="pitch_bias: %f\n",ops_conf.pitch_bias;
            write, f, format="yaw_bias: %f\n",ops_conf.yaw_bias;
            write, f, format="scan_bias: %f\n",ops_conf.scan_bias;
            write, f, format="range_biasM: %f\n",ops_conf.range_biasM;

            close, f;
         }
      }
      // write metadata
      for (ij = 1; ij <=numberof(iidx_path); ij++) {

         // if you get an error here, it is most likely because you decided to use 'i'
         // elsewhere.
         write, format="RWM: IJ(%d): %d / %d: %s\n", i, ij, numberof(iidx_path), indx_path(i);
         if (mtdt_path(ij) == indx_path(i)) {
            f = open(mtdt_file(ij), "a");
            if (cmdfile) write, f, format="Processed Data Tile %9.2f %9.2f %9.2f %9.2f\n",min_e, max_e, min_n, max_n;
            if (auto) {
               if (typ == 0) typtag="First Surface";
               if (typ == 1) typtag="Bathy";
               if (typ == 2) typtag="Veg";
               if (typ == 3) typtag="Bathy and Veg";
               write, f, format="Processed Data Tile %9.2f %9.2f %9.2f %9.2f for %s\n",min_e, max_e, min_n, max_n, typtag;
            }
            close, f;
         }
      }

      if (typ == 0) {
         write, format = "Processing Region %d of %d for First Surface Only\n",i,n;
         fs_all = make_fs(latutm = 1, q = q,  ext_bad_att=1, use_centroid=1);
         if (is_array(fs_all)) {
            fs_all = clean_fs(fs_all);
            if (is_array(fs_all)) {
               if (edf) {
                  write, format = "Writing edf file for Region %d of %d\n",i,n;

                  write_topo, ofn(1), split_path(ofn(2),0,ext=1)(1)+"_f.edf", fs_all;
               }
               if (pbd) {
                  new_ofn = split_path(ofn(2),0,ext=1);
                  t = *pointer(new_ofn(1));
                  nn = where(t == '_');
                  date = string(&t(nn(0)+1:));
                  vname = "fst_"+date+"_"+swrite(format="%d",i);
                  write, format = "Writing pbd file for Region %d of %d\n",i,n;
                  f = createb(split_path(pofn,0,ext=1)(1)+"_f.pbd");
                  add_variable, f, -1, vname, structof(fs_all), dimsof(fs_all);
                  get_member(f, vname) = fs_all;
                  save, f, vname;
                  close, f;
               }
            }
         }

      }
      if (typ == 1) {
         if ((get_typ && !only_veg) || (!get_typ)) {
            write, format = "Processing Region %d of %d for Bathymetry\n",i,n;
            depth_all = make_bathy(latutm = 1, q = q,avg_surf=avg_surf);
            if (is_array(depth_all)){
               depth_all = clean_bathy(depth_all);
               if (is_array(depth_all)) {
                  numstart=numberof(depth_all)
                  if ((min(depth_all.east) < (min_e-400)*100) || (max(depth_all.east) > (max_e+400)*100) || (min(depth_all.north) < (min_n-400)*100) || (max(depth_all.north) > (max_n+400)*100)) {
                     f = open(save_dir+swrite(format="i_e%d_n%d_%d/errors.txt", idx_e, idx_n, zone), "a");
                     write, f, format="Data tile %9.2f %9.2f %9.2f %9.2f %s exceeded normal size.\n", min_e, max_e, min_n, max_n, mdate;
                     write, f, format="	Tile size acctually: %9.2f %9.2f %9.2f %9.2f\n", min(depth_all.east)/100., max(depth_all.east)/100., min(depth_all.north)/100., max(depth_all.north/100.);
                     pldj, max_e, max_n, min_e, max_n, color="red";
                     pldj, min_e, min_n, max_e, min_n, color="red";
                     pldj, max_e, min_n, max_e, max_n, color="red";
                     pldj, min_e, min_n, min_e, max_n, color="red";
                     numend = numberof(data_box(depth_all.east, depth_all.north, (min_e-400)*100, (max_e+400)*100, (min_n-400)*100, (max_n+400)*100));
                     write, f, format="# of points removed: %d of %d (That's %4.1f precent)\n", numstart-numend, numstart, ((((numstart-numend)*1.)/(numstart*1.))*100);
                     close, f
                  }

                  if (edf) {
                     write, format = "Writing edf file for Region %d of %d\n",i,n;
                     write_bathy, ofn(1), split_path(ofn(2),0,ext=1)(1)+"_b.edf", depth_all;
                  }
                  if (pbd) {
                     new_ofn = split_path(ofn(2),0,ext=1);
                     t = *pointer(new_ofn(1));
                     nn = where(t == '_');
                     date = string(&t(nn(0)+1:));
                     vname = "bat_"+date+"_"+swrite(format="%d",i);
                     write, format = "Writing pbd file for Region %d of %d\n",i,n;
                     f = createb(split_path(pofn,0,ext=1)(1)+"_b.pbd");
                     add_variable, f, -1, vname, structof(depth_all), dimsof(depth_all);
                     get_member(f, vname) = depth_all;
                     save, f, vname;
                     close, f;
                  }
               }
            }
         }
      }
      if (typ == 2) {
         if ((get_typ && !only_bathy) || (!get_typ)) {
            write, format = "Processing Region %d of %d for Vegetation\n",i,n;
            veg_all = make_veg(latutm = 1, q = q, ext_bad_veg=1, ext_bad_att=1, use_centroid=1);
            if (is_array(veg_all))  {
               veg_all = clean_veg(veg_all);
               if (is_array(veg_all)) {
                  if (edf) {
                     write, format = "Writing edf file for Region %d of %d\n",i,n;
                     write_vegall, opath=ofn(1), ofname=split_path(ofn(2),0,ext=1)(1)+"_v.edf", veg_all;
                  }
                  if (pbd) {
                     new_ofn = split_path(ofn(2),0,ext=1);
                     t = *pointer(new_ofn(1));
                     nn = where(t == '_');
                     date = string(&t(nn(0)+1:));
                     vname = "bet_"+date+"_"+swrite(format="%d",i);
                     write, format = "Writing pbd file for Region %d of %d\n",i,n;
                     f = createb(split_path(pofn,0,ext=1)(1)+"_v.pbd");
                     add_variable, f, -1, vname, structof(veg_all), dimsof(veg_all);
                     get_member(f, vname) = veg_all;
                     save, f, vname;
                     close, f;
                  }
               }
            }
         }
      }
      if (typ == 3) {
         write, "type is 3"
         if ((get_typ && !only_veg) || (!get_typ)) {
         //process for bathy
         write, format = "Processing Region %d of %d for Bathymetry\n",i,n;
         depth_all = make_bathy(latutm = 1, q = q, ext_bad_depth=1, ext_bad_att=1);
         if (is_array(depth_all)){
            depth_all = clean_bathy(depth_all);
            if (is_array(depth_all)) {
               if (edf) {
                  write, format = "Writing edf file for Region %d of %d\n",i,n;
                  write_bathy, ofn(1), split_path(ofn(2),0,ext=1)(1)+"_b.edf", depth_all;
               }
               if (pbd) {
                  new_ofn = split_path(ofn(2),0,ext=1);
                  t = *pointer(new_ofn(1));
                  nn = where(t == '_');
                  date = string(&t(nn(0)+1:));
                  vname = "bat_"+date+"_"+swrite(format="%d",i);
                  write, format = "Writing pbd file for Region %d of %d\n",i,n;
                  f = createb(split_path(pofn,0,ext=1)(1)+"_b.pbd");
                  add_variable, f, -1, vname, structof(depth_all), dimsof(depth_all);
                  get_member(f, vname) = depth_all;
                  save, f, vname;
                  close, f;
               }
            }
         }
      }
      if ((get_typ && !only_bathy) || (!get_typ)) {
         write, format = "Processing Region %d of %d for Vegetation\n",i,n;
         veg_all = make_veg(latutm = 1, q = q, ext_bad_veg=1, ext_bad_att=1, use_centroid=1);
         if (is_array(veg_all))  {
            veg_all = clean_veg(veg_all);
            if (is_array(veg_all)) {
               if (edf) {
                  write, format = "Writing edf file for Region %d of %d\n",i,n;
                  write_vegall, opath=ofn(1), ofname=split_path(ofn(2),0,ext=1)(1)+"_v.edf", veg_all;
               }
               if (pbd) {
                  new_ofn = split_path(ofn(2),0,ext=1);
                  t = *pointer(new_ofn(1));
                  nn = where(t == '_');
                  date = string(&t(nn(0)+1:));
                  vname = "bet_"+date+"_"+swrite(format="%d",i);
                  write, format = "Writing pbd file for Region %d of %d\n",i,n;
                  f = createb(split_path(pofn,0,ext=1)(1)+"_v.pbd");
                  add_variable, f, -1, vname, structof(veg_all), dimsof(veg_all);
                  get_member(f, vname) = veg_all;
                  save, f, vname;
                  close, f;
                  }
               }
            }
         }
      }
   // } else {
   //    write, "No Flightlines found in this block."
   // }
   return update;
}

// show progress of jobs completed.
func show_progress(color=) {
   if ( is_void(color) ) color= "red";
   // XYZZY: We need to trap somehow that the system didn't work, or we'll fail on the open
   system, "./show_tiles.pl -rm /tmp/batch/done > /tmp/batch/.tiles";
   f = open("/tmp/batch/.tiles");

   col1= col2= col3= col4= array(0, 1000 /* max rows per column */ );
   read, f, col1, col2, col3, col4;
   close,f;
   // system, "rm /tmp/batch/.tiles";

   col1 = col1(where(col1));  // Throw away nulls
   col2 = col2(where(col2));  // Throw away nulls
   col3 = col3(where(col3));  // Throw away nulls
   col4 = col4(where(col4));  // Throw away nulls

   if ( is_array( col1 )) {
      pldj, col1, col3, col1, col4, color=color
      pldj, col1, col3, col2, col3, color=color
      pldj, col2, col3, col2, col4, color=color
      pldj, col2, col4, col1, col4, color=color
   }
   window,6;  // seems to help in getting the sgtatus plot updated.
}

// Check space in batch area
func check_space(wmark=, dir=) {
   // XYZZY: need to trap somehow that system didn't work, or we'll fail on the open
   cmd = swrite(format="./waiter.pl -noloop %d %s > /tmp/batch/.space", wmark, dir );
   system, cmd;
   f = open("/tmp/batch/.space");

   space= fc= array(0, 1 /* max rows per column */ );
   read, f, space, fc
   close,f;
   // system, "rm /tmp/batch/.space";
   return ([space, fc]);
}

func batch_process(typ=, save_dir=, shem=, zone=, dat_tag=, cmdfile=, n=, onlyplot=, mdate=, pbd=, edf=, win=, auto=, pick=, get_typ=, only_bathy=, only_veg=, update=, avg_surf=,conf_file=, now=) {
/* DOCUMENT batch_process
   See: mbatch_process
*/
   mbatch_process(typ=typ, save_dir=save_dir, shem=shem, zone=zone, dat_tag=dat_tag, cmdfile=cmdfile, n=n, onlyplot=onlyplot, mdate=mdate, pbd=pdb, edf=edf, win=win, auto=auto, pick=pick, get_typ=get_typ, only_bathy=only_bathy, only_veg=only_veg, update=update, avg_surf=avg_surv,conf_file=conf_file, now=1);
}

func mbatch_process(typ=, save_dir=, shem=, zone=, dat_tag=, cmdfile=, n=, onlyplot=, mdate=, pbd=, edf=, win=, auto=, pick=, get_typ=, only_bathy=, only_veg=, update=, avg_surf=,conf_file=, now=, b_rcf=, buf=, w=, no_rcf=, mode=, merge=, clean=, rcfmode=, write_merge=) {
/* DOCUMENT mbatch_process
func batch_process(typ=, save_dir=, shem=, zone=, dat_tag=,
                   cmdfile=, n=, onlyplot=, mdate=, pbd=, edf=,
                   win=, auto=, pick=, get_typ=, only_bathy=,
                   only_veg=, update=,conf_file=, now=)

This function is used to batch process several regions for a given
data set.  The regions are either defined by a command file or
automatically choosen by the program if auto=1 (auto=1 by default)

Input:
  typ=         : Type of data to process for
                 0 for first surface
                 1 for bathy
                 2 for topo under veg

  save_dir=    : Directory name where the processed data will be written

  zone=        : Set to UTM zone number when using pick=1

  onlyplot=    : Set to '1' to only plot the areas that would be
                 processed to the screen.
                 (no actual processing is done).

  mdate=       : Set to the string of the date the data was taken
                 in yyyymmdd format.
                 e.g. "20040304"

  pbd=         : Set to write out pbd files
  edf=         : Set to write out edf files
                 Default is pbd,  only select one output format.

  win=         : window number where the rbgga information is displayed.
                 Default is 6.

  only_bathy=  : Set to 1 to process only bathy data.
                 Defaults to both bathy and veg when typ=3

  only_veg=    : set to 1 to process only veg data.
                 Defaults to both bathy and veg when typ=3

  update=      : Set to 1 to process for only those files where the
                 output does not exist.  Useful when the program halts,
                 and you want to resume processing.
                 Set to 2 to only process for rcf.

  avg_surf=    : Set to 1 to use the average of the water surface
                 reflections when processing for bathymetry (typ=1).
                 Default is avg_surf=1, use 0 to disble

  now=         : Set to 1 to process in the current ALPS session.  This
                 is automatically set when called as batch_process().

                 Set to 0, requires running one "batcher.tcl server" AND
                 one or more "batcher.tcl localhost".  This is the default
                 for mbatch_process and allows for multiple cpus/cores to
                 be used to process the data.  To run the client on a
                 separate computer, "batcher.tcl HOST" where host is the
                 name of the server computer.

If using the automatic region creation, the following options
are REQUIRED:

  auto=      : Sets the program to run in automatic mode.
               Default is 1 if cmdfile is not set.

  save_dir=  : Root path to save the data, path must exist.

  zone=      : UTM zone
               e.g. zone=17

  dat_tag=   : Datum tag
               Default is w84, but can be set to any string.
               e.g. dat_tag="n88"

  schem=     : Set to 1 if the data is in the southern hemisphere.
               Required to properly define the utm zone letter.

  conf_file= : Puts the .conf file parameters into the meta-data
               files.  Set to be the path of the .conf file used
               in quotes.

  b_rcf=     : 1 - invokes batch_rcf after normal batch processing

The following are pass thru variables needed for batch_rcf
  buf=         :
  w=           :
  no_rcf=      :
  mode=        :
  merge=       :
  clean=       :
  rcfmode=     :
  write_merge= :



Ex: curzone=18
    batch_process,typ=2,save_dir="/data/3/2004/bombay-hook/output/",
                  mdate="20040209",zone=18,pick=1


amar nayegandhi started (10/04/02) Lance Mosher
Added server/client support (2009-01) Richard Mitchell
*/

   extern pnav_filenam, bath_ctl

   // start the timer
   timer, t0;
   myt0 = t0(3);
   write, format="Start Time: %f\n", t0(3);
   if (is_void(host)) host="localhost";
   if (is_void(now)) now=0;
   if (is_void(win)) win = 6;
   window, win;

   // Create output directory for tilekkk cmd files:
   system, "mkdir -p /tmp/batch/jobs";

   // Get username and pc name of person running batch_process
   system, "uname -n > ~/temp.123456789";
   system, "whoami >> ~/temp.123456789";
   f = open("~/temp.123456789");
   user_pc_NAME = array(string,2);
   user_pc_NAME(1) = rdline(f);
   user_pc_NAME(2) = rdline(f);
   close,f;
   system, "rm ~/temp.123456789";

   if (zone) zone_s = swrite(format="%d", zone);
   //if (zone) pick=1;
   if (!pbd && !edf)      pbd      = 1;
   if (is_void(typ))      get_typ  = 1;
   if (!dat_tag)          dat_tag  = "w84";
   if (is_void(update))   update   = 0;
   if (is_void(avg_surf)) avg_surf = 1;
   if (is_void(b_rcf))    b_rcf    = 0;
   if (!cmdfile && !auto) auto     = 1;
   if (cmdfile) {
      path = array(string, n);
      min_e = array(float, n);
      max_e = array(float,n);
      min_n = array(float, n);
      max_n = array(float, n);
      // open cmdfile
      f = open(cmdfile, "r");
      read, f, format="%s %f %f %f %f", path, min_e, max_e, min_n, max_n;
      close, f;
   }
   conf_file_lines=[];
   if (is_array(conf_file)) {
      cfile = open(conf_file);
      conf_file_lines = array(string,6);
      for (i=1;i<=6;i++) {
         conf_file_lines(i) = rdline(cfile);
      }
      close, cfile;
   }
   if ((auto)&&(pick==1)) {
      window, win;
      rgn = array(float, 4);
      if (pick==1) {
         a = mouse(1,1,
         "Hold the left mouse button down, select a region:");
         rgn(1) = min( [ a(1), a(3) ] );
         rgn(2) = max( [ a(1), a(3) ] );
         rgn(3) = min( [ a(2), a(4) ] );
         rgn(4) = max( [ a(2), a(4) ] );
         a_x=[rgn(1), rgn(2), rgn(2), rgn(1), rgn(1)];
         a_y=[rgn(3), rgn(3), rgn(4), rgn(4), rgn(3)];
      } else {
         north_east = fll2utm(max(pnav.lat), max(pnav.lon));
         south_west = fll2utm(min(pnav.lat), min(pnav.lon));
         rgn(1) = south_west(2);
         rgn(2) = north_east(2);
         rgn(3) = south_west(1);
         rgn(4) = north_east(1);
         zone = long(north_east(3));
         zone_s = swrite(format="%d", long(north_east(3)));
      }
      write, "Region selected. Confirming region... this may take several minutes..."
      ind_e_min = 2000 * (int((rgn(1)/2000)));
      ind_e_max = 2000 * (1+int((rgn(2)/2000)));
      if ((rgn(2) % 2000) == 0) ind_e_max = rgn(2);
      ind_n_min = 2000 * (int((rgn(3)/2000)));
      ind_n_max = 2000 * (1+int((rgn(4)/2000)));
      if ((rgn(4) % 2000) == 0) ind_n_max = rgn(4);
      n_east = (ind_e_max - ind_e_min)/2000;
      n_north = (ind_n_max - ind_n_min)/2000;
      n = n_east * n_north;

      if (get_typ) {
         restore, openb("TB_Types.i"), tile;
         indx = where(tile.min_e >= ind_e_min);
         if (is_array(indx)) {
            tile = tile(indx);
            indx1 = where(tile.max_e <= ind_e_max);
            if (is_array(indx1)) {
               tile = tile(indx1);
               indx2 = where(tile.min_n >= ind_n_min);
               if (is_array(indx2)) {
                  tile = tile(indx2);
                  indx3 = where(tile.max_n <= ind_n_max);
                  if (is_array(indx3)) tile = tile(indx3);
               } else tile = 0;
            } else tile = 0;
         } else tile = 0;
      }
      min_e = array(float, n);
      max_e = array(float, n);
      min_n = array(float, n);
      max_n = array(float, n);
      i = 1;

      for (e=ind_e_min; e<=(ind_e_max-2000); e=e+2000) {
         for(north=(ind_n_min+2000); north<=ind_n_max; north=north+2000) {
            min_e(i) = e;
            max_e(i) = e+2000;
            min_n(i) = north-2000;
            max_n(i) = north;
            i++;
         }
      }
   }

   if(pick==2) {
      ply=getPoly();
      plotPoly(ply);
      box=boundBox(ply);
      rgn= array(float,4)
      rgn(1) = min ( [box(1,1)], [box(1,2)], [box(1,3)], [box(1,4)] );
      rgn(2) = max ( [box(1,1)], [box(1,2)], [box(1,3)], [box(1,4)] );
      rgn(3) = min ( [box(2,1)], [box(2,2)], [box(2,3)], [box(2,4)] );
      rgn(4) = max ( [box(2,1)], [box(2,2)], [box(2,3)], [box(2,4)] );

      mine=(int(rgn(1)));
      maxe=(int(rgn(2)+1));
      minn=(int(rgn(3)));
      maxn=(int(rgn(4)+1));

      mine=(2000*(mine/2000))-2000;
      maxe=(2000*(maxe/2000))+2000;
      minn=(2000*(minn/2000))-2000;
      maxn=(2000*(maxn/2000))+2000;


      count=0;
      for(i=minn; i<maxn; i=i+2000) {
         for(j=mine; j<maxe; j=j+2000) {
            e_coor=[j, j, j+2000, j+2000];
            n_coor=[i, i+2000, i, i+2000];
            ptsInPoly=testPoly(ply, e_coor, n_coor);
            if(numberof(ptsInPoly)>0)
               count++;
         }
      }

      min_e=array(float, count);
      min_n=array(float, count);
      max_e=array(float, count);
      max_n=array(float, count);

      count=1;
      for(i=minn; i<maxn; i=i+2000){
         for(j=mine; j<maxe; j=j+2000) {
            e_coor=[j, j, j+2000, j+2000];
            n_coor=[i, i+2000, i, i+2000];
            ptsInPoly=testPoly(ply, e_coor, n_coor);
            if(numberof(ptsInPoly)>0) {
               min_e(count)=j;
               min_n(count)=i;
               max_e(count)=j+2000;
               max_n(count)=i+2000;
               count++;
            }
         }
      }

      n=count-1;

   }


   // ok, show a quick grid, but in yellow or something light
   pldj, min_e, min_n, min_e, max_n, color="yellow"
   pldj, min_e, min_n, max_e, min_n, color="yellow"
   pldj, max_e, min_n, max_e, max_n, color="yellow"
   pldj, max_e, max_n, min_e, max_n, color="yellow"

   if (onlyplot == 1) return

   indx_path = array(string,n);

   for (i=1;i<=n;i++) {
      if (cmdfile) indx_path(i) = (split_path(path(i),-1))(1);
      if (auto) {
         idx_e = long(10000 * long(min_e(i) / 10000));
         idx_n = long(10000 * long(1+(max_n(i) / 10000)));
         if ((max_n(i) % 10000) == 0) idx_n = long(max_n(i));
         indx_path(i) = swrite(format="%si_e%d_n%d_%s/", save_dir, idx_e, idx_n, zone_s);
      }
   }
   iidx_path = unique(indx_path);
   bool_arr = array(int, numberof(iidx_path));
   mtdt_path = array(string, numberof(iidx_path));
   mtdt_file = array(string, numberof(iidx_path));
   for (i=1;i<=numberof(iidx_path);i++) {
      mtdt_path(i) = indx_path(iidx_path(i));
      indx_tile = split_path(mtdt_path(i), -1)(2);
      indx_tile = strpart(indx_tile, 1:-1); // remove the trailing slash
      mtdt_file(i) = mtdt_path(i)+indx_tile+"_"+mdate+"_metadata.txt";
      if (cmdfile) {
         f = open(mtdt_file(i),"a");
         write, f, "Batch Processing Begins"
         write, f, timestamp();
         write, f, format="PNAV FILE: %s\n",pnav_filename;
         if (typ == 0) write, f, "Processing for First Surface Returns"
         if (typ == 1) {
            write, f, "\nProcessing for Bathymetry";
            write, f, "Bathymetry Constants: ";
            write, f, format="Laser: %f\n",bath_ctl.laser;
            write, f, format="Water: %f\n",bath_ctl.water;
            write, f, format="AGC  : %f\n",bath_ctl.agc;
            write, f, format="Threshold: %f\n",bath_ctl.thresh;
            write, f, format="Last : %d\n",bath_ctl.last;
         }
         if (typ == 2) write, f, "Processing for topography under vegetation ie. (Bare Earth)"
         write, f, "\nops_conf constants: ";
         write, f, format="y_offset: %f\n",ops_conf.y_offset;
         write, f, format="x_offset: %f\n",ops_conf.x_offset;
         write, f, format="z_offset: %f\n",ops_conf.z_offset;
         write, f, format="roll_bias: %f\n",ops_conf.roll_bias;
         write, f, format="pitch_bias: %f\n",ops_conf.pitch_bias;
         write, f, format="yaw_bias: %f\n",ops_conf.yaw_bias;
         write, f, format="scan_bias: %f\n",ops_conf.scan_bias;
         write, f, format="range_biasM: %f\n",ops_conf.range_biasM;
         close, f;
      }
   }
   for (i=1;i<=n;i++) {
      if (cmdfile) {
         ofn = split_path(path(i),0);
         if (mdate) {
            new_ofn = split_path(ofn(2),0,ext=1);
            ofn(2) = new_ofn(1)+mdate+new_ofn(2);
         }
         if (pbd) {
            new_ofn = split_path(ofn(2),0, ext=1);
            ofn(2) = new_ofn(1)+".pbd";
            pofn = ofn(1)+ofn(2);
         }
         if (edf) {
            new_ofn = split_path(ofn(2),0,ext=1);
            ofn(2) = new_ofn(1)+".edf";
         }
      }
      write, format = "Selecting Region %d of %d\n",i,n;
      q = gga_win_sel(2, win=win, llarr=[min_e(i)-200.0, max_e(i)+200.0, min_n(i)-200.0, max_n(i)+200.0], _batch=1);
      // 2009-01-15: came across odd bug where q was:  <nuller>:
      // To avoid, check for numberof as well.
      if ( ! is_void(q) && numberof(q) > 0 ) {
         r = gga_win_sel(2, win=win, color="green", llarr=[min_e(i), max_e(i), min_n(i), max_n(i)], _batch=1);
         if ( ! is_void(r) && numberof(r) > 0 ) {
            // Show the tile that is being prepared to be processed.
            pldj, min_e(i), min_n(i), min_e(i), max_n(i), color="blue"
            pldj, min_e(i), min_n(i), max_e(i), min_n(i), color="blue"
            pldj, max_e(i), min_n(i), max_e(i), max_n(i), color="blue"
            pldj, max_e(i), max_n(i), min_e(i), max_n(i), color="blue"

            if ( now == 0 ) {
               show_progress, color="green";

               // make sure we have space before creating more files
               system, "./waiter.pl 250000 /tmp/batch/jobs"
               package_tile(q=q, r=r, typ=typ, min_e=min_e(i), max_e=max_e(i), min_n=min_n(i), max_n=max_n(i) )
            } else {
               uber_process_tile(q=q, r=r, typ=typ, min_e=min_e(i), max_e=max_e(i), min_n=min_n(i), max_n=max_n(i), host=host )
            }
         }
      }
  }
   if ( now == 0 ) {
      // wait until no more jobs to be farmed out
      do {
         mya1 = check_space(wmark=1024, dir="/tmp/batch/jobs");
         if ( mya1(2) > 0 ) write,format="%d job(s) to be farmed out.\n", mya1(2);

         show_progress, color="green";
         mya2 = check_space (wmark=1024, dir="/tmp/batch/farm");
         if ( mya2(2) != rj ) write,format="%d job(s) to be retrieved.\n", mya2(2);

         show_progress, color="green";
         mya3 = check_space (wmark=1024, dir="/tmp/batch/work");
         if ( mya3(2) != rj ) write,format="%d job(s) to be finished.\n", mya3(2);
         space = mya1(1) + mya2(1) + mya3(1);
      } while ( space(1) > 1024 );
      // wait until all jobs finished.
      rj = 99;
      do {
         system, "./waiter.pl -noloop 1024 /tmp/batch/work > /tmp/batch/.space"
         f = open("/tmp/batch/.space");

         space= fc= array(0, 1 /* max rows per column */ );
         read, f, space, fc
         close,f;
         // system, "rm /tmp/batch/.space";
         if ( fc(1) != rj ) write,format="%d job(s) to be finished.\n", fc(1);
         rj = fc(1);
         show_progress, color="green";
      } while ( space(1) > 1024 );
   }

   // stop the timer
   write, format="start Time: %f\n", t0(3);
   timer, t1;
   myt1 = t1(3);
   write, format="End   Time: %f\n", t1(3);
   t = (t1-t0)/60.;
   for (ij = 1; ij <=numberof(iidx_path); ij++) {
      if (bool_arr(ij) == 1) {
         f = open(mtdt_file(ij), "a");
         write, f, "Batch Processing Complete."
         write, f, timestamp();
         close, f;
      }
   }
   write, "Batch Process Complete. GoodBye."
   write, format="Time Statistics in minutes: \n CPU    :%12.4f \n System :%12.4f \n Wall   :%12.4f\n",t(1), t(2), t(3);
   write, format="Walltime: %f: %f - %f\n", myt1-myt0, myt1, myt0;

}


func batch_rcf(dirname, fname=, buf=, w=, tw=, fbuf=, fw=, no_rcf=, mode=, meta=, prefilter_min=, prefilter_max=, clean=, compare_noaa=, merge=, write_merge=, readedf=, readpbd=, writeedf=, writepbd=, rcfmode=, datum=, fsmode=, wfs=, searchstr=, bmode=, interactive=, onlyupdate=, selectmode=) {
/* DOCUMENT
func batch_rcf(dirname, fname=, buf=, w=, tw=, fbuf=, fw=, no_rcf=,
               mode=, meta=, prefilter_min=, prefilter_max=, clean=,
               compare_noaa=, merge=, write_merge=, readedf=, readpbd=,
               writeedf=, writepbd=, rcfmode=, datum=, fsmode=, wfs=,
               searchstr=, bmode=, interactive=, onlyupdate=)

This function batch processes using the rcf filter.

Input:
  dirname  : The directory name to process all files within,
             including subdirectories, unless fname is also set.

  fname=   : Provide a single file name to process.
             If fname is set, only this file will be processed.

  buf=     : Horizontal (north,east) size of the area to be filtered
             in centimeters.  Essentially buf=700 describes a 7m
             rectangle on the ground.
             Default is 700cm.

  w=       : Vertical (elevation) height in cm of the "buf" rectangle.
             Default is 200cm.

  no_rcf=  : Minimum number of data points that must be found within
             the volume described by "buf" and "w" before any data
             from this volume will be be returned.
             Default is 3 points.

  mode=    : 1 First surface
             2 Bathymetry
             3 "Ground under Vegetation" AKA last return or
               bare earth.

  meta=    : Set to 1 to have the file name contain the rcf parameters.

  prefilter_max= : Maximum allowable elevation to be used before
                   filtering (in meters)

  prefilter_min= : Minimum allowable elevation to be used before
                   filtering (in meters)

  clean=   : Set to 1 to eliminate data points that have already
             been determined as erroneous for one of the data
             structure fields.

  compare_noaa=  : Set to 1 to compare bathy data with the NOAA
                   data in the florida keys.

  merge=   : Set to 0 to not merge all the files in directory
             dirname before filtering (as defined by searchstr).
             Default is 1.

  write_merge=   : Set to 1 to write out merged data file before
                   filtering.

  readedf= : set to 1 to read  edf files (slow)
  readpbd= : set to 1 to read  pbd files (default,fast)
  writeedf=: set to 1 to write edf files (slow)
  writepbd=: set to 1 to write pbd files (default, fast, recommended)

  rcfmode= : Set to 2 to use the triangulation filter to RCF the data.
             Set to 1 to use the plain RCF filter.
             Set to 0 do disable filter (merge only).
             Default is 2.

  datum=   : Set to "n88" to use the NAVD88 files.
             Set to "w84" to use the WGS84  files.

  fsmode=  : Set to 4 if you want to filter the bad first returns
             from the good bare earth returns when mode is set to 3.

  wfs=     : Elevation width or vertical extent for first surface
             elevations when fsmode is set to 4 in METERS.
             Default is 25m.

  searchstr= : Search string for the file names. Default = "*.pbd"
               e.g. "*n88*_v.pbd".
               Do not use datum= keyword when using searchstr.

               If datum= is not set, searchstr must be set.
               Use searchstr="*.pbd" to include all files in the
               directory.

 bmode=      : Set to 0 when not using batch mode with correct
               file naming conventions
               Default is 1.

 onlyupdate= : Set to 1 to keep existing files.
               (Useful when resuming from a partial filter).
               Default is 0.

 selectmode= : Set to 1 to select an rcf region using a rubberband box.
               All data tiles within the selected region will be rcf'd.

Original amar nayegandhi. Started 12/06/02.
*/

   timer, t0;
   extern fn_all, noaa_data, ofn;

   if (!readedf && !readpbd) readpbd = 1;
   if (!writeedf && !writepbd) writepbd = 1;
   if (!buf) buf = 700;
   if (!w) w = 200;
   if (!no_rcf) no_rcf = 3;
   if (!meta) meta = 1;
   if (!clean) clean = 1;
   if (is_void(dorcf)) dorcf = 1;
   if (compare_noaa && is_void(datum)) datum = "n88";
   if (!mode) mode=2;
   if (is_void(bmode)) bmode = 1;
   if (is_void(rcfmode)) rcfmode=2;
   if (interactive) {plottriag = 1; datawin=5;}
   if (is_void(merge)) merge=1;
   if (is_void(searchstr)) searchstr="*.pbd";


   if (!is_void(fname)) {
      fn_all = dirname+fname;
   } else {
      if (!is_void(selectmode)) {
         fn_all = select_datatiles(dirname, search_str=searchstr, mode=selectmode+1, win=win);
      } else {
         s = array(string, 10000);
         if (is_array(searchstr)) {
            ss = searchstr;
         } else {
            if (readedf) {
               if (datum) {
                  ss = ["*"+datum+"*.bin", "*"+datum+"*.edf"];
               } else {
                  ss = ["*.bin", "*.edf"];
               }
            }
            if (readpbd) {
               if (datum) {
                  ss = ["*"+datum+"*.pbd"];
               } else {
                  ss = ["*.pbd"];
               }
            }
         }
         scmd = swrite(format = "find %s -name '%s'",dirname, ss);
         fp = 1; lp = 0;
         for (i=1; i<=numberof(scmd); i++) {
            f=popen(scmd(i), 0);
            n = read(f,format="%s", s );
            close, f;
            lp = lp + n;
            if (n) fn_all = s(fp:lp);
            fp = fp + n;
         }
      }
   }
   write, numberof(fn_all);

   if (!is_array(fn_all))
      exit,"No input files found.  Goodbye.";

   if ((onlyupdate == 1) && (rcfmode == 1)) {
      mgd_mode = strmatch(fn_all, "_rcf",1);
      oldfiles = fn_all(where(mgd_mode));
   }
   if ((onlyupdate == 1) && (rcfmode ==2)) {
      mgd_mode = strmatch(fn_all, "_ircf",1);
      oldfiles = fn_all(where(mgd_mode));
   }
   if ((mode == 1) || (mode == 3)) {
      mgd_mode = strmatch(fn_all, "_v",1);
      fn_all = fn_all(where(mgd_mode));
   }
   if (mode == 2) {
      mgd_mode = strmatch(fn_all, "_b", 1);
      fn_all = fn_all(where(mgd_mode));
   }

   /*
   // consider only files that do not have "rcf" in them
   if (rcfmode ==1) {
      mgd_mode = strmatch(fn_all, "_rcf",1);
      fn_all = fn_all(where(!mgd_mode));
   }
   if (rcfmode ==2) {
      mgd_mode = strmatch(fn_all, "_ircf",1);
      fn_all = fn_all(where(!mgd_mode));
   }
   */

   write, numberof(fn_all);


   if (merge) {
      // do not include merged files
      mgd_idx = strmatch(fn_all,"merged",1);
      fn_all = fn_all(where(!mgd_idx));
      // merge files within each data tile
      tile_dir = array(string, numberof(fn_all));
      all_dir = array(string, numberof(fn_all));
      tile_fname = array(string, numberof(fn_all));
      for (ti = 1; ti <= numberof(fn_all); ti++) {
         tile_split = split_path(fn_all(ti), -1);
         t = *pointer(tile_split(2));
         n = where(t == '/');
         tile_dir(ti) = string(&t(1:n(1)));
         tile_fname(ti) = string(&t(n(1)+1:0));
         all_dir(ti) = (split_path(fn_all(ti),0))(1);
      }
      uidx = unique(tile_dir);
      ndirname = array(string, numberof(uidx));
      ndirname = all_dir(uidx);
      fname = array(string, numberof(uidx));
      for (ti=1; ti<=numberof(uidx);ti++) {
         t = *pointer(tile_fname(uidx(ti)));
         n = where(t == '_');
         fname(ti) = string(&t(1:n(-1)-1))+string(&t(n(0):));
      }
      fn_all = ndirname+fname;
   }

   nfiles = numberof(fn_all);
   write, format="Total number of files to RCF = %d\n",nfiles;

   if ( now == 1 && _ytk && (int(nfiles) != 0) ) {
      tkcmd,"destroy .batch_rcf; toplevel .batch_rcf; set progress 0;"
      tkcmd,swrite(format="ProgressBar .batch_rcf.pb \
      -fg black \
      -troughcolor red \
      -relief raised \
      -maximum %d \
      -variable batch_progress \
      -height 30 \
      -width 400", int(nfiles) );
      tkcmd,"pack .batch_rcf.pb; update;"
   }

   for (i=1;i<=nfiles;i++) {
      fn_split = split_path(fn_all(i), 0);
      eaarl = [];
      vnametag = "";
      fnametag = "";
      if (onlyupdate) {
         fn = fn_all(i);
         oldfn = split_path(fn,1,ext=1);
         if (merge) fnametag = "_merged";
         if (compare_noaa) fnametag = fnametag+"_cnoaa";
         if ((mode == 1) && (strglob("*_v*",fn))) fnametag = fnametag+"_fs";
         if (rcfmode >=1) {
            if (rcfmode ==1) rcftag="_rcf";
            if (rcfmode ==2) rcftag="_ircf";
            if (interactive) rcftag = rcftag+"_mf";
            fnametag = fnametag+rcftag;
         }
         if (meta) {
            metakey = swrite(format="_b%d_w%d_n%d",buf,w,no_rcf);
            new_fn = oldfn(1)+metakey+fnametag+oldfn(2);
         } else {
            new_fn = oldfn(1)+fnametag+oldfn(2);
         }
         res = split_path(new_fn, 0);
         sp_new_fn = split_path(res(2),0,ext=1);
         if (writepbd)
         ofn = res(1)+sp_new_fn(1)+".pbd";
         if (writeedf) {
            res(2) = sp_new_fn(1)+".edf";
            ofn = res(1)+res(2);
         }
         if (is_array(where(oldfiles == ofn))) {
            swrite(format="File %i of %i exists.. continuing..", i, nfiles)
            continue;
         }
      }
      vnametag = [];
      fnametag = [];
      if (merge) {
         if (vnametag) {
            vnametag = vnametag+"_m"
         } else {
            vnametag = "_m"
         }
         if (fnametag) {
            fnametag = fnametag+"_merged"
         } else {
            fnametag = "_merged"
         }
         if (readedf) {
            write, format="merging eaarl edf data in directory %s\n",fn_split(1);
            if (datum) {
               data_ptr = read_yfile(fn_split(1), searchstring="*"+datum+"*"+searchstr+".edf");
            } else {
               data_ptr = read_yfile(fn_split(1), searchstring="*"+searchstr+"*");
            }
         }
         if (readpbd) {
            write, format="merging eaarl pbd data in directory %s\n",fn_split(1);
            if (datum) {
               eaarl = merge_data_pbds(fn_split(1), searchstring="*"+datum+"*"+searchstr+".pbd");
            } else {
               eaarl = merge_data_pbds(fn_split(1), searchstring="*"+searchstr+"*");
            }
         }
      } else {
         if (readedf) {
            data_ptr = read_yfile(fn_split(1), fname_arr = fn_split(2));
         }
         if (readpbd) {
            f = openb(fn_all(i));
            restore, f, vname;
            eaarl = get_member(f,vname);
         }
      }
      if (readedf) {
         for (j=1;j<=numberof(data_ptr);j++) {
            grow, eaarl, (*data_ptr(j));
         }
      }
      if (!(is_void(clean))) {
         if (mode == 1) {
            eaarl = clean_fs(eaarl);
         }
         if (mode == 2) {
            eaarl = clean_bathy(eaarl);
         }
         if (mode == 3) {
            eaarl = clean_veg(eaarl);
         }
      }
      data_ptr = [];
      if (bmode == 1) {
         fmeast = fmnorth = 0;
         sread, strpart(fn_split(2), 4:9), fmeast;
         sread, strpart(fn_split(2), 12:18), fmnorth;
         didx = data_box(eaarl.east/100., eaarl.north/100., fmeast-350, fmeast+2350, fmnorth-2350, fmnorth+350);
         if (is_array(didx)) {
            eaarl = eaarl(didx);
         } else continue;
      }
      if (!is_void(prefilter_min) && (is_void(prefilter_max))) {
         if (mode == 1) {
            pfindx = where(eaarl.elevation > prefilter_min*100);
         }
         if (mode == 2) {
            pfindx = where((eaarl.depth+eaarl.elevation) > prefilter_min*100);
         }
         if (mode == 3) {
            pfindx = where(eaarl.lelv > prefilter_min*100);
         }
         if (is_array(pfindx)) {
            eaarl = eaarl(pfindx);
         } else continue;
      }
      if (is_void(prefilter_min) && !(is_void(prefilter_max))) {
         if (mode == 1) {
            pfindx = where(eaarl.elevation < prefilter_max*100);
         }
         if (mode == 2) {
            pfindx = where((eaarl.depth+eaarl.elevation) < prefilter_max*100);
         }
         if (mode == 3) {
            pfindx = where(eaarl.lelv < prefilter_max*100);
         }
         if (is_array(pfindx)) {
            eaarl = eaarl(pfindx);
         } else continue;
      }
      if (!is_void(prefilter_min) && !(is_void(prefilter_max))) {
         if (mode == 1) {
            pfindx = where(eaarl.elevation < prefilter_max*100);
            pfpfindx = where(eaarl.elevation(pfindx) > prefilter_min*100);
         }
         if (mode == 2) {
            pfindx = where((eaarl.depth+eaarl.elevation) < prefilter_max*100);
            pfpfindx = where((eaarl.depth(pfindx)+eaarl.elevation(pfindx)) > prefilter_min*100);
         }
         if (mode == 3) {
            pfindx = where(eaarl.lelv < prefilter_max*100);
            pfpfindx = where(eaarl.lelv(pfindx) > prefilter_min*100);
         }
         pfindx = pfindx(pfpfindx);
         if (is_array(pfindx)) {
            eaarl = eaarl(pfindx);
         } else continue;
      }
      if (!is_array(eaarl))  continue;
      if (!(is_void(compare_noaa))) {
         //comparing data to noaa bathy data
         if (mode == 2) {
            if (vnametag) {
               vnametag = vnametag+"_cn"
            } else {
               vnametag = "_cn"
            }
            if (fnametag) {
               fnametag = fnametag+"_cnoaa"
            } else {
               fnametag = "_cnoaa"
            }
            write, "comparing data to noaa bathy data";
            if (!is_array(noaa_data)) {
               noaa_data = read_4wd_ascii("~/lidar-processing/noaa/", "bathy_data_keys_0_40m_min_max.txt");
            }
            eaarl = compare_data(noaa_data, eaarl);
         }
      }
      if (!is_array(eaarl)) continue;

      if(write_merge==1) {
         gg=merge_data_pbds(fn_split(1), write_to_file=1, merged_filename=file_rootname(fn_all(i))+"_merged.pbd", nvname="merged_v", searchstring="*"+searchstr+"*");
      }
      /*	if (interactive) {
            oldwin = window();
            winkill, 5; window,5,dpi=100,width=600, height=600, style="work.gs"; fma; limits, square=1;
            cbar.cmax=-14.5; cbar.cmin=-47.5; cbar.cdelta=33.0
            window, 5; plot_bathy, eaarl, win=5, ba=1, fs = 0, de = 0 , fint = 0, lint = 0, cmin=-47.5, cmax=-14.5, msize = 1.0, marker=1, skip=1;
            window, oldwin;
         }
      */

      if ((mode == 1) && (strglob("*_v*",fn_all(i)))) {
         if (fnametag) {
            fnametag = fnametag+"_fs";
         } else {
            fnametag = "_fs";
         }
      }

      if (rcfmode>=0) {
         write, "RCF'ing data points...\n"
         if (rcfmode==1)rcftag = "_rcf";
         if (rcfmode==2)rcftag = "_ircf";
         if (rcfmode==0)rcftag = "";
         if (interactive) rcftag+="_mf";
         if (vnametag) {
            vnametag = vnametag+rcftag;
         } else {
            vnametag = rcftag;
         }
         if (fnametag) {
            fnametag = fnametag+rcftag;
         } else {
            fnametag = rcftag;
         }
         if (rcfmode == 1) rcf_eaarl = rcfilter_eaarl_pts(eaarl, buf=buf, w=w, mode=mode, no_rcf=no_rcf, wfs=wfs, fsmode=fsmode);
         if (rcfmode == 2) rcf_eaarl = rcf_triag_filter(eaarl,buf=buf,w=w,mode=mode,no_rcf=no_rcf,tw=tw,fbuf=fbuf,fw=fw,interactive=interactive, datawin=datawin, plottriag=plottriag);
         if (rcfmode == 0) rcf_eaarl=eaarl;
         if (!is_array(rcf_eaarl)) continue;
         fn = fn_all(i);
         write, "Writing resulting data array to file...\n"
         oldfn = split_path(fn,1,ext=1);
         if (meta) {
            metakey = swrite(format="_b%d_w%d_n%d",buf,w,no_rcf);
            new_fn = oldfn(1)+metakey+fnametag+oldfn(2);
         } else {
            new_fn = oldfn(1)+fnametag+oldfn(2);
         }
         res = split_path(new_fn, 0);
         sp_new_fn = split_path(res(2),0,ext=1);
         if (writepbd)
         ofn = res(1)+sp_new_fn(1)+".pbd";
         if (writeedf) {
            res(2) = sp_new_fn(1)+".edf";
            ofn = res(1)+res(2);
         }

         //if (numberof(where(rcf_eaarl.east == 0))) lance_is_watching();
         if (mode == 1) {
            if (writeedf) {
               write_topo, res(1), res(2), rcf_eaarl;
            }
            if (writepbd) {
               vname = "fst"+vnametag+"_"+swrite(format="%d",i);
               write, format = "Writing pbd file for Region %d of %d\n",i,nfiles;
               f = createb(ofn);
               add_variable, f, -1, vname, structof(rcf_eaarl), dimsof(rcf_eaarl);
               get_member(f, vname) = rcf_eaarl;
               save, f, vname;
               close, f;
            }

         }
         if (mode == 2) {
            if (writeedf) {
               write_geoall, rcf_eaarl, opath=res(1), ofname=res(2);
            }
            if (writepbd) {
               vname = "bat"+vnametag+"_"+swrite(format="%d",i);
               write, format = "Writing pbd file for Region %d of %d\n",i,nfiles;
               f = createb(ofn);
               add_variable, f, -1, vname, structof(rcf_eaarl), dimsof(rcf_eaarl);
               get_member(f, vname) = rcf_eaarl;
               save, f, vname;
               close, f;
            }
         }
         if (mode == 3) {
            if (writeedf) {
               write_vegall, rcf_eaarl, opath=res(1), ofname=res(2);
            }
            if (writepbd) {
               vname = "bet"+vnametag+"_"+swrite(format="%d",i);
               write, format = "Writing pbd file for Region %d of %d\n",i,nfiles;
               f = createb(ofn);
               add_variable, f, -1, vname, structof(rcf_eaarl), dimsof(rcf_eaarl);
               get_member(f, vname) = rcf_eaarl;
               save, f, vname;
               close, f;
            }
         }
      }
      if (now == 1 && _ytk)
         tkcmd, swrite(format="set batch_progress %d", i)
   }

   if (now == 1 && _ytk) {
      tkcmd, "destroy .batch_rcf"
   }
   //batch_test_rcf(dirname, mode, datum=datum, testpbd=writepbd, testedf=writeedf, buf=buf, w=w, no_rcf=no_rcf);
}

func batch_write_xyz(dirname, outdir=, fname=, selectmode=, ss=, readpbd=,
readedf=, datum=, mode=, rcfmode=, ESRI=, header=, footer=, delimit=,
intensity=, rn=, soe=, indx=, zclip=, latlon=, buffer=, zone=, update=, qq=,
atm=) {
/* DOCUMENT batch_write_xyz, dirname, outdir=, fname=, selectmode=, ss=,
   readpbd=, readedf=, datum=, mode=, rcfmode=, ESRI=, header=, footer=,
   delimit=, intensity=, rn=, soe=, indx=, zclip=, latlon=, buffer=, zone=,
   update=, qq=, atm=

   Batch creates xyz files for specified files.

   Required parameters:

      dirname      : Directory name where the input files reside. (The input
                     files will be searched using a recursive find.)

   Options that determine output location:

      outdir=      : Specifies the directory where the output files will be
                     created.  If not provided, the output files will be
                     created alongside the input files.

   Options that determine file selection:

      The initial list of selected files is generated by one of four methods.
      In order of precedence (high to low), those methods are to specify a
      single file (using fname=), graphically specifying a bounding box (using
      selectmode=), specifying a search string (ss=), or specifying the kind of
      files to search for (readedf= and/or readpbd=, optionally with datum=).

      fname=       : Provide a single file name to be converted (the file
                     should be relative to dirname). This will cause
                     selectmode=, ss=, readpbd=, and readedf= to be ignored.

      selectmode=  : Set to 1 to select the convert region using a rubberband
                     box.  All data tiles within the selected region will be
                     converted. This will cause ss=, readpbd=, and readedf= to
                     be ignored.

      ss=          : Search string used in the find command. This can be a
                     single glob or an array of globs. This will cause readpbd=
                     and readedf= to be ignored.

      readpbd=     : Set to 1 to read pbd files (will search for *.pbd).
      readedf=     : Set to 1 to read edf files (will search for *.edf and
                     *.bin)
      datum=       : Set to "n88" to search for NAVD88 files.
                     Set to "w84" to search for WGS84 files.
                     This is only used if readpbd= or readedf= are being used.

      If readpbd and readedf are not specified, then the defaults are readpbd=1
      and readedf=0. If only one of them are specified, then the other will
      default to the opposite value (for example, readpbd=0 would result in
      readedf=1). Thus, if absolutely none of the above options are used, the
      default behavior is for all *.pbd files to be selected.

      After creating a list of files, the list is filtered down further based
      on the following options. (This filtering occurs regardless of which of
      the above selection methods are used.)

      mode=        : 1 for first surface (filters by *_v*)
                     2 for bathymetry (filters by *_b*)
                     3 for bare earth topography (filters by *_v*)
                     This will also append one of fs, ba, or be into the output
                     file name.
                     NOTE: This option defaults to mode=1.

      rcfmode=     : 1 for RCF (filters by *_rcf.*)
                     2 for IRCF (filters by *_ircf.*)
                     3 for IRCF_MF files (filters by *_ircf_mf.*)
                     If this option is omitted, then the files will not be
                     filtered based on rcf mode.

   Options that affect output file content:

      buffer=      : Sets the buffer size in meters. Data outside the tile's
                     limits plus the buffer's size will be excluded from
                     output. Zero constrains the data to the tiles' boundaries.
                     A negative value indicates that all data should be used.
                     e.g. buffer=0  crops to 2kmx2km
                          buffer=10 crops to 2.01kmx2.01km
                          buffer=-1 does not crop

   The following options are passed to write_ascii_xyz. Please refer to the
   documentation for write_ascii_xyz for information on what they do.

      ESRI=
      header=
      footer=
      delimit=
      intensity=
      rn=
      soe=
      indx=
      zclip=
      latlon=
      zone=

   Miscellaneous options:

      ESRI=        : If set to 1, files end with .txt. Otherwise, they end with
                     .xyz (this is the default).

      update=      : Set to 1 to create only those ascii files that are not yet
                     created. Useful when required to start from where you left
                     off. Note however that if the initial creation was
                     interrupted in the middle of a file's creation, that file
                     will not be finished since it already exists.

      qq=          : Set to 1 if you are converting quarter-quad tiles. When
                     this is specified, filtering will not be done based on
                     mode. It will also alter the buffer= algorithm to work on
                     quarter quad extents instead of 2km tile extents.

      atm=         : Set to 1 if you are converting ATM data. When this is
                     specified, filtering will not be done based on mode.

amar nayegandhi 10/06/03.
Refactored and modified by David Nagle 2008-11-04
*/
   default, ESRI, 0;
   default, buffer, -1;
   default, mode, 1;
   default, update, 0;
   default, readpbd, !readedf;
   default, readedf, !readpbd;
   default, qq, 0;
   default, atm, 0;
   default, outdir, "";

   if(!is_void(fname)) {
      fn_all = dirname + fname;
   } else if(!is_void(selectmode)) {
      fn_all = select_datatiles(dirname, search_str=ss, mode=selectmode+1, win=win);
   } else {
      if(!ss) {
         ss = [];
         if(readedf) {
            grow, ss, ["*.bin", "*.edf"];
         }
         if(readpbd) {
            grow, ss, ["*.pbd"]
         }
         if(!numberof(ss)) {
            exit, "Please provide ss= or specify readedf=1 or readpbd=1";
         }
         if(datum) {
            ss = "*" + datum + ss;
         }
      }

      fn_all = find(dirname, glob=ss);
   }

   if (!is_array(fn_all))
      exit,"No input files found.  Goodbye.";

   if(numberof(where(rcfmode == [1,2,3]))) {
      rcf_str = ["_rcf.", "_ircf.", "_ircf_mf."](rcfmode);
      w = where(strmatch(fn_all, rcf_str, 1));
      if(!numberof(w))
         exit, "No RCF'd input files found.  Goodbye.";
      fn_all = fn_all(w);
   }

   if(!numberof(where(mode == [1,2,3])))
      exit, "Please specify a mode (1, 2, or 3)";

   modechar = ["_v", "_b", "_v"](mode);
   out = ["fs", "ba", "be"](mode);

   if(!qq && !atm) {
      w = where(strmatch(fn_all, modechar, 1));
      if(!numberof(w))
         exit, "No input files found for mode.  Goodbye.";
      fn_all = fn_all(w);
   }

   for (i=1; i<=numberof(fn_all); i++) {
      fn_tail = file_tail(fn_all(i));
      fn_path = file_dirname(fn_all(i));


      fn_ext = ESRI ? ".txt" : ".xyz";
      out_tail = file_rootname(fn_tail) + "_" + out + fn_ext;
      out_path = strlen(outdir) ? outdir : fn_path;
      fix_dir, out_path;

      // 2009-01-28: if we're going to skip because the file already exists,
      // lets skip quickly before loading any data - rwm
      if(update && file_exists(out_path + out_tail)) {
         // 2009-01-28: this should really check to see if the file size is > 0.
         // if yorick runs out of memory during the write process, the file will
         // exist but be empty. - rwm
         write, format="%3d: Skipping %s: output file already exists\n", i, fn_tail;
         continue;
      }

      if(strglob("*.pbd", fn_tail)) {
         f = openb(fn_all(i));
         eaarl = get_member(f, f.vname);
         close, f;
      } else if(strglob("*.bin", fn_tail) || strglob("*.edf", fn_tail)) {
         data_ptr = read_yfile(fn_path, fname_arr=fn_tail);
         eaarl = *data_ptr(1);
      } else {
         write, format="Skipping %s: unrecognized file extension\n", fn_tail;
         continue;
      }

      if(buffer >= 0) {
         n = e = [];
         if(mode == 1 || mode == 3) {
            n = eaarl.north;
            e = eaarl.east;
         } else if(mode == 2) {
            n = eaarl.lnorth;
            e = eaarl.least;
         }
         idx = [];
         n = n/100.;
         e = e/100.;
         if(qq) {
            idx = extract_for_qq(n, e, qq2uz(fn_tail), fn_tail, buffer=buffer);
         } else {
            idx = extract_for_dt(n, e, fn_tail, buffer=buffer);
         }
         n = e = [];
         if(numberof(idx)) {
            write, format="Applied buffer, reduced points from %d to %d\n", numberof(eaarl), numberof(idx);
            eaarl = eaarl(idx);
            idx = [];
         } else {
            eaarl = [];
            write, format="Skipping %s: no data within buffer\n", fn_tail;
            continue;
         }
      }
      pstruc = structof(eaarl(1));
      write, format="Writing ascii file %d of %d\n",i,numberof(fn_all);
      write_ascii_xyz, eaarl, out_path, out_tail, type=mode, indx=indx,
         intensity=intensity, delimit=delimit, zclip=zclip, pstruc=pstruc,
         rn=rn, soe=soe, header=header, latlon=latlon, zone=zone,
         ESRI=ESRI, footer=footer;
   }
}

func batch_test_rcf(dir, mode, datum=, testpbd=, testedf=, buf=, w=, no_rcf=, re_rcf=) {
/* DOCUMENT batch_test_rcf
   Goes through dir and determines if all the RCF files have been created.
   If not, it writes a  list of the missing tiles into batch_rcf_missin.txt.
   Set keywords to narrow the test to RCF'd files of certain datum, buf, w,
   or no_rcf.
   Specify wheather to search for pbd or edf with testpbd=/testedf=.
   If neither are set testpbd is the default
*/

   missingdirs=[];
//generate list of *.pbd files and data tile directories
   if ((!testpbd) && (!testedf)) testpbd=1;
   s = array(string, 100000);
   ss = ["*.pbd"];
   scmd = swrite(format = "find %s -name '%s'",dir, ss);
   fp = 1; lp = 0;
   for (i=1; i<=numberof(scmd); i++) {
      f=popen(scmd(i), 0);
      n = read(f,format="%s", s );
      close, f;
      lp = lp + n;
      if (n) fn_all = s(fp:lp);
      fp = fp + n;
   }
   t=*pointer(fn_all(1));
   nn=where(t=='_');
   dtiles = strpart(fn_all, 1:nn(-5)-2);
   dtiles = dtiles(unique(dtiles));
   dbool = array(short, numberof(dtiles),2);

//go through each directory and determine if the rcf file exists
   if ((mode == 1) || (mode == 3)) mchar = "v";
   if (mode == 2) mchar = "b";
   if (buf) sbuf = swrite(format="%d",buf);
   if (!buf) sbuf="";
   if (w) sw = swrite(format="%d",w);
   if (!w) sw ="";
   if (no_rcf) sno_rcf = swrite(format="%d",no_rcf);
   if (!no_rcf) sno_rcf="";
   if (!datum) datum="";
   if (testpbd) {
      for (j=1;j<=numberof(dtiles);j++) {
         fn_all = [];
         s = array(string, 100000);
         scmd = swrite(format = "find %s -name '*%s*%s*%s*%s*%s*rcf.pbd'", dtiles(j), datum, mchar, sbuf, sw, sno_rcf);
         fp = 1; lp=0;
         for (i=1; i<=numberof(scmd); i++) {
            f=popen(scmd(i), 0);
            n = read(f,format="%s", s );
            close, f;
            lp = lp + n;
            if (n) fn_all = s(fp:lp);
            fp = fp + n;
         }
         if (!is_void(fn_all)) dbool(j,1) = 1;
      }
   }
   if (testedf) {
      for (j=1;j<=numberof(dtiles);j++) {
         fn_all = [];
         s = array(string, 100000);
         scmd = swrite(format = "find %s -name '*%s*%s*%s*%s*%s*rcf.edf'", dtiles(j), datum, mchar, sbuf, sw, sno_rcf);
         fp = 1; lp=0;
         for (i=1; i<=numberof(scmd); i++) {
            f=popen(scmd(i), 0);
            n = read(f,format="%s", s );
            close, f;
            lp = lp + n;
            if (n) fn_all = s(fp:lp);
            fp = fp + n;
         }
         if (!is_void(fn_all)) dbool(j,2) = 1;
      }
   }
   if (testpbd) missingpbd = where(dbool(,1) == 0);
   if (testedf) missingedf = where(dbool(,2) == 0);
   if ((!is_array(missingpbd)) && (!is_array(missingedf))) {write, "No missing files!"; return;}
   if (is_array(missingpbd)) {
      write, "PBD files missing from directory:"
      for (i=1;i<=numberof(missingpbd);i++) {
         write, dtiles(missingpbd(i));
         grow, missingdirs, dtiles(missingpbd(i));
      }
   }
   if (is_array(missingedf)) {
      write, "EDF files missing from directory:"
      for (i=1;i<=numberof(missingedf);i++) {
         write, dtiles(missingedf(i))
      }
   }
   write, "Some PBD or EDF files were not created! Check above!!";
   if (re_rcf) {
      write, "re-filtering missing directories...";
      if (!buf || !w || !mode) {write, "You must specify buf, w, and mode in order to re-filter"; return missingdirs;}
      if ((buf=="") || (w=="") || !mode) {write, "You must specify buf, w, and mode in order to re-filter"; return missingdirs;}
      fmode = mode;
      if (mode == 1) fmode = 3;
      if (!no_rcf) (no_rcf=3);
      for (i=1;i<=numberof(missingdirs);i++) {
         batch_rcf, missingdirs(i), buf=buf, w=w, no_rcf=no_rcf, mode=fmode, meta=1, clean=1, merge=1, readpbd=1, writeedf=1, writepbd=1, dorcf=1, datum="w84", fsmode=(mode == 1) || (mode == 3);
      }
   }

   return missingdirs;
}

func pipthresh(data, maxthresh=, minthresh=,  mode=) {
/* DOCUMENT pipthresh(data, maxthresh=, minthresh=, mode=)
This function prompts the user to select data using the
points-in-polygon (PIP) technique and then returns all points
in this region that are within the speficified threshold.

Input:
  data        : Data array
  maxthresh=  : Maxiumum threshold value in meters.
                All data below this value are retained.

  minthresh=  : Minimum threshold value in meters.
                All data above this value are retained.

  mode=       : Type of data to threshold is automatically determined.
                1 First surface
                2 Bathymetry
                3 Bare earth)
                Mode overrides the automatic default.

Output:
  Output data array after threshold is applied for selected region.
*/
     //Automatically get mode if not set
   if (is_void(mode)) {
      a = nameof(structof(data));
      if (a == "FS") mode = 1;
      if (a == "GEO") mode = 2;
      if (a == "VEG__") mode = 3;
   }
   // convert maxthresh and minthresh to centimeters
   if (is_array(maxthresh)) maxthresh *= 100;
   if (is_array(minthresh)) minthresh *= 100;
   ply = getPoly();
   box = boundBox(ply);
   if ((mode == 1) || (mode == 2)) {
      box_pts = ptsInBox(box*100., data.east, data.north);
   } else {
      box_pts = ptsInBox(box*100., data.least, data.lnorth);
   }
   if (!is_array(box_pts)) return data;
   if ((mode == 1) || (mode == 2)) {
      poly_pts = testPoly(ply*100., data.east(box_pts), data.north(box_pts));
   } else {
      poly_pts = testPoly(ply*100., data.least(box_pts), data.lnorth(box_pts));
   }

   indx = box_pts(poly_pts);
   iindx = array(int,numberof(data.soe));
   if (is_array(indx)) iindx(indx) = 1;
   findx = where(iindx == 0);
   findata = data(findx);
   wdata = data(indx);
   norig = numberof(wdata);
   if (mode == 1) {
      if ((is_array(maxthresh)) & (is_array(minthresh))) {
         nidx = array(int, norig);
         idx = where((wdata.elevation < maxthresh) & (wdata.elevation > minthresh));
         nidx(idx) = 1;
         wdata = wdata(where(!nidx));
      } else {
         if (is_array(maxthresh)) wdata = wdata(where(wdata.elevation <= maxthresh));
         if (is_array(minthresh)) wdata = wdata(where(wdata.elevation >= minthresh));
      }
   }
   if (mode == 2) {
      if ((is_array(maxthresh)) & (is_array(minthresh))) {
         nidx = array(int, norig);
         idx = where(((wdata.elevation+wdata.depth) < maxthresh) & ((wdata.elevation+wdata.depth) > minthresh))
         nidx(idx) = 1;
         wdata = wdata(where(!nidx));
      } else {

         if (is_array(maxthresh)) wdata = wdata(where(wdata.elevation + wdata.depth <= maxthresh));
         if (is_array(minthresh)) wdata = wdata(where(wdata.elevation + wdata.depth >= minthresh));
      }
   }
   if (mode == 3) {
      if ((is_array(maxthresh)) & (is_array(minthresh))) {
         nidx = array(int, norig);
         idx = where((wdata.lelv < maxthresh) & (wdata.lelv > minthresh));
         nidx(idx) = 1;
         wdata = wdata(where(!nidx));
      } else {
         if (is_array(maxthresh)) wdata = wdata(where(wdata.lelv <= maxthresh));
         if (is_array(minthresh)) wdata = wdata(where(wdata.lelv <= minthresh));
      }
   }
   write, format="%d of %d points within selected region removed\n",norig-numberof(wdata), norig;
   grow, findata, wdata;
   return findata;
}

func batch_ddf(eaarl, cell=, minnum=) {
// Data density filter
   if (!minnum) minnum = 3;
   if (!cell) cell = 5;
   finaldata = [];
   mine = floor(eaarl.east(min)/5)*5/100.0;
   maxe =  ceil(eaarl.east(max)/5)*5/100.0;
   minn = floor(eaarl.north(min)/5)*5/100.0;
   maxn =  ceil(eaarl.north(max)/5)*5/100.0;
   for (i=mine;i<=maxe-cell;i+=cell) {
      swrite(format="Starting column: %i", int(i));
      coldata = data_box(eaarl.east/100.0, eaarl.north/100., i, i+cell, minn, maxn);
      if (numberof(coldata) <= minnum) {
         write, "No data in column!";
         continue;
      }
      for (j=minn;j<=maxn-cell;j+=cell) {
         boxdata = data_box(eaarl.east(coldata)/100.0, eaarl.north(coldata)/100., i, i+cell, j, j+cell);
         if (numberof(boxdata) <= 3) continue;
         grow, finaldata, coldata(boxdata);
      }
   }
   return finaldata;
   end
}

func spot_rcf(eaarl,dirname,mode,rcfmode,rgn=,buf=,w=,no_rcf=,fsmode=,wfs=,fw=,tw=,interactive=,tai=,plottriag=,plottriagwin=,prefilter_min=,prefilter_max=,distthresh=, datawin=, type=, plotbox=) {
/* DOCUMENT spot_rcf(eaarl, dirname, mode, rcfmode,
                     rgn=, buf=, w=, no_rcf=, fsmode=, wfs=, fw=, tw=,
                     interactive=, tai=, plottriag=, plottriagwin=,
                     prefilter_min=, prefilter_max=, distthresh=, datawin=,
                     type=)

This function re-filters a rectangular region in 'eaarl' and splices
it back into the original array.

Input:
  eaarl   : The array to be re-filtered

  dirname : The exact directory that holds the raw data of the region

  mode    : The filter mode.
            1 First surface
            2 Bathy
            3 Bare earth.

  rcfmode : Set to 1 to run the plain RCF filter
            Set to 2 to run the triangulation (IRCF) filter

  rgn=    : An array of the form [xmin, xmax, ymin, ymax] that defines
            the box to re-filter
            If not supplied the user will be asked to draw a box in the
            active window)

  buf=           :  Filtering options.
  w=             :  See rcffilter_eaarl_pts and/or
  no_rcf=        :      rcf_triag_filter for more information
  fsmode=        :
  wfs=           :
  fw=            :
  tw=            :
  interactive=   :
  tai=           :
  plottriag=     :
  plottriagwin=  :
  prefilter_min= :
  prefilter_max= :
  distthresh=    :
  datawin=       :

  type=          : The structure type of data.
                   Assumes GEO for mode=2 and VEG__ for mode=3
*/
   if (!(is_array(rgn))) {
      rgn = array(float, 4);
      a = mouse(1,1,
      "Hold the left mouse button down, select a region:");
      rgn(1) = min( [ a(1), a(3) ] );
      rgn(2) = max( [ a(1), a(3) ] );
      rgn(3) = min( [ a(2), a(4) ] );
      rgn(4) = max( [ a(2), a(4) ] );
   }
   xbuf=(rgn(2) - rgn(1))*0.05;
   ybuf=(rgn(4) - rgn(3))*0.05;
   xmin = rgn(1) - xbuf;
   xmax = rgn(2) + xbuf;
   ymin = rgn(3) - xbuf;
   ymax = rgn(4) + xbuf;
   oldrgn = rgn;
   rgn = [xmin, xmax, ymin, ymax];
   rawdata = sel_rgn_from_datatiles(junk,rgn=rgn,data_dir=dirname,mode=mode,onlynotrcfd=1,datum="w84", noplot=1);
   if (!is_array(rawdata)) {
      write, "Cannot find raw data for this region!";
      lance();
      return;
   }
   if (plotbox) {
      pldj, rgn(1), rgn(3), rgn(1), rgn(4), color="cyan";
      pldj, rgn(1), rgn(4), rgn(2), rgn(4), color="cyan";
      pldj, rgn(2), rgn(4), rgn(2), rgn(3), color="cyan";
      pldj, rgn(2), rgn(3), rgn(1), rgn(3), color="cyan";
   }
   rgn = oldrgn;
   if (rcfmode == 1) rcfdata = rcfilter_eaarl_pts(rawdata,buf=buf,w=w,mode=mode,no_rcf=no_rcf,fsmode=fsmode,wfs=wfs);
   if (rcfmode == 2) rcfdata = rcf_triag_filter(rawdata,buf=buf,w=w,mode=mode,no_rcf=no_rcf,fbuf=fbuf,fw=fw,tw=tw,interactive=interactive,tai=tai,plottriag=plottriag,plottriagwin=plottriagwin,prefilter_min=prefilter_min,prefilter_max=prefilter_max,distthresh=distthresh,datawin=datawin);
   if (!type) {
      if (mode == 2) type = GEO;
      if (mode == 3) type = VEG__;
   }
   keepdata = sel_data_rgn(eaarl,mode=4,exclude=1,rgn=rgn);
   if (!is_array(rcfdata)) {
      write, "Filter returned no points! This will leave a hole the data!";
      return keepdata;
   }
   rcfdata = rcfdata(data_box(rcfdata.east/100.0, rcfdata.north/100.0, rgn(1), rgn(2), rgn(3), rgn(4)));
   if (plotbox) {
      pldj, rgn(1), rgn(3), rgn(1), rgn(4), color="blue";
      pldj, rgn(1), rgn(4), rgn(2), rgn(4), color="blue";
      pldj, rgn(2), rgn(4), rgn(2), rgn(3), color="blue";
      pldj, rgn(2), rgn(3), rgn(1), rgn(3), color="blue";
   }
   if (!is_array(keepdata)) {
      write, "All old points were discarded!";
      return rcfdata;
   }
   data_out = array(type, numberof(keepdata)+numberof(rcfdata));
   data_out(1:numberof(keepdata)) = keepdata;
   data_out(numberof(keepdata)+1:0) = rcfdata;
   return data_out;
}
