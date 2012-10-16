// vim: set ts=2 sts=2 sw=2 ai sr et:

func autoselect_ops_conf(dir) {
/* DOCUMENT ops_conf_file = autoselect_ops_conf(dir)

  This function attempts to determine the ops_conf.i file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  The function attempts to find an appropriate ops_conf.i file by following
  these steps:

    1. Is there a file named ops_conf.i in dir? If so, it is returned.
    2. Do any files in dir match ops_conf*.i? If so, those files are sorted
       by name and the last is returned.
    3. The same as 1, except looking in dir's parent directory.
    4. The same as 2, except looking in dir's parent directory.

  If no file can be found, then the nil string is returned (string(0)).
*/
  dir = file_join(dir);
  dirs = [dir, file_dirname(dir)];

  for(i = 1; i <= numberof(dirs); i++) {
    dir = dirs(i);

    if(file_isfile(file_join(dir, "ops_conf.i")))
      return file_join(dir, "ops_conf.i");

    files = lsfiles(dir, glob="ops_conf*.i");
    if(numberof(files)) {
      files = files(sort(files));
      return file_join(dir, files(0));
    }
  }

  return string(0);
}

func autoselect_edb(dir) {
/* DOCUMENT edb_file = autoselect_edb(dir)

  This function attempts to determine the EAARL edb file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  The function will return the first file (sorted) that matches
  dir/eaarl/*.idx. If no files match, string(0) is returned.
*/
  files = lsfiles(file_join(dir, "eaarl"), glob="*.idx");
  if(numberof(files))
    return file_join(dir, "eaarl", files(sort(files))(1));
  else
    return string(0);
}

func autoselect_cir_dir(dir) {
/* DOCUMENT cir_dir = autoselect_cir_dir(dir)
  This function attempts to determine the EAARL cir directory to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  If a subdirectory "cir" exists, it will be returned. Otherwise, string(0)
  is returned.
*/
  cir_dir = file_join(dir, "cir");
  if(file_isdir(cir_dir))
    return cir_dir;
  cir_dir = file_join(dir, "nir");
  if(file_isdir(cir_dir))
    return cir_dir;
  return string(0);
}

func autoselect_rgb_dir(dir) {
/* DOCUMENT rgb_dir = autoselect_rgb_dir(dir)
  This function attempts to determine the EAARL rgb directory to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  If a subdirectory "rgb" or "cam1" exists, it will be returned. Otherwise,
  string(0) is returned.
*/
  dirs = ["rgb", "cam1"];
  for(i = 1; i <= numberof(dirs); i++) {
    rgb_dir = file_join(dir, dirs(i));
    if(file_isdir(rgb_dir))
      return rgb_dir;
  }
  return string(0);
}

func autoselect_rgb_tar(dir) {
/* DOCUMENT rgb_tar = autoselect_rgb_tar(dir)
  This function attempts to determine the EAARL rgb tar file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  Three patterns are checked, in this order: *-cam1.tar, cam1-*.tar, and
  cam1.tar. The first pattern that matches any files will be used; if
  multiple files match that pattern, then the files are sorted and the first
  is returned. If no matches are found, string(0) is returned.
*/
  globs = ["*-cam1.tar", "cam1-*.tar", "cam1.tar"];
  for(i = 1; i <= numberof(globs); i++) {
    files = lsfiles(dir, glob=globs(i));
    if(numberof(files)) {
      files = files(sort(files));
      return file_join(dir, files(1));
    }
  }
  return string(0);
}

func autoselect_iexpbd(dir) {
/* DOCUMENT iexpbd_file = autoselect_iexpbd(dir)

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

   If no matches are found, [] is returned.

   This function is not guaranteed to return the best or most appropriate
   iexpbd file. It is a convenience function that should only be used when you
   know it's safe to be used.
*/
  dir = file_join(dir);
  if(file_tail(dir) != "trajectories") {
    if(file_exists(file_join(dir, "trajectories"))) {
      dir = file_join(dir, "trajectories");
    }
  }
  candidates = find(dir, glob="*-ins.pbd");
  if(!numberof(candidates)) return [];
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
  for(i = 1; i <= numberof(patterns); i++) {
    w = where(strglob(patterns(i), candidates));
    if(numberof(w)) {
      candidates = candidates(w);
      candidates = candidates(sort(candidates));
      return candidates(0);
    }
  }
  return [];
}

func autoselect_pnav(dir) {
/* DOCUMENT pnav_file = autoselect_pnav(dir)

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

  If no matches are found, [] is returned.

  This function is not guaranteed to return the best or most appropriate pnav
  file. It is a convenience function that should only be used when you know
  it's safe to be used.
*/
  dir = file_join(dir);
  if(file_tail(dir) != "trajectories") {
    if(file_exists(file_join(dir, "trajectories"))) {
      dir = file_join(dir, "trajectories");
    }
  }
  candidates = find(dir, glob="*-pnav.ybin");
  if(!numberof(candidates)) return [];
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
  for(i = 1; i <= numberof(patterns); i++) {
    w = where(strglob(patterns(i), candidates));
    if(numberof(w)) {
      candidates = candidates(w);
      candidates = candidates(sort(candidates));
      return candidates(0);
    }
  }
  return [];
}
