func corrupt_scan_pbd_dir(dir, searchstr=, outfile=, files=, relpath=) {
/* DOCUMENT corrupt_scan_pbd_dir, dir, searchstr=, outfile=, files=, relpath=
  Scans the PBDs in a directory to detect corrupt files.

  Parameter:
    dir: The directory to scan.

  Options:
    searchstr= The file pattern to search for. Default is "*.pbd" (all pbd files).
    outfile= By default the found files go to the console. If you provide
      OUTFILE, then they will be written to that file instead.
    files= A list of files to check. If this is used, then DIR+SEARCHSTR are
      not.
    relpath= Default is relpath=1, which shows paths relative to DIR. Use
      relpath=0 to show full absolute paths instead.
*/
  default, searchstr, "*.pbd";
  default, relpath, 1;

  f = [];
  if(outfile) f = open(outfile, "w");

  if(is_void(files)) files = find(dir, searchstr=searchstr);

  if(!numberof(files)) {
    write, "No files found.";
    return;
  }

  files = files(sort(files));
  nfiles = numberof(files);

  files_show = files;
  if(relpath) files_show = file_relative(dir, files_show);

  valid = array(1, nfiles);
  invalid = 0;

  msg = "Checking CURRENT of COUNT";

  status, start, count=nfiles, msg=msg;
  for(i = 1; i <= nfiles; i++) {
    status, progress, i, nfiles;
    if(!is_pbd(files(i))) {
      valid(i) = 0;
      write, f, format="%s\n", files_show(i);

      invalid++;
      msg = swrite(format="Checking CURRENT of COUNT (%d corrupt found)", invalid);
    }
  }
  status, finished;
}
