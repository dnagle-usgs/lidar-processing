// vim: set ts=2 sts=2 sw=2 ai sr et:

func autoselect_ops_conf(dir, options=) {
/* DOCUMENT ops_conf_file = autoselect_ops_conf(dir, options=)

  This function attempts to determine the ops_conf.i file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  The function attempts to find an appropriate ops_conf.i file by following
  these steps:

    1. Is there a file named ops_conf.i in dir? If so, it is returned.
    2. Do any files in dir match *ops_conf*.i? If so, those files are sorted
       by name and the last is returned.
    3. The same as 1, except looking in dir's parent directory.
    4. The same as 2, except looking in dir's parent directory.

  If no file can be found, then the nil string is returned (string(0)).

  If options=1, then an array of all possibilities that meet the criteria above
  is returned instead. If no possiblities are found, then [string(0)] is
  returned.
*/
  dir = file_join(dir);
  dirs = [dir, file_dirname(dir)];

  results = [];
  for(i = 1; i <= numberof(dirs); i++) {
    dir = dirs(i);

    if(file_isfile(file_join(dir, "ops_conf.i")))
      grow, results, file_join(dir, "ops_conf.i");

    files = lsfiles(dir, glob="*ops_conf*.i");
    if(numberof(files)) {
      files = files(sort(files));
      grow, results, file_join(dir, files);
    }
  }

  if(is_void(results))
    results = [string(0)];
  return options ? results : results(1);
}

func autoselect_bath_ctl(dir, options=) {
/* DOCUMENT bctl_file = autoselect_bath_ctl(dir, options=)

  This function attempts to determine the bathy settings file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  The function attempts to find an appropriate bathy settings file by following
  these steps:

    1. Are there any files named *-bctl.json in the flight directory?
    2. Are there any files named *-bctl.json in the parent directory?
    3. Are there any files named *.bctl in the flight directory?
    4. Are there any files named *.bctl in the parent directory?

  If no file can be found, then the nil string is returned (string(0)).

  If options=1, then an array of all possibilities that meet the criteria above
  is returned instead. If no possiblities are found, then [string(0)] is
  returned.
*/
  dir = file_join(dir);
  dirs = [dir, file_dirname(dir)];
  globs = ["*-bctl.json", "*.bctl"];

  results = [];
  for(i = 1; i <= numberof(globs); i++) {
    for(j = 1; j <= numberof(dirs); j++) {
      files = lsfiles(dirs(j), glob=globs(i));
      if(numberof(files)) {
        files = files(sort(files));
        grow, results, file_join(dirs(j), files);
      }
    }
  }

  if(is_void(results))
    results = [string(0)];
  return options ? results : results(1);
}

func autoselect_edb(dir, options=) {
/* DOCUMENT edb_file = autoselect_edb(dir, options=)

  This function attempts to determine the EAARL edb file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  The function will return the first file (sorted) that matches
  dir/eaarl/*.idx. If no files match, string(0) is returned.

  If options=1, then an array of all possibilities that meet the criteria above
  is returned instead. If no possiblities are found, then [string(0)] is
  returned.
*/
  files = lsfiles(file_join(dir, "eaarl"), glob="*.idx");
  results = [];
  if(numberof(files))
    results = file_join(dir, "eaarl", files(sort(files)));
  else
    results = [string(0)];
  return options ? results : results(1);
}

func autoselect_nir_dir(dir, options=) {
/* DOCUMENT nir_dir = autoselect_nir_dir(dir, options=)
  This function attempts to determine the EAARL nir directory to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  If a subdirectory "nir" exists, it will be returned. Otherwise, string(0) is
  returned.

  If options=1, then an array of all possibilities that meet the criteria above
  is returned instead. If no possiblities are found, then [string(0)] is
  returned.
*/
  results = [];
  nir_dir = file_join(dir, "nir");
  if(file_isdir(nir_dir))
    grow, results, nir_dir;
  if(is_void(results))
    results = [string(0)];
  return options ? results : results(1);
}

func autoselect_rgb_dir(dir, options=) {
/* DOCUMENT rgb_dir = autoselect_rgb_dir(dir, options=)
  This function attempts to determine the EAARL rgb directory to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  If a subdirectory "rgb" or "cam1" exists, it will be returned. Otherwise,
  string(0) is returned.

  If options=1, then an array of all possibilities that meet the criteria above
  is returned instead. If no possiblities are found, then [string(0)] is
  returned.
*/
  dirs = ["rgb", "cam1"];
  results = [];
  for(i = 1; i <= numberof(dirs); i++) {
    rgb_dir = file_join(dir, dirs(i));
    if(file_isdir(rgb_dir))
      grow, results, rgb_dir;
  }
  if(is_void(results))
    results = [string(0)];
  return options ? results : results(1);
}

func autoselect_rgb_tar(dir, options=) {
/* DOCUMENT rgb_tar = autoselect_rgb_tar(dir, options=)
  This function attempts to determine the EAARL rgb tar file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  Three patterns are checked, in this order: *-cam1.tar, cam1-*.tar, and
  cam1.tar. The first pattern that matches any files will be used; if
  multiple files match that pattern, then the files are sorted and the first
  is returned. If no matches are found, string(0) is returned.

  If options=1, then an array of all possibilities that meet the criteria above
  is returned instead. If no possiblities are found, then [string(0)] is
  returned.
*/
  globs = ["*-cam1.tar", "cam1-*.tar", "cam1.tar"];
  results = [];
  for(i = 1; i <= numberof(globs); i++) {
    files = lsfiles(dir, glob=globs(i));
    if(numberof(files)) {
      files = files(sort(files));
      grow, results, file_join(dir, files);
    }
  }
  if(is_void(results))
    results = [string(0)];
  return options ? results : results(1);
}

func autoselect_iexpbd(dir, options=) {
/* DOCUMENT iexpbd_file = autoselect_iexpbd(dir, options=)

   This function attempts to determine an appropriate iexpbd file to load for a
   dataset.

   The dir parameter should be either the path to the mission day or the path
   to the mission day's trajectories subdirectory.

   The function will find all *-ins.pbd files underneath the trajectories
   directory. If there are more than one, then it selects based on what kind of
   file it is with the following priorities (high to low): *-p-*, *-b-*, *-r-*,
   and *-u-*. If there are still multiple matches, then it prefers
   *-fwd-ins.pbd if present. If there are still multiple matches, it sorts them
   then returns the last one -- in many cases, this will result in the most
   recently created file being chosen.

   This function is not guaranteed to return the best or most appropriate
   iexpbd file. It is a convenience function that should only be used when you
   know it's safe to be used.

  If options=1, then an array of all possibilities that meet the criteria above
  is returned instead. If no possiblities are found, then [string(0)] is
  returned.
*/
  dir = file_join(dir);
  if(file_tail(dir) != "trajectories") {
    if(file_exists(file_join(dir, "trajectories"))) {
      dir = file_join(dir, "trajectories");
    }
  }
  candidates = find(dir, searchstr="*-ins.pbd");
  if(!numberof(candidates)) return options ? [] : [string(0)];
  patterns = [
    "*-p-*-fwd-ins.pbd",
    "*-p-*-ins.pbd",
    "*-b-*-fwd-ins.pbd",
    "*-b-*-ins.pbd",
    "*-r-*-fwd-ins.pbd",
    "*-r-*-ins.pbd",
    "*-u-*-fwd-ins.pbd",
    "*-u-*-ins.pbd"
      ];
  results = [];
  for(i = 1; i <= numberof(patterns); i++) {
    w = where(strglob(patterns(i), candidates));
    if(numberof(w)) {
      files = candidates(w);
      files = files(sort(files)(::-1));
      grow, results, files;
    }
  }
  if(is_void(results))
    results = [string(0)];
  return options ? results : results(1);
}

func autoselect_pnav(dir, options=) {
/* DOCUMENT pnav_file = autoselect_pnav(dir, options=)

  This function attempts to determine an appropriate pnav file to load for a
  dataset.

  The dir parameter should be either the path to the mission day or the path
  to the mission day's trajectories subdirectory.

  The function will find all *-pnav.ybin files underneath the trajectories
  directory. If there are more than one, then it selects based on what kind of
  file it is with the following priorities (high to low): *-p-*, *-b-*, *-r-*,
  and *-u-*. If there are still multiple matches, then it prefers
  *-cmb-pnav.ybin if present. If there are still multiple matches, it sorts
  them then returns the last one -- in many cases, this will result in the
  most recently created file being chosen.

  This function is not guaranteed to return the best or most appropriate pnav
  file. It is a convenience function that should only be used when you know
  it's safe to be used.

  If options=1, then an array of all possibilities that meet the criteria above
  is returned instead. If no possiblities are found, then [string(0)] is
  returned.
*/
  dir = file_join(dir);
  if(file_tail(dir) != "trajectories") {
    if(file_exists(file_join(dir, "trajectories"))) {
      dir = file_join(dir, "trajectories");
    }
  }
  candidates = find(dir, searchstr="*-pnav.ybin");
  if(!numberof(candidates)) return options ? [] : [string(0)];
  patterns = [
    "*-p-*-cmb-pnav.ybin",
    "*-p-*-pnav.ybin",
    "*-b-*-cmb-pnav.ybin",
    "*-b-*-pnav.ybin",
    "*-r-*-cmb-pnav.ybin",
    "*-r-*-pnav.ybin",
    "*-u-*-cmb-pnav.ybin",
    "*-u-*-pnav.ybin",
    "*-pnav.ybin"
  ];
  results = [];
  for(i = 1; i <= numberof(patterns); i++) {
    w = where(strglob(patterns(i), candidates));
    if(numberof(w)) {
      files = candidates(w);
      files = files(sort(files)(::-1));
      grow, results, files;
    }
  }
  if(is_void(results))
    results = [string(0)];
  return options ? results : results(1);
}
