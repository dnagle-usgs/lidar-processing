// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "logger.i";

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
  save, f, plugins="eaarlb";
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
  save, f, ext_bad_att, forcechannel, bath_ctl, bath_ctl_chn4;

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
    cmd = swrite(format="/opt/alps/lidar-processing/scripts/check_for_tlds.pl %s %s %s",
        afn,
        host,
        file_tail(file_dirname(edb_filename)) );
    write, cmd;
    system, cmd;
    write, format="Unpackage_Tile(%s): %s: done\n", host, cmd;
  }
  write, format="Unpackage_Tile(%s): %s: done\n", host, fn;
}

func call_process_tile( junk=, host= ) {
  // write, format="t_e%6.0f_n%7.0f_%s\n", min_e, max_n, zone_s;
  uber_process_tile,q=q, r=r, typ=typ, min_e=min_e, max_e=max_e, min_n=min_n, max_n=max_n, host=host, rcf_only=rcf_only, ext_bad_att=ext_bad_att, forcechannel=forcechannel;
}


func uber_process_tile (q=, r=, typ=, min_e=, max_e=, min_n=, max_n=, host=, rcf_only=, ext_bad_att=, forcechannel= ) {
  extern ofn;
  default, rcf_only, 0;

  // Make sure the output directory exits
  mkdirp, save_dir;

  if (is_array(r) || rcf_only == 1 ) {

    if ( rcf_only == 0 ) {
      // process_tile will return 0 if the tile needs to be updated
      update = process_tile (q=q, r=r, typ=typ, min_e=min_e, max_e=max_e, min_n=min_n, max_n=max_n, update=update, host=host, ext_bad_att=ext_bad_att, forcechannel=forcechannel );
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

      batch_rcf, mypath, buf=buf, w=w, no_rcf=no_rcf, mode=typ+1, merge=merge, rcfmode=rcfmode, onlyupdate=update, write_merge=write_merge, tile_id=tile_id;
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

func process_tile (q=, r=, typ=, min_e=, max_e=, min_n=, max_n=, host=,update=, ext_bad_att=, forcechannel= ) {
  extern ofn, _hgid, get_typ, auto;
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering process_tile";
    logger, debug, log_id+"Called with params:";
    logger, debug, log_id+"  q="+pr1(q);
    logger, debug, log_id+"  r="+pr1(r);
    logger, debug, log_id+"  typ="+pr1(typ);
    logger, debug, log_id+"  min_e="+pr1(min_e);
    logger, debug, log_id+"  max_e="+pr1(max_e);
    logger, debug, log_id+"  min_n="+pr1(min_n);
    logger, debug, log_id+"  max_n="+pr1(max_n);
    logger, debug, log_id+"  host="+pr1(host);
    logger, debug, log_id+"  update="+pr1(update);
    logger, debug, log_id+"  ext_bad_att="+pr1(ext_bad_att);
    logger, debug, log_id+"  forcechannel="+pr1(forcechannel);
    logger, debug, log_id+"Externs:";
    logger, debug, log_id+"  ofn="+pr1(ofn);
    logger, debug, log_id+"  _hgid="+pr1(_hgid);
    logger, debug, log_id+"  get_typ="+pr1(get_typ);
    logger, debug, log_id+"  auto="+pr1(auto);
  }
  default, host, "localhost";
    if (get_typ) {
      if(logger(debug)) logger, debug, log_id+"get_typ enabled";
      typ=[]
      typ_idx = where(tile.min_e == min_e);
      if (is_array(typ_idx)) typ_idx2 = where(tile.max_n(typ_idx) == max_n);
      if (is_array(typ_idx2)) typ = [tile.typ(typ_idx(typ_idx2))](1);
      if (!typ) typ = typer(min_e, max_e, min_n, max_n, zone);
      if(logger(debug)) logger, debug, log_id+"typ="+pr1(typ);
    }
    if (auto) {
      if(logger(debug)) logger, debug, log_id+"auto enabled";
      idx_e = long(10000 * long(min_e / 10000));
      idx_n = long(10000 * long(1+(max_n / 10000)));
      if ((max_n % 10000) == 0) idx_n = long(max_n);
      if(logger(debug))
        logger, debug, log_id+"idx_e="+pr1(idx_e)+" idx_n="+pr1(idx_n);
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
      if(logger(debug)) {
        logger, debug, log_id+"ofn(1)="+ofn(1);
        logger, debug, log_id+"ofn(2)="+ofn(2);
        logger, debug, log_id+"pofn="+pofn;
      }

      // if update = 1, check to see if file exists
      if (update) {
        if(logger(debug)) logger, debug, log_id+"update enabled";
        // Get files from server
        if ( ! strmatch(host, "localhost") ) {
          if(logger(debug)) logger, debug, log_id+"retrieving files via rsync";
          write, format="rsyncing %s:%s\n", host, ofn(1);
          cmd = swrite(format="rsync -PHaqR %s:%s /", host, ofn(1));
          write, cmd;
          system, cmd;
          write, "rsyncing finished";
        }
      }

      if (typ == 0)
        new_file = file_rootname(pofn)+"_f.pbd";
      if (typ == 1)
        new_file = file_rootname(pofn)+"_b.pbd";
      if (typ == 2)
        new_file = file_rootname(pofn)+"_v.pbd";

      //does not work for typ=3
      new_file = file_tail(new_file); // only file name (removed path);

      if (update) {
        scmd = swrite(format = "find %s -name '%s'",save_dir, new_file);
        nf = 0;
        s = array(string, 1);
        f=popen(scmd(1), 0);
        nf = read(f,format="%s", s );
        close, f;
        if (nf) {
          write, format="File %s already exists...\n", new_file;
          if(logger(debug))
            logger, debug, log_id+"File already exists, aborting: "+new_file;
          // continue; // RWM
          return update;
        }
        update=0;  // if the tile was updated, force rcf to process.
      }
      write, format="Generating tile: %s\n", new_file;

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
        if(is_string(pnav_filename))
          write, f, format="PNAV FILE: %s\n",pnav_filename;
        if(is_string(ins_filename))
          write, f, format="INS FILE: %s\n",ins_filename;
        if(is_string(edb_filename))
          write, f, format="EDB FILE: %s\n", edb_filename;
        if(is_string(ops_conf_filename))
          write, f, format="OPS_CONF FILE: %s\n", ops_conf_filename;
        write_ops_conf, f;
        if (typ == 1) {
          write, f, "Bathymetry Settings";
          bath_ctl_save, f;
        }

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
      fs_all = make_fs(latutm = 1, q = q,  ext_bad_att=ext_bad_att, usecentroid=1, forcechannel=forcechannel );
      if (is_array(fs_all)) {
        test_and_clean, fs_all;
        if (is_array(fs_all)) {
          if (edf) {
            write, format = "Writing edf file for Region %d of %d\n",i,n;
            edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_f.edf", fs_all;
          }
          if (pbd) {
            t = *pointer(file_rootname(ofn(2)));
            nn = where(t == '_');
            date = string(&t(nn(0)+1:));
            vname = "fst_"+date+"_"+swrite(format="%d",i);
            write, format = "Writing pbd file for Region %d of %d\n",i,n;
            f = createb(file_rootname(pofn)+"_f.pbd");
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
        depth_all = make_bathy(latutm=1, q=q, avg_surf=avg_surf,
          ext_bad_att=ext_bad_att, forcechannel=forcechannel, verbose=0);
        if (is_array(depth_all)){
          test_and_clean, depth_all;
          if (is_array(depth_all)) {
            numstart=numberof(depth_all)
            if ((min(depth_all.east) < (min_e-400)*100) || (max(depth_all.east) > (max_e+400)*100) || (min(depth_all.north) < (min_n-400)*100) || (max(depth_all.north) > (max_n+400)*100)) {
              f = open(save_dir+swrite(format="i_e%d_n%d_%d/errors.txt", idx_e, idx_n, zone), "a");
              write, f, format="Data tile %9.2f %9.2f %9.2f %9.2f %s exceeded normal size.\n", min_e, max_e, min_n, max_n, mdate;
              write, f, format="	Tile size acctually: %9.2f %9.2f %9.2f %9.2f\n", min(depth_all.east)/100., max(depth_all.east)/100., min(depth_all.north)/100., max(depth_all.north/100.);
              if (!batch()) {
                pldj, max_e, max_n, min_e, max_n, color="red";
                pldj, min_e, min_n, max_e, min_n, color="red";
                pldj, max_e, min_n, max_e, max_n, color="red";
                pldj, min_e, min_n, min_e, max_n, color="red";
              }
              numend = numberof(data_box(depth_all.east, depth_all.north, (min_e-400)*100, (max_e+400)*100, (min_n-400)*100, (max_n+400)*100));
              write, f, format="# of points removed: %d of %d (That's %4.1f precent)\n", numstart-numend, numstart, ((((numstart-numend)*1.)/(numstart*1.))*100);
              close, f
            }

            if (edf) {
              write, format = "Writing edf file for Region %d of %d\n",i,n;
              edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_b.edf", depth_all;
            }
            if (pbd) {
              t = *pointer(file_rootname(ofn(2)));
              nn = where(t == '_');
              date = string(&t(nn(0)+1:));
              vname = "bat_"+date+"_"+swrite(format="%d",i);
              write, format = "Writing pbd file for Region %d of %d\n",i,n;
              f = createb(file_rootname(pofn)+"_b.pbd");
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
        veg_all = make_veg(latutm=1, q=q, ext_bad_att=ext_bad_att,
          use_centroid=1, forcechannel=forcechannel);
        if (is_array(veg_all))  {
          test_and_clean, veg_all;
          if (is_array(veg_all)) {
            if (edf) {
              write, format = "Writing edf file for Region %d of %d\n",i,n;
              edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_v.edf", veg_all;
            }
            if (pbd) {
              t = *pointer(file_rootname(ofn(2)));
              nn = where(t == '_');
              date = string(&t(nn(0)+1:));
              vname = "bet_"+date+"_"+swrite(format="%d",i);
              write, format = "Writing pbd file for Region %d of %d\n",i,n;
              f = createb(file_rootname(pofn)+"_v.pbd");
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
      depth_all = make_bathy(latutm=1, q=q, ext_bad_att=ext_bad_att,
        forcechannel=forcechannel, verbose=0);
      if (is_array(depth_all)){
        test_and_clean, depth_all;
        if (is_array(depth_all)) {
          if (edf) {
            write, format = "Writing edf file for Region %d of %d\n",i,n;
            edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_b.edf", depth_all;
          }
          if (pbd) {
            t = *pointer(file_rootname(ofn(2)));
            nn = where(t == '_');
            date = string(&t(nn(0)+1:));
            vname = "bat_"+date+"_"+swrite(format="%d",i);
            write, format = "Writing pbd file for Region %d of %d\n",i,n;
            f = createb(file_rootname(pofn)+"_b.pbd");
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
      veg_all = make_veg(latutm=1, q=q, ext_bad_att=ext_bad_att,
        use_centroid=1, forcechannel=forcechannel);
      if (is_array(veg_all))  {
        test_and_clean, veg_all;
        if (is_array(veg_all)) {
          if (edf) {
            write, format = "Writing edf file for Region %d of %d\n",i,n;
            edf_export, file_rootname(file_join(ofn(1), ofn(2)))+"_v.edf", veg_all;
          }
          if (pbd) {
            t = *pointer(file_rootname(ofn(2)));
            nn = where(t == '_');
            date = string(&t(nn(0)+1:));
            vname = "bet_"+date+"_"+swrite(format="%d",i);
            write, format = "Writing pbd file for Region %d of %d\n",i,n;
            f = createb(file_rootname(pofn)+"_v.pbd");
            add_variable, f, -1, vname, structof(veg_all), dimsof(veg_all);
            get_member(f, vname) = veg_all;
            save, f, vname;
            close, f;
            }
          }
        }
      }
    }

  if(logger(debug))
    logger, debug, log_id+"Leaving process_tile";
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
only_veg=, update=, avg_surf=, now=, b_rcf=, buf=, w=, no_rcf=,
mode=, merge=, rcfmode=, write_merge=, ext_bad_att=, forcechannel=, shapefile=,
shp_buffer=)
{
/* DOCUMENT mbatch_process, typ=, save_dir=, shem=, zone=, dat_tag=, cmdfile=,
  n=, onlyplot=, mdate=, pbd=, edf=, win=, auto=, pick=, get_typ=,
  only_bathy=, only_veg=, update=, avg_surf=, now=, b_rcf=, buf=,
  w=, no_rcf=, mode=, merge=, rcfmode=, write_merge=, ext_bad_att=,
  forcechannel=, shapefile=, shp_buffer=

  batch_process, typ=, save_dir=, shem=, zone=, dat_tag=, cmdfile=, n=,
  onlyplot=, mdate=, pbd=, edf=, win=, auto=, pick=, get_typ=, only_bathy=,
  only_veg=, update=, avg_surf=, now=, ext_bad_att=, forcechannel=,
  shapefile=, shp_buffer=

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

  ext_bad_att= Threshold in meters that specifies the minimum distance a point
            must be (in elevation) from the mirror to be considered valid. Set
            to 0 to disable. Default is 20 meters.

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

  b_rcf=     : 1 - invokes batch_rcf after normal batch processing

The following are pass thru variables needed for batch_rcf
  buf=         :
  w=           :
  no_rcf=      :
  mode=        :
  merge=       :
  rcfmode=     :
  write_merge= :

Ex: curzone=18
   batch_process,typ=2,save_dir="/data/3/2004/bombay-hook/output/",
            mdate="20040209",zone=18,pick=1

amar nayegandhi started (10/04/02) Lance Mosher
Added server/client support (2009-01) Richard Mitchell
*/
  default, ext_bad_att, 20.;
  if(numberof(forcechannel) > 1) {
    for(i = 1; i <= numberof(forcechannel); i++) {
      mbatch_process, typ=typ, save_dir=save_dir, shem=shem, zone=zone,
        dat_tag=dat_tag, cmdfile=cmdfile, n=n, onlyplot=onlyplot, mdate=mdate,
        pbd=pbd, edf=edf, win=win, auto=auto, pick=pick, get_typ=get_typ,
        only_bathy=only_bathy, only_veg=only_veg, update=update,
        avg_surf=avg_surf, now=now, b_rcf=b_rcf, buf=buf,
        w=w, no_rcf=no_rcf, mode=mode, merge=merge, rcfmode=rcfmode,
        write_merge=write_merge, ext_bad_att=ext_bad_att,
        forcechannel=forcechannel(i), shapefile=shapefile,
        shp_buffer=shp_buffer;
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
    if (cmdfile) indx_path(i) = file_dirname(file_dirname(path(i)))+"/";
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
    indx_tile = file_tail(file_dirname(mtdt_path(i)));
    mtdt_file(i) = mtdt_path(i)+indx_tile+"_"+mdate+"_metadata.txt";
    if (cmdfile) {
      f = open(mtdt_file(i),"a");
      write, f, "Batch Processing Begins"
      write, f, timestamp();
      if(!is_void(_hgid))
        write, f, format="   using repository revision %s\n", _hgid;
      write, f, format="PNAV FILE: %s\n",pnav_filename;
      if (typ == 0) write, f, "Processing for First Surface Returns"
      if (typ == 2) write, f, "Processing for topography under vegetation ie. (Bare Earth)"

      write_ops_conf, f;
      if (typ == 1) {
        write, f, "Bathymetry Settings";
        bath_ctl_save, f;
      }

      close, f;
    }
  }
  for (i=1;i<=n;i++) {
    if (cmdfile) {
      ofn = [file_dirname(path(i))+"/", file_tail(path(i))];
      if (mdate) {
        ofn(2) = file_rootname(ofn(2))+mdate+file_extension(ofn(2));
      }
      if (pbd) {
        ofn(2) = file_rootname(ofn(2))+".pbd";
        pofn = ofn(1)+ofn(2);
      }
      if (edf) {
        ofn(2) = file_rootname(ofn(2))+".edf";
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
          uber_process_tile(q=q, r=r, typ=typ, min_e=min_e(i), max_e=max_e(i), min_n=min_n(i), max_n=max_n(i), host=host, ext_bad_att=ext_bad_att, forcechannel=forcechannel )
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
only_veg=, update=, avg_surf=, now=, ext_bad_att=, forcechannel=,
shapefile=, shp_buffer=) {
  default, now, 1;
  mbatch_process, typ=typ, save_dir=save_dir, shem=shem, zone=zone,
    dat_tag=dat_tag, cmdfile=cmdfile, n=n, onlyplot=onlyplot, mdate=mdate,
    pbd=pbd, edf=edf, win=win, auto=auto, pick=pick, get_typ=get_typ,
    only_bathy=only_bathy, only_veg=only_veg, update=update,
    avg_surf=avg_surv, now=now, ext_bad_att=ext_bad_att,
    forcechannel=forcechannel, shapefile=shapefile, shp_buffer=shp_buffer;
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

func mbatch_process_dir( dirname, buf=, w=, no_rcf=, mode=, merge=, rcfmode=,
update=, onlyupdate=, write_merge=, searchstr=, selectmode=, win= ) {
/* DOCUMENT
func mbatch_process_dir( dirname, buf=, w=, no_rcf=, mode=, merge=,
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
