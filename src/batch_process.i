// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";
/*
  Original: Amar Nayegandhi
  mbatch_process: Richard Mitchell
*/


func package_tile (q=, r=, typ=, min_e=, max_e=, min_n=, max_n= ) {

  ppath = swrite(format="/tmp/batch/prep/job-t_e%6.0f_n%7.0f_%s.cmd", min_e, max_n, zone_s);
  jpath = swrite(format="%s", "/tmp/batch/jobs/");
  save_vars, ppath, tile=1;
  cmd = swrite(format="mv %s %s", ppath, jpath);
  system, cmd;  // want the file to be fully there before the foreman sees it.
}


func package_rcf (ofn) {
  ofn_tail = file_tail(ofn(1));
  path = swrite(format="/tmp/batch/jobs/job-%s.cmd", ofn_tail);
  rcf_only = 1;
  b_rcf    = 1;

  default, update, 0;
  default, onlyupdate, update;
  default, write_merge, 0;

  update = onlyupdate;  // this ensures that both are the same if either are set.

  /*
  write, format="path        = %s\n", path;
  write, format="OFN         = %s\n", ofn(1);
  write, format="buf         = %d\n", buf;
  write, format="w           = %d\n", w;
  write, format="no_rcf      = %d\n", no_rcf;
  write, format="mode        = %d\n", mode;
  write, format="merge       = %d\n", merge;
  write, format="clean       = %d\n", clean;
  write, format="rcfmode     = %d\n", rcfmode;
  write, format="onlyupdate  = %d\n", onlyupdate;
  write, format="write_merge = %d\n", write_merge;
  */

  save_vars, path, tile=2;
}

func save_vars (filename, tile=) {
  myi   = strchr( filename, '/', last=1);  // get filename only
  pt  = strpart( filename, 1:myi);
  fn  = strpart( filename, myi+1:0 );
  tfn = swrite(format="%s.%s", pt, fn);
  cmd = swrite(format="mv %s %s", tfn, filename);
  f = createb( tfn );
  if ( ! get_typ ) get_typ = 0;
  default, initialdir, "/data/0";
  if ( tile == 1 ) {      // stuff for batch_process
    save, f, user_pc_NAME;
    save, f, q, r, min_e, max_e, min_n, max_n;
    save, f, get_typ, typ, auto;
    save, f, save_dir;
    save, f, zone, zone_s;
    save, f, dat_tag, mdate;
    save, f, iidx_path, indx_path, bool_arr, mtdt_path, mtdt_file;
    save, f, i, n;
    save, f, pbd;
    save, f, update;
    save, f, eaarl_time_offset;
  }
  if ( tile == 2 ) {      // stuff for batch_rcf only;
    save, f, rcf_only;   // flag value for uber_process_tile
    save, f, ofn;
    save, f, buf, w, no_rcf;
    save, f, mode;
    save, f, merge, clean;
    save, f, rcfmode;
    save, f, update;     // process_tile changes this back to onlyupdate
    save, f, write_merge;

  } else {

    save, f, edb_filename, pnav_filename, ins_filename;
    // save, f, tans, pnav, edb;    // save filenames instead
    save, f, edb_files;
    save, f, data_path;
    save, f, soe_day_start, eaarl_time_offset;
    save, f, ops_conf;
    save, f, curzone;
  }
  save, f, initialdir;

  // XYZZY - we need to save the batch_rcf parameters too!!
  if ( b_rcf == 1 ) {
    save,  f, b_rcf, buf, w, no_rcf, mode, merge, clean, rcfmode, write_merge;
  }
  save, f, forcechannel, bath_ctl, bath_ctl_chn4;

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

  return ( edb_files(myedb) );         // return list of names
 }

func unpackage_tile (fn=,host= ) {
  extern gga, pnav, tans;
  default, host, "localhost";
  default, rcf_only, 0;
  write, format="Unpackage_tile: %s %s\n", fn, host;
  f = openb(fn);
  restore, f;
  close, f;
  if ( ! strmatch(host, "localhost") ) {
    // We need to rsync the edb, pnav, and ins files from the server

    cmd = swrite(format="rsync -PHaqR %s:%s /", host, edb_filename);
    write, cmd;
    system, cmd;

    cmd = swrite(format="rsync -PHaqR %s:%s /", host, pnav_filename);
    write, cmd;
    system, cmd;

    cmd = swrite(format="rsync -PHaqR %s:%s /", host, ins_filename);
    write, cmd;
    system, cmd;

    afn  = swrite(format="%s.files", fn);
    af = open(afn, "w");
    write, af, format="%s\n", data_path;
  }

  oc = ops_conf;    // this gets wiped out by load_iexpbd, save now to restore later

  // We don't need these if only doing rcf
  if ( rcf_only != 1 ) {
    load_edb,  fn=edb_filename, verbose=0, override_offset = eaarl_time_offset;
    pnav = rbpnav( fn=pnav_filename, verbose=0);
    load_iexpbd,  ins_filename, verbose=0;
  }

  ops_conf = oc;

  if ( ! strmatch(host, "localhost") ) {
    // Get list of edb_files for this tile
    mytld = get_tld_names(q);
    for(myi=1; myi<=numberof(mytld); ++myi) {
      write, af, format="%s\n", mytld(myi);
    }
    // for(myi=1; myi<=numberof(myedb); ++myi) {
    //     write, af, format="%s\n", edb_files(myedb(myi)).name;
    // }

    close,af;
    cmd = swrite(format="/opt/alps/lidar-processing/scripts/check_for_tlds.pl %s %s", afn, host);
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
  uber_process_tile,q=q, r=r, typ=typ, min_e=min_e, max_e=max_e, min_n=min_n, max_n=max_n, host=host, rcf_only=rcf_only, forcechannel=forcechannel;
}


func uber_process_tile (q=, r=, typ=, min_e=, max_e=, min_n=, max_n=, host=, rcf_only=, forcechannel= ) {
  extern ofn;
  default, rcf_only, 0;

  // Make sure the output directory exits
  mkdirp, save_dir;

  if (is_array(r) || rcf_only == 1 ) {

    if ( rcf_only == 0 ) {
      // process_tile will return 0 if the tile needs to be updated
      update = process_tile (q=q, r=r, typ=typ, min_e=min_e, max_e=max_e, min_n=min_n, max_n=max_n, update=update, host=host, forcechannel=forcechannel );
    }

      mypath = ofn(1);
    if ( b_rcf ) {
      write, format="RCF path: %s\n", mypath;
      if ( ! strmatch(host, "localhost") ) {
        // Here we do need to make sure that we have all of the files
        // so they can be processed together.
        // XYZZY - This will result in errors from rsync when the
        // files don't exist on the server (probably most of the time)
        write, format="RCF: rsyncing %s:%s\n", host, mypath;
        cmd = swrite(format="rsync -PHauqR %s:%s /", host, mypath);
        write,  cmd;
        system, cmd;
        write, "rsync complete";
      }

      tile_id = swrite(format="t_e%6.0f_n%7.0f_%s_rcf",
        min_e, max_n, zone_s);

      batch_rcf, mypath, buf=buf, w=w, no_rcf=no_rcf, mode=typ+1, merge=merge, clean=clean, rcfmode=rcfmode, onlyupdate=update, write_merge=write_merge, tile_id=tile_id;
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

func process_tile (q=, r=, typ=, min_e=, max_e=, min_n=, max_n=, host=,update=, forcechannel= ) {
  extern ofn, _hgid;
  default, host, "localhost";
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
        write, format="Generating tile: %s\n", new_file;
        update=0;  // if the tile was updated, force rcf to process.
      }

      mkdirp, swrite(format="%si_e%d_n%d_%s", save_dir, idx_e, idx_n, zone_s);
      mkdirp, swrite(format="%si_e%d_n%d_%s/t_e%6.0f_n%7.0f_%s", save_dir, idx_e, idx_n, zone_s, min_e, max_n, zone_s);
      indx_num = where(mtdt_path == swrite(format="%si_e%d_n%d_%s/", save_dir, idx_e, idx_n, zone_s));
      indx_number = indx_num(1);
      if (bool_arr(indx_number) != 1) {
        f = open(mtdt_file(indx_number),"a");
        bool_arr(indx_number) = 1
        write, f, "Batch Processing Begins"
        write, f, timestamp();
        write, f, format="   on %s by %s\n\n",user_pc_NAME(1),user_pc_NAME(2);
        if(get_host() != user_pc_NAME(1))
          write, f, format="   batch processed on %s as %s\n", get_host(), get_user();
        if(!is_void(_hgid))
          write, f, format="   using repository revision %s\n", _hgid;
        if (!is_array(conf_file_lines)) write, f, format="PNAV FILE: %s\n",pnav_filename;
        if (typ == 1) {
          bconf = (forcechannel == 4) ? bath_ctl_chn4 : bath_ctl;
          write, f, "Bathymetry Constants: "
          write, f, format="Laser: %f\n",bconf.laser;
          write, f, format="Water: %f\n",bconf.water;
          write, f, format="AGC  : %f\n",bconf.agc;
          write, f, format="Threshold: %f\n",bconf.thresh;
          write, f, format="Last : %d\n",bconf.last;
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
        write, f, format="chn1_range_bias: %f\n", ops_conf.chn1_range_bias;
        write, f, format="chn2_range_bias: %f\n", ops_conf.chn2_range_bias;
        write, f, format="chn3_range_bias: %f\n", ops_conf.chn3_range_bias;

        close, f;
      }
    }
    // write metadata
    for (ij = 1; ij <=numberof(iidx_path); ij++) {

      // if you get an error here, it is most likely because you decided to use 'i'
      // elsewhere.
      // write, format="RWM: IJ(%d): %d / %d: %s\n", i, ij, numberof(iidx_path), indx_path(i);
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
      // fs_all = make_fs(latutm = 1, q = q,  ext_bad_att=1, use_centroid=1);
      fs_all = make_fs(latutm = 1, q = q,  ext_bad_att=1, forcechannel=forcechannel );
      if (is_array(fs_all)) {
        test_and_clean, fs_all;
        if (is_array(fs_all)) {
          if (edf) {
            write, format = "Writing edf file for Region %d of %d\n",i,n;
            edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_f.edf", fs_all;
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
        depth_all = make_bathy(latutm = 1, q = q,avg_surf=avg_surf, forcechannel=forcechannel);
        if (is_array(depth_all)){
          test_and_clean, depth_all;
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
              edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_b.edf", depth_all;
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
        veg_all = make_veg(latutm = 1, q = q, ext_bad_att=1, use_centroid=1, forcechannel=forcechannel);
        if (is_array(veg_all))  {
          test_and_clean, veg_all;
          if (is_array(veg_all)) {
            if (edf) {
              write, format = "Writing edf file for Region %d of %d\n",i,n;
              edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_v.edf", veg_all;
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
      depth_all = make_bathy(latutm = 1, q = q, forcechannel=forcechannel);
      if (is_array(depth_all)){
        test_and_clean, depth_all;
        if (is_array(depth_all)) {
          if (edf) {
            write, format = "Writing edf file for Region %d of %d\n",i,n;
            edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_b.edf", depth_all;
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
      veg_all = make_veg(latutm = 1, q = q, ext_bad_att=1, use_centroid=1, forcechannel=forcechannel);
      if (is_array(veg_all))  {
        test_and_clean, veg_all;
        if (is_array(veg_all)) {
          if (edf) {
            write, format = "Writing edf file for Region %d of %d\n",i,n;
            edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_v.edf", veg_all;
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

  return update;
}

// show progress of jobs completed.
func show_progress(color=) {
  default, color, "red";
  system, swrite(format="'%s' -rm /tmp/batch/done > /tmp/batch/.tiles",
    file_join(alpsrc.batcher_dir, "show_tiles.pl"));
  f = open("/tmp/batch/.tiles");

  col1= col2= col3= col4= array(0, 1000 /* max rows per column */ );
  read, f, col1, col2, col3, col4;
  close,f;

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
  window,6;  // seems to help in getting the status plot updated.
}

// Check space in batch area
func check_space(wmark=, dir=) {
  system, swrite(format="'%s' -noloop %d '%s' > /tmp/batch/.space",
    file_join(alpsrc.batcher_dir, "waiter.pl"), wmark, dir);
  f = open("/tmp/batch/.space");

  space= fc= array(0, 1 /* max rows per column */ );
  read, f, space, fc
  close,f;
  return ([space, fc]);
}

// batch_process is defined further below; it is dummied out here so that it
// inherits the same documentation as mbatch_process.
func batch_process {};
func mbatch_process(typ=, save_dir=, shem=, zone=, dat_tag=, cmdfile=, n=,
onlyplot=, mdate=, pbd=, edf=, win=, auto=, pick=, get_typ=, only_bathy=,
only_veg=, update=, avg_surf=,conf_file=, now=, b_rcf=, buf=, w=, no_rcf=,
mode=, merge=, clean=, rcfmode=, write_merge=, forcechannel=, shapefile=,
shp_buffer=) {
/* DOCUMENT mbatch_process, typ=, save_dir=, shem=, zone=, dat_tag=, cmdfile=,
  n=, onlyplot=, mdate=, pbd=, edf=, win=, auto=, pick=, get_typ=,
  only_bathy=, only_veg=, update=, avg_surf=,conf_file=, now=, b_rcf=, buf=,
  w=, no_rcf=, mode=, merge=, clean=, rcfmode=, write_merge=, forcechannel=,
  shapefile=, shp_buffer=

  batch_process, typ=, save_dir=, shem=, zone=, dat_tag=, cmdfile=, n=,
  onlyplot=, mdate=, pbd=, edf=, win=, auto=, pick=, get_typ=, only_bathy=,
  only_veg=, update=, avg_surf=,conf_file=, now=, forcechannel=, shapefile=,
  shp_buffer=

This function is used to batch process several regions for a given data set.
The regions are either defined by a command file or automatically choosen by
the program if auto=1.

For mbatch_process, auto= defaults to 1. This form of the function is intended
for batch usage. For batch_process, auto= defaults to 0. This form of the
function is intended for interactive usage. Otherwise, the two functions are
identical.

Input:
  typ=         : Type of data to process for
            0 for first surface
            1 for bathy
            2 for topo under veg

  save_dir=    : Directory name where the processed data will be written

  zone=        : Set to UTM zone number when using pick=1

  pick=        : Specifies how to select which data to process.
            1: draw a rubber-band box
            2: draw a polygon

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

  forcechannel= : Set to 1, 2, 3, or 4 to force the use of the specified
            channel. The mdate will have _chan1 or similar automatically
            appended to it if "_chan" is not already present in mdate.
            This can also be an array of channels, such as:
              forcechannel=[1,2,3,4]
            This will result in mbatch being recursively invoked once per
            channel, exactly as if you had called it once per channel
            sequentially yourself. Note that this is only really recommended
            for use alongside shapefile=. If you are using a mode that requires
            you to click-and-drag a region, you'll be prompted to do that once
            per channel.

  shapefile=    : Set to the path to a UTM ASCII shapefile containing a single
            polygon. This will be used for the boundary (and disables pick=).

  shp_buffer=   : If using shapefile=, this will place a buffer region around
          the imported boundary. The value is in meters. Note that this will
          also use the convex hull, so if your region has concavity, that
          concavity will be lost.

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
  if(numberof(forcechannel) > 1) {
    for(i = 1; i <= numberof(forcechannel); i++) {
      mbatch_process, typ=typ, save_dir=save_dir, shem=shem, zone=zone,
        dat_tag=dat_tag, cmdfile=cmdfile, n=n, onlyplot=onlyplot, mdate=mdate,
        pbd=pbd, edf=edf, win=win, auto=auto, pick=pick, get_typ=get_typ,
        only_bathy=only_bathy, only_veg=only_veg, update=update,
        avg_surf=avg_surf, conf_file=conf_file, now=now, b_rcf=b_rcf, buf=buf,
        w=w, no_rcf=no_rcf, mode=mode, merge=merge, clean=clean,
        rcfmode=rcfmode, write_merge=write_merge, forcechannel=forcechannel(i),
        shapefile=shapefile, shp_buffer=shp_buffer;
    }
    return;
  }

  extern pnav_filenam, bath_ctl, bath_ctl_chn4, _hgid;

  if(forcechannel && !strglob("*_chan*", mdate)) {
    mdate += swrite(format="_chan%d", forcechannel);
  }

  // start the timer
  t0 = array(double, 3);
  t1 = array(double, 3);
  timer, t0;
  myt0 = t0(3);
  write, format="Start Time: %f\n", t0(3);
  default, host, "localhost";
  default, now,  0;
  default, win,  6;
  window, win;

  eaarl_time_offset = 0;	// need this first, cuz get_erast uses it.
  eaarl_time_offset = edb(1).seconds - decode_raster( get_erast(rn=1) ).soe;


  // Create output directory for tile cmd files:
  system, "mkdir -p /tmp/batch/prep";
  system, "mkdir -p /tmp/batch/jobs";

  // Get username and pc name of person running batch_process
  user_pc_NAME = [get_host(), get_user()];

  // Make sure the output path ends in a /
  if ( strpart(save_dir, 0:0) != "/" ) save_dir += "/";
  // write, format="SAVE_DIR: %s\n", save_dir;

  if (zone) zone_s = swrite(format="%d", zone);
  //if (zone) pick=1;
  if (!pbd && !edf)      pbd      = 1;

  default, typ,         1;
  default, dat_tag, "w84";
  default, update,      0;
  default, avg_surf,    1;
  default, write_merge, 0;
  default, b_rcf,       0;

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
  if(!is_void(shapefile))
    pick = 2;
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
    if(!is_void(shapefile)) {
      ply = read_ascii_shapefile(shapefile);
      if(numberof(ply) != 1)
        error, "shapefile must contain exactly one polygon!";
      ply = *ply(1);
      if(shp_buffer)
        ply = buffer_hull(ply, shp_buffer);
    } else {
      ply=getPoly();
    }
    ply;
    plpoly, ply, marker=4;
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
      if(!is_void(_hgid))
        write, f, format="   using repository revision %s\n", _hgid;
      write, f, format="PNAV FILE: %s\n",pnav_filename;
      if (typ == 0) write, f, "Processing for First Surface Returns"
      if (typ == 1) {
        bconf = (forcechannel == 4) ? bath_ctl_chn4 : bath_ctl;
        write, f, "\nProcessing for Bathymetry";
        write, f, "Bathymetry Constants: ";
        write, f, format="Laser: %f\n",bconf.laser;
        write, f, format="Water: %f\n",bconf.water;
        write, f, format="AGC  : %f\n",bconf.agc;
        write, f, format="Threshold: %f\n",bconf.thresh;
        write, f, format="Last : %d\n",bconf.last;
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
      write, f, format="chn1_range_bias: %f\n", ops_conf.chn1_range_bias;
      write, f, format="chn2_range_bias: %f\n", ops_conf.chn2_range_bias;
      write, f, format="chn3_range_bias: %f\n", ops_conf.chn3_range_bias;

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
    q = pnav_sel_rgn(win=win, region=[min_e(i)-200.0, max_e(i)+200.0, min_n(i)-200.0, max_n(i)+200.0], _batch=1);
    // 2009-01-15: came across odd bug where q was:  <nuller>:
    // To avoid, check for numberof as well.
    if ( ! is_void(q) && numberof(q) > 0 ) {
      r = pnav_sel_rgn(win=win, color="green", region=[min_e(i), max_e(i), min_n(i), max_n(i)], _batch=1);
      if ( ! is_void(r) && numberof(r) > 0 ) {
        // Show the tile that is being prepared to be processed.
        pldj, min_e(i), min_n(i), min_e(i), max_n(i), color="blue"
        pldj, min_e(i), min_n(i), max_e(i), min_n(i), color="blue"
        pldj, max_e(i), min_n(i), max_e(i), max_n(i), color="blue"
        pldj, max_e(i), max_n(i), min_e(i), max_n(i), color="blue"

        if ( now == 0 ) {
          show_progress, color="green";

          // make sure we have space before creating more files
          system, swrite(format="'%s' 25000 /tmp/batch/jobs",
            file_join(alpsrc.batcher_dir, "waiter.pl"));
          package_tile(q=q, r=r, typ=typ, min_e=min_e(i), max_e=max_e(i), min_n=min_n(i), max_n=max_n(i) )
        } else {
          uber_process_tile(q=q, r=r, typ=typ, min_e=min_e(i), max_e=max_e(i), min_n=min_n(i), max_n=max_n(i), host=host, forcechannel=forcechannel )
        }
      }
    }
  }
  if ( now == 0 ) {
    // wait until no more jobs to be farmed out
    batch_cleanup;
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

func batch_process(typ=, save_dir=, shem=, zone=, dat_tag=, cmdfile=, n=,
onlyplot=, mdate=, pbd=, edf=, win=, auto=, pick=, get_typ=, only_bathy=,
only_veg=, update=, avg_surf=,conf_file=, now=, forcechannel=, shapefile=,
shp_buffer=) {
  default, now, 1;
  mbatch_process, typ=typ, save_dir=save_dir, shem=shem, zone=zone,
    dat_tag=dat_tag, cmdfile=cmdfile, n=n, onlyplot=onlyplot, mdate=mdate,
    pbd=pbd, edf=edf, win=win, auto=auto, pick=pick, get_typ=get_typ,
    only_bathy=only_bathy, only_veg=only_veg, update=update,
    avg_surf=avg_surv,conf_file=conf_file, now=now, forcechannel=forcechannel,
    shapefile=shapefile, shp_buffer=shp_buffer;
}


// This is called after mbatch_process() mbatch_process_dir() generates
// all of the tiles and then monitors the status of the work completed,
// coloring completed tiles green.
// This can also be called manually if ALPS gets restarted.
func batch_cleanup ( junk ) {
  // wait until no more jobs to be farmed out
  do {
    mya1 = check_space(wmark=8, dir="/tmp/batch/jobs");
    if ( mya1(2) > 0 ) write,format="%3d job(s) queued.\n", mya1(2);
    show_progress, color="green";

    mya2 = check_space (wmark=8, dir="/tmp/batch/farm");
    if ( mya2(2) > 0 ) write,format="%3d job(s) transferring.\n",  mya2(2);
    show_progress, color="green";

    mya3 = check_space (wmark=8, dir="/tmp/batch/work");
    if ( mya3(2) > 0 ) write,format="%3d job(s) processing.\n",   mya3(2);
    cnt = mya1(2) + mya2(2) + mya3(2);

  } while ( cnt(1) > 0 );
  write, "No batch jobs available.";
}

// process an output directory instead of a flightline.
// this will mostly be used for batch_rcf.

func mbatch_process_dir( dirname, buf=, w=, no_rcf=, mode=, merge=, clean=, rcfmode=, update=, onlyupdate=, write_merge=, searchstr=, selectmode=, win= ) {
/* DOCUMENT
func mbatch_process_dir( dirname, buf=, w=, no_rcf=, mode=, merge=, clean=,
                 rcfmode=, update=, onlyupdate=, write_merge=,
                 searchstr=, selectmode=, win= )

Uses the multi batch processing routines to process the files in a
sub-directory instead of using a bounding box in a map window.
Currently (2009-02) this is only useful for doing a batch_rcf(),
but could be expanded to other functions in the future.

All current options are from batch_rcf.
*/

  if ( !readedf  && !readpbd ) readpbd  = 1;
  if ( !writeedf && !writepbd) writepbd = 1;

  if ( !is_void(selectmode) ) {
    fn_all = select_datatiles(dirname, search_str=searchstr, mode=selectmode+1, win=win );
  } else {
write, format="Searching: %s\n", dirname;
    s = array(string, 10000);
    if ( is_array( searchstr ) ) {
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
write,format="For      : %s\n", ss;
    scmd = swrite(format = "find %s -name '%s'", dirname, ss);
    fp = 1; lp = 0;
    for ( i=1; i<=numberof(scmd); i++) {
      write,format="scmd(%d) = %s\n", i, scmd(i);
      f = popen(scmd(i), 0);
      n = read(f, format="%s", s);
      close, f;
      lp += n;
      if ( n ) fn_all = s(fp:lp);
      fp = fp + n;
    }

  }
  write, format="Found: %3d\n", numberof(fn_all);

  // XYZZY: we have a list of files, now we just want the dirnames they are in.
  dn_all = file_dirname(fn_all);
  dn_all = dn_all(unique(dn_all));
  n      = numberof(dn_all);
  write, format="Dirs : %3d\n", n;

  // loop to generate batch jobs
  for ( i=1; i<=n; ++i ) {
    // make sure we have space
    system, swrite(format="'%s' 25000 /tmp/batch/jobs",
      file_join(alpsrc.batcher_dir, "waiter.pl"));
    package_rcf, dn_all(i);
    show_progress, color="green";
  }

  // loop to wait until all jobs are done.
  batch_cleanup;
  write,"Batch RCF Process Complete.";
}

// a simple routine to display a list of file names for debugging.
func show_files(files=, str=) {
  n = numberof(files);
  for ( i=1; i<=n; ++i ) {
   write, format="FILES(%s): %2d/%2d: %s\n", str, i, n, files(i);
  }
}

func batch_rcf(dirname, fname=, buf=, w=, tw=, fbuf=, fw=, no_rcf=, mode=, meta=, prefilter_min=, prefilter_max=, clean=, merge=, write_merge=, readedf=, readpbd=, writeedf=, writepbd=, rcfmode=, datum=, fsmode=, wfs=, searchstr=, bmode=, interactive=, onlyupdate=, selectmode=, tile_id=) {
/* DOCUMENT
func batch_rcf(dirname, fname=, buf=, w=, tw=, fbuf=, fw=, no_rcf=, mode=,
          meta=, prefilter_min=, prefilter_max=, clean=, merge=, write_merge=,
          readedf=, readpbd=, writeedf=, writepbd=, rcfmode=, datum=, fsmode=,
          wfs=, searchstr=, bmode=, interactive=, onlyupdate=)

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

  searchstr= : Search string for the file names. Default = "*_v.pbd"
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

  t0 = t1 = tp = array(double, 3);
  timer, t0;
  extern fn_all, noaa_data, ofn;

  if (!readedf && !readpbd) readpbd = 1;
  if (!writeedf && !writepbd) writepbd = 1;
  if (!buf) buf = 700;
  if (!w) w = 200;
  if (!no_rcf) no_rcf = 3;
  if (!meta) meta = 1;
  if (!clean) clean = 1;
  default, dorcf, 1;
  if (!mode) mode=2;
  default, bmode,   1;
  default, rcfmode, 2;
  default, merge,   1;
  default, searchstr, "*.pbd";
  if (interactive) {plottriag = 1; datawin=5;}

  // Gather list of filenames

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
          ss = ["*.bin", "*.edf"];
        }
        if (readpbd) {
          ss = ["*.pbd"];
        }
        if(datum) {
          ss = "*" + datum + ss;
        }
      }
      // write, format="DIRNAME: %s%s\n", dirname, ss;
      fn_all = find(dirname, glob=ss);
    }
  }
  if (!is_array(fn_all))
    exit,"No input files found.  Goodbye.";

  // Determine existing files; filter file list by type

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

  if (merge) {
    // do not include merged files
    mgd_idx = strmatch(fn_all,"merged",1);
    fn_all = fn_all(where(!mgd_idx));
    fn_arr = fn_all;
    // show_files, files=fn_all, str="FIRST";

    nfiles = numberof(fn_all);
    write, format="Total number of files to RCF = %d\n",nfiles;

    // merge files within each data tile
    tile_dir   = array(string, numberof(fn_all));
    all_dir    = array(string, numberof(fn_all));
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

    if ( b_rcf ) {
      if (readpbd) {
        write, "merging all eaarl pbd data";
        show_files(files=fn_arr, str="Merge");
        all_eaarl = dirload(files=fn_arr);
        if(clean)
          test_and_clean, all_eaarl;
      }
    }
  }

  nfiles = numberof(fn_all);
  // write, format="Total number of files to RCF = %d\n",nfiles;

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
        if(datum)
          data_edf = dirload(fn_split(1), searchstr="*"+datum+"*"+searchstr+"*.edf");
        else
          data_edf = dirload(fn_split(1), searchstr="*"+searchstr+"*.edf");
      }
      if (readpbd) {
        if ( b_rcf ) {
          if (bmode == 1) {
            fmeast = fmnorth = 0;
            sread, strpart(fn_split(2), 4:9), fmeast;
            sread, strpart(fn_split(2), 12:18), fmnorth;
            didx = data_box(all_eaarl.east/100., all_eaarl.north/100., fmeast-350, fmeast+2350, fmnorth-2350, fmnorth+350);
            if (is_array(didx)) {
              eaarl = all_eaarl(didx);
            } else continue;
          }
        } else {
          write, format="merging eaarl pbd data in directory %s\n",fn_split(1);
          if (datum) {
            eaarl = dirload(fn_split(1), searchstr="*"+datum+"*"+searchstr+".pbd");
          } else {
            eaarl = dirload(fn_split(1), searchstr="*"+searchstr+"*");
          }

        }
      }
    } else {
      if (readedf)
        data_edf = edf_import(fn_all(i));
      if (readpbd)
        eaarl = pbd_load(fn_all(i));
    }
    if (readedf)
      grow, eaarl, data_edf;
    if(clean && !(merged && readpbd))
      test_and_clean, eaarl;
    data_edf = [];
    if (bmode == 1 && ! (merge && readpbd)) {
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
    if (!is_array(eaarl)) continue;

    if(write_merge==1) {
      dirload, fn_split(1), searchstr="*"+searchstr+"*",
        outvname="merged_v", outfile=file_rootname(fn_all(i))+"_merged.pbd";
    }

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
      if (rcfmode == 1) rcf_eaarl = rcf_filter_eaarl(eaarl, buf=buf, w=w, mode=["fs","ba","be"](mode), n=no_rcf, rcfmode="grcf");
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
          edf_export, file_join(res(1), res(2)), rcf_eaarl;
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
          edf_export, file_join(res(1), res(2)), rcf_eaarl;
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
          edf_export, file_join(res(1), res(2)), rcf_eaarl;
        }
        if (writepbd) {
          // use tile_id when run from mbatch_process() as 'i' is always 1.
          if ( tile_id ) {
            vname = "bet"+vnametag+"_"+tile_id;
          } else {
            vname = "bet"+vnametag+"_"+swrite(format="%d",i);
          }
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

func new_batch_rcf(dir, searchstr=, merge=, files=, update=, mode=, clean=,
prefilter_min=, prefilter_max=, rcfmode=, buf=, w=, n=, meta=, verbose=) {
/* DOCUMENT new_batch_rcf, dir, searchstr=, merge=, files=, update=, mode=,
  clean=, prefilter_min=, prefilter_max=, rcfmode=, buf=, w=, n=, meta=,
  verbose=

  This is a rewritten batch_rcf function. It iterates over each file in a set
  of files and applies an RCF filter to its data.

  This function has many changes with respect to batch_rcf, as noted after the
  parameters and options below.

  Parameters:
    dir: The directory containing the files you wish to filter.

  Options:
    searchstr= The search string to use to locate the files you with to
      filter. Examples:
        searchstr="*.pbd"    (default)
        searchstr="*_v.pbd"
        searchstr="*n88*_v.pbd"

    merge= This is a special-case convenience setting that includes a call to
      batch_automerge_tiles. It can only be run if your search string ends
      with _v.pbd or _b.pbd. After running the merge, the search string will
      get updated to replace _v.pbd with _v_merged.pbd and _b.pbd with
      _b_merged.pbd. (So "*_v.pbd" becomes "*_v_merged.pbd", whereas
      "*w84*_v.pbd" becomes "*w84*_v_merged.pbd".) It is an error to use
      this setting with a search string that does not fit these
      requirements. Note that you CAN NOT "skip" the writing of merged files
      if you want to filter merged data. Settings:
        merge=0     Do not perform an automerge. (default)
        merge=1     Merge tiles together before filtering.

    files= Manually provides a list of files to filter. This will result in
      searchstr= being ignored and is not compatible with merge=1.

    update= Specifies that this is an update run and that existing files
      should be skipped. Settings:
        update=0    Overwrite output files if they exist.
        update=1    Skip output files if they exist.

    mode= Specifies which data mode to use for the data. Can be any setting
      valid for data2xyz.
        mode="fs"   First surface (default)
        mode="be"   Bare earth
        mode="ba"   Bathymetry (submerged topo)

    clean= Specifies whether the data should be cleaned first using
      test_and_clean. Settings:
        clean=0     Do not clean the data.
        clean=1     Clean the data. (default)

    prefilter_min= Specifies a minimum value for the elevation values, in
      meters. Points below this value are discarded prior to filtering.

    prefilter_max= Specifies a maximum value for the elevation values, in
      meters. Points above this value are discarded prior to filtering.

    rcfmode= Specifies which rcf filter function to use. Possible settings:
        rcfmode="grcf"    Use gridded_rcf (default)
        rcfmode="rcf"     Use old_gridded_rcf (deprecated)

    buf= Defines the size of the x/y neighborhood the filter uses, in
      centimeters. Default is 700cm.

    w= Defines the size of the vertical (z) window the filter uses, in
      centimeters. Default is 200cm.

    n= Defines the minimum number of points that are required in a window in
      order to count as successful. Default is 3.

    meta= Specifies whether the filter parameters should be included in the
      output filename. Settings:
        meta=0   Do not include the filter parameters in the file name.
        meta=1   Include the filter parameters in the file name. (default)

    verbose= Specifies how talkative the function should be as it runs. Valid
      settings:
        verbose=2   Lots of output, will scroll your window. (default)
        verbose=1   Minimal output, just a basic progress line, no scroll.
        verbose=0   Be completely silent.

  Changes from batch_rcf:

    No support for edf files. The readedf=, readpbd=, writeedf=, and
    writepbd= options are thus not included.

    The no_rcf= parameter is now just n=.

    The mode= parameter is now "fs" instead of 1, etc.

    The fname= parameter is replaced by files=.

    No support for merging *without* writing the merged files.

    No support for merging without filtering. Use batch_automerge_tiles or
    batch_merge_tiles for that.

    The rcfmode= parameter accepts different settings and defaults to the new
    gridded_rcf logic. No support yet for the triangulation filter (ircf).

    There is no datum= option; the filtering is blind to datums.

    There is no fsmode= or wfs= option; the combined first surface/bare earth
    filtering is no longer in use. They are filtered separately now to avoid
    unnecessary sparseness in the results.

    There is no bmode= option.

    The onlyupdate= option is now named update=.

    There is no selectmode= option.
*/
// Original David Nagle 2009-12-28
  default, searchstr, "*.pbd";
  default, verbose, 2;
  default, update, 0;
  default, merge, 0;
  default, buf, 700;
  default, w, 200;
  default, n, 3;
  default, clean, 1;
  default, meta, 1;
  default, mode, "fs";
  default, rcfmode, "grcf";

  timing = elapsed = array(double, 3);
  timer, timing;

  if(merge) {
    if(!is_void(files))
      error, "You cannot use merge=1 if you are specifying files=."
    // We can ONLY merge if our searchstr ends with *_v.pbd or *_b.pbd.
    // If it does... then merge, and update our search string.
    if(strlen(searchstr) < 7)
      error, "Incompatible setting for searchstr= with merge=1. See \
        documentation.";
    ss1 = strpart(searchstr, :-6);
    ss2 = strpart(searchstr, -6:);
    if(ss2 == "*_v.pbd") {
      batch_automerge_tiles, dir, searchstr=searchstr, verbose=verbose > 0,
        update=update;
      searchstr = ss1 + "_v_merged.pbd";
    } else if(ss2 == "*_b.pbd") {
      batch_automerge_tiles, dir, searchstr=searchstr, verbose=verbose > 0,
        update=update;
      searchstr = ss1 + "_b_merged.pbd";
    } else {
      error, "Invalid setting for searchstr= with merge=1. See \
        documentation."
    }
  }

  if(is_void(files))
    files = find(dir, glob=searchstr);
  count = numberof(files);

  if(!count) {
    if(verbose)
      write, "No files found, nothing to do... Goodbye!";
    return;
  }

  // Variable name -- same as input, but add _rcf (or _grcf, etc.)
  // File name -- same as input, but lop off extension and add rcf settings
  vname = [];
  if(count > 1)
    sizes = file_size(files)(cum)(2:);
  else
    sizes = file_size(files);
  status, start, msg="Batch RCF...";
  for(i = 1; i <= count; i++) {
    file_in = files(i);
    file_out = file_rootname(file_in);
    // _fs, _be, _ba
    file_out += "_" + mode;
    // _b700_w50_n3
    if(meta)
      file_out += swrite(format="_b%d_w%d_n%d", buf, w, n);
    // _grcf, _ircf, _rcf
    file_out += "_" + rcfmode;
    // _mf
    // .pbd
    file_out += ".pbd";

    if(verbose)
      write, format="%s%d/%d: %s%s",
          (verbose > 1 ? "\n" : ""),
          i, count, file_tail(file_out),
          (verbose > 1 ? "\n " : "\r");

    if(update && file_exists(file_out)) {
      if(verbose > 1)
        write, format="  already exists%s", "\n";
      continue;
    }

    rcf_filter_eaarl_file, file_in, file_out, mode=mode, clean=clean,
        rcfmode=rcfmode, buf=buf, w=w, n=n, prefilter_min=prefilter_min,
        prefilter_max=prefilter_max, verbose=(verbose > 1);
    status, progress, sizes(i), sizes(0);
  }
  status, finished;

  if(verbose == 1)
    write, format="%s", "\n";

  timer, timing, elapsed;
  if(verbose > 1)
    write, format="Finished in %s\n", seconds2prettytime(elapsed(3));
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
  if (rcfmode == 1) rcfdata = rcf_filter_eaarl(rawdata, buf=buf, w=w, mode=["fs","ba","be"](mode), n=no_rcf, rcfmode="grcf");
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

func batch_automerge_tiles(path, searchstr=, verbose=, update=) {
/* DOCUMENT batch_automerge_tiles(path, searchstr=, verbose=, update=)
  Specialized batch merging function for the initial merge of processed data.

  By default, it will find all files matching *_v.pbd and *_b.pbd. It will
  then merge everything it can. It makes distinctions between _v and _b, and
  it also makes distinctions between w84, n88, n88_g03, n88_g09, etc. Thus,
  it's safe to run on a directory containing both veg and bathy or both w84
  and n88; they won't all get mixed together inappropriately.

  Parameters:
    path: The path to the directory.

  Options:
    searchstr= You can override the default search string if you're only
      interested in merging some of the available files. However, if your
      search string matches things that this function isn't designed to
      handle, it won't handle them. Examples:
        searchstr=["*_v.pbd", "*_b.pbd"]    Find all _v and _b files (default)
        searchstr="*_b.pbd"                 Find only _b files
        searchstr="*w84*_v.pbd"             Find only w84 _v files
      Note that searchstr= can be an array for this function, if need be.

    verbose= Specifies how chatty the function should be. Settings:
        verbose=0      Be silent
        verbose=1      Provide progress and information to the screen

    update= By default, existing files are overwritten. Using update=1 will
      skip them instead.
        update=0    Overwrite files if they exist
        update=1    Skip files if they exist

  Output:
    This will create the merged files in the directory specified, alongside
    the input files.

    An example output filename is:
      t_e352000_n3006000_17_w84_b_merged.pbd
    The tile name, datum (w84, etc.), and type (v, b) will vary based on the
    files merged.

    An example vname is:
      e352_n3006_w84_b
    Again, the information will vary based on the files merged.
*/
  default, searchstr, ["*_v.pbd", "*_b.pbd"];
  default, verbose, 1;
  default, update, 0;

  // Locate files and split into dirs/tails
  files = find(path, glob=searchstr);
  dirs = file_dirname(files);
  tails = file_tail(files);

  // Extract tile names
  tiles = extract_tile(tails, dtlength="long", qqprefix=0);

  // Break up into _v/_b
  types = array(string, numberof(files));
  w = where(strglob("*_v.pbd", tails));
  if(numberof(w))
    types(w) = "v";
  w = where(strglob("*_b.pbd", tails));
  if(numberof(w))
    types(w) = "b";

  // Break up into w84, n88, etc.
  parsed = parse_datum(tails);
  datums = parsed(..,1);
  geoids = parsed(..,2);
  parsed = [];

  // Check for problems
  problem = strlen(tiles) == 0 | strlen(types) == 0 | strlen(datums) == 0;
  if(anyof(problem)) {
    w = where(problem);
    if(verbose) {
      write, format="\nFound %d problem files that were non-parseable and will \
        be skipped:\n", numberof(w);
      write, format=" - %s\n", tails(w);
    }
    if(allof(problem)) {
      if(verbose)
        write, format="All files were skipped. Aborting.%s", "\n";
      return;
    } else {
      w = where(!problem);
      files = files(w);
      tails = tails(w);
      tiles = tiles(w);
      datums = datums(w);
      geoids = geoids(w);
    }
  }

  // Calculate filename suffix
  suffixes = swrite(format="%s_%s_%s_merged.pbd", datums, geoids, types);
  suffixes = regsub("__*", suffixes, "_", all=1);

  // Calculate output filenames
  tokens = swrite(format="%s_%s", tiles, suffixes);
  tokens = regsub("__*", tokens, "_", all=1);
  outfiles = file_join(dirs, tokens);
  dirs = [];

  // Check for files that already exist
  exists = file_exists(outfiles);
  if(anyof(exists)) {
    w = where(exists);
    existout = set_remove_duplicates(outfiles(w));
    if(verbose) {
      write, format="\nFound %d output files that already exist. %s\n",
        numberof(existout), (update ? "Skipping." : "Overwriting.");
      write, format=" - %s\n", file_tail(existout);
    }
    if(update) {
      if(allof(exists)) {
        if(verbose)
          write, format="All files were skipped. Aborting.%s", "\n";
        return;
      } else {
        w = where(!exists);
        outfiles = outfiles(w);
        files = files(w);
        tiles = tiles(w);
        types = types(w);
        datums = datums(w);
        geoids = geoids(w);
        suffixes = suffixes(w);
      }
    }
  }

  // Calculate variable names
  tiles = extract_tile(tiles, dtlength="short", qqprefix=1);
  // Lop off zone for 2k/10k tiles
  tiles = regsub("_[0-9]+$", tiles, "");
  vnames = swrite(format="%s_%s_%s", tiles, datums, types);
  tiles = datums = types = geoids = [];

  // Sort by output file name
  srt = sort(outfiles);
  files = files(srt);
  suffixes = suffixes(srt);
  outfiles = outfiles(srt);
  vnames = vnames(srt);
  srt = [];

  count = numberof(files);

  suffixes = set_remove_duplicates(suffixes);
  nsuf = numberof(suffixes);
  outuniq = numberof(set_remove_duplicates(outfiles));
  if(verbose) {
    write, format="\nCreating %d set%s of merged files:\n", nsuf,
      (nsuf > 1 ? "s" : "");
    write, format=" - *%s\n", suffixes;
    write, format="\nMerging %d input files into %d output files...\n",
      count, outuniq;
  }

  // Iterate through and load each file, saving whenever we're on the input
  // file for a given output file.
  tstamp = [];
  timer_init, tstamp;
  i = j = k = 1;
  while(i <= count) {
    if(verbose)
      timer_tick, tstamp, k, outuniq;
    while(j < count && outfiles(j+1) == outfiles(i))
      j++;
    dirload, files=files(i:j), outfile=outfiles(i), outvname=vnames(i), uniq=0,
      soesort=1, skip=1, verbose=0;
    i = j = j + 1;
    k++;
  }
}

func batch_merge_tiles(path, searchstr=, file_suffix=, vname_suffix=,
verbose=, update=) {
/* DOCUMENT batch_merge_tiles, path, searchstr=, file_suffix=, vname_suffix=,
  verbose=, update=

  Performs a batch merge over data that has been stored in a tiled format.

  This will work for data stored in data tiles, index tiles, or quarter quads.
  All files found for each tile will be merged together. If a file does not
  have a parseable tile in its filename, it will be skipped.

  All input files for a given tile must contain data in the same structure,
  otherwise errors will ensue.

  Parameters:
    path: The path to the data.

  Options:
    searchstr= The search string to use to find your data. Examples:
        searchstr="*.pbd"    All pbd data (default)
        searchstr="*_v.pbd"  All veg data

    file_suffix= The suffix to append to the tile names when creating the
      merged output filename. Be sure to include the extension. Examples:
        file_suffix="_merged.pbd"        (default)
        file_suffix="_w84_v_merged.pbd"

    vname_suffix= The suffix to append to the tile names when creating the
      merged vname for the output file. Examples:
        vname_suffix="_merged"     (default)
        vname_suffix="_v_merged"

    verbose= Specifies whether output information should be given as its
      processes. Possible settings:
        verbose=0      Be silent.
        verbose=1      Give progress. (default)

    update= Turns on update mode, which skips existing files. Possible
      settings:
        update=0    Existing files are overwritten
        update=1    Existing files are skipped

  Each of the three kinds of tiles has a different set of conventions that
  governs how their filenames and vnames are constructed, as follows.

  Data tiles (2km):
    The file name will start with the long form of the tile name. The vname
    will start with the short form of the tile name. Using the default
    settings, a merged tile might get this for its output:
      output filename = t_e652000_n4504000_18_merged.pbd
      output vname = e652_n4504_18_merged

  Index tiles (10km):
    Index tile names only have one form, which is what gets used. Using
    default settings, a merged tile might get this as its output:
      output filename = i_e640000_n4510000_18_merged.pbd
      output vname = i_e640000_n4510000_18_merged

  Quarter quads:
    The file name will start with the normal form of the tile name. The vname
    will start with the qq-prefixed form. Using the default settings, a
    merged tile might result in this:
      output filename = 29085h4b_merged.pbd
      output vname = qq29085h4b_merged
*/
// Original David Nagle 2009-12-24
  default, searchstr, "*.pbd";
  default, file_suffix, "_merged.pbd";
  default, vname_suffix, "_merged";
  default, verbose, 1;
  default, update, 0;

  files_in = find(path, glob=searchstr);
  if(is_void(files_in)) {
    if(verbose)
      write, "No files found. Giving up!";
    return;
  }

  tiles = extract_tile(file_tail(files_in), dtlength="long", qqprefix=0);

  w = where(!tiles);
  if(numberof(w)) {
    if(verbose) {
      write, format=" Couldn't parse tile information for %d files:\n", numberof(w);
      write, format="  %s\n", file_tail(files_in(w));
    }
  }
  w = where(tiles);
  if(is_void(w)) {
    if(verbose)
      write, "Couldn't parse tile information for any files. Giving up!";
    return;
  }
  files_in = files_in(w);
  tiles = tiles(w);

  files_out = file_join(file_dirname(files_in), tiles + file_suffix);

  uniq_out = set_remove_duplicates(files_out);
  numout = numberof(uniq_out);

  tstamp = 0;
  timer_init, tstamp;
  for(i = 1; i <= numout; i++) {
    if(verbose)
      timer_tick, tstamp, i, numout;

    cur_out = uniq_out(i);

    if(update && file_exists(cur_out))
      continue;

    w = where(files_out == cur_out);

    vname = extract_tile(file_tail(cur_out), dtlength="short", qqprefix=1);
    vname += vname_suffix;

    dirload, files=files_in(w), outfile=cur_out, outvname=vname, uniq=1,
      skip=1, verbose=0;
  }
}

func batch_merge_veg_bathy(path, veg_ss=, bathy_ss=, file_suffix=, progress=,
ignore_none_found=) {
/* DOCUMENT batch_merge_veg_bathy, path, veg_ss=, bathy_ss=, file_suffix=,
  progress=, ignore_none_found=

  Performs a batch merge on the veg and bathy files found in path, creating
  seamless files.

  For tiles that have both a veg and a bathy file, the data from each file
  will be merged and a seamless file will be created. If only veg is present,
  it is copied to the seamless file. If only bathy is present, it is converted
  to VEG__ a seamless file will be created.

  Parameters:
    path: The path to the directory containing the veg and bathy files.
      (Normally an Index_Tiles directory.)

  Options:
    veg_ss= The search string to use for the veg files. Defaults to
      "*n88*mf_str.pbd".
    bathy_ss= The search string to use for the bathy files. Defaults to
      "*n88*_b_*mf.pbd"
    file_suffix= Specifies how the files will be named. This is appended to
      the tile's name to create a filename. Defaults to
      "n88_merged_seamless.pbd".
    progress= By default, progress is shown using a simple counter. Set
      progress=0 to silence that output.
    ignore_none_found= By default, the function will abort if it doesn't find
      some of both kinds of files (veg and bathy). Setting
      ignore_none_found=1 will force it to generate seamless files even if
      only one kind is present.
*/
// Original David Nagle 2009-06-16
  default, veg_ss, "*n88*mf_str.pbd";
  default, bathy_ss, "*n88*_b_*mf.pbd";
  default, file_suffix, "n88_merged_seamless.pbd";
  default, ignore_none_found, 0;
  default, progress, 1;

  v_files = find(path, glob=veg_ss);
  b_files = find(path, glob=bathy_ss);

  if(!numberof(v_files) && !numberof(b_files)) {
    write, "No veg or bathy files found. Aborting.";
    return;
  } else if(!numberof(v_files) && !ignore_none_found) {
    write, "No veg files found. Aborting.";
    write, "Use ignore_none_found=1 to force.";
    return;
  } else if(!numberof(b_files) && !ignore_none_found) {
    write, "No bathy files found. Aborting.";
    write, "Use ignore_none_found=1 to force.";
    return;
  }

  v_dt = numberof(v_files) ? extract_dt(file_tail(v_files), dtlength="long") : [];
  b_dt = numberof(b_files) ? extract_dt(file_tail(b_files), dtlength="long") : [];
  s_dt = set_union(v_dt, b_dt);

  tstamp = 0;
  timer_init, tstamp;
  for(i = 1; i <= numberof(s_dt); i++) {
    if(progress)
      timer_tick, tstamp, i, numberof(s_dt);
    this_tile = s_dt(i);

    seamless_file = string(0);

    vw = where(v_dt == this_tile);
    if(numberof(vw) == 1) {
      vw = vw(1);
      f = openb(v_files(vw));
      v_data = get_member(f, f.vname);
      close, f;

      seamless_file = file_join(
        file_dirname(v_files(vw)),
        this_tile + "_" + file_suffix
      );
    } else if(numberof(vw) > 1) {
      error, "Found multiple veg files for tile " + this_tile;
    } else {
      v_data = [];
    }

    bw = where(b_dt == this_tile);
    if(numberof(bw) == 1) {
      bw = bw(1);
      f = openb(b_files(bw));
      b_data = get_member(f, f.vname);
      close, f;

      if(!seamless_file)
        seamless_file = file_join(
          file_dirname(b_files(bw)),
          this_tile + "_" + file_suffix
        );
    } else if(numberof(bw) > 1) {
      error, "Found multiple bathy files for tile " + this_tile;
    } else {
      b_data = [];
    }

    seamless_data = merge_veg_bathy(v_data, b_data);
    vname = "smls_" + extract_dt(this_tile);

    f = createb(seamless_file);
    save, f, vname;
    add_variable, f, -1, vname, structof(seamless_data), dimsof(seamless_data);
    get_member(f, vname) = seamless_data;
    close, f;
  }
}

func show_setup ( junk ) {
  write, format="EDB\n  %s\n", edb_filename;
  write, format="\n%s\n  %s\n  %s\n", "PNAV",
    split_path(pnav_filename,0)(1);
    split_path(pnav_filename,0)(0);
  write, format="\n%s\n  %s\n  %s\n", "INS",
    split_path(ins_filename,0)(1);
    split_path(ins_filename,0)(0);
  write, format="\nDATA PATH\n  %s\n", data_path;
}
