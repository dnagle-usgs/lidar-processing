require, "makeflow.i";

func mf_automerge_tiles(path, searchstr=, update=, makeflow_fn=,
norun=) {
/* DOCUMENT mf_automerge_tiles, path, searchstr=, update=, makeflow_fn=,
   norun=

  Specialized batch merging function for the initial merge of processed data.

  By default, it will find all files matching *_v.pbd and *_b.pbd. It will
  then merge everything it can. It makes distinctions between _v and _b, and
  it also makes distinctions between w84, n88, n88_g03, n88_g09, etc. Thus,
  it's safe to run on a directory containing both veg and bathy or both w84
  and n88; they won't all get mixed together inappropriately.

  If called as a subroutine, the jobs will be run with Makeflow. If called as a
  function, the configuration that would have been passed to Makeflow is
  returned instead.

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

    update= By default, existing files are overwritten. Using update=1 will
      skip them instead.
        update=0    Overwrite files if they exist
        update=1    Skip files if they exist

    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.

    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow

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
  default, update, 0;

  // Locate files and split into dirs/tails
  files = find(path, searchstr=searchstr);
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
    if(allof(problem)) {
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
    if(update) {
      if(allof(exists)) {
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
    } else {
      w = where(exists);
      for(i = 1; i <= numberof(w); i++)
        remove, outfiles(w(i));
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

  // Iterate through and load each file, saving whenever we're on the input
  // file for a given output file.
  conf = save();
  i = j = k = 1;
  while(i <= count) {
    while(j < count && outfiles(j+1) == outfiles(i))
      j++;
    save, conf, string(0), save(
      input=files(i:j),
      output=outfiles(i),
      command="job_dirload",
      options=save(
        string(0), [],
        "file-in", files(i:j),
        "file-out", outfiles(i),
        vname=vnames(i),
        uniq="0",
        skip="1",
        soesort="1"
      )
    );
    i = j = j + 1;
    k++;
  }

  if(!am_subroutine())
    return conf;

  makeflow_run, conf, makeflow_fn, interval=10, norun=norun;
}
