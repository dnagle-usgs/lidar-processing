// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func kmz_create(dest, files, ..) {
/* DOCUMENT kmz_create, dest, mainfile, file, file, file ...
  Creates a kmz at dest. mainfile is used as doc.kml, any additional files are
  also included. Arguments may be scalar or array.
*/
  while(more_args())
    grow, files, next_arg();

  rmvdoc = 0;

  if(file_tail(files(1)) != "doc.kml") {
    dockml = file_join(file_dirname(files(1)), "doc.kml");
    if(file_exists(dockml))
      error, "doc.kml already exists!";
    file_copy, files(1), dockml;
    files(1) = dockml;
    rmvdoc = 1;
  }

  listing = dest + ".listing";

  cmd = [];
  exe = popen_rdfile("which zip");
  if(numberof(exe)) {
    cmd = swrite(format="cd '%s' && cat '%s' | '%s' -X -9 -@ '%s'; rm -f '%s'",
      file_dirname(dest), listing, exe(1), file_tail(dest), listing);
  } else {
    error, "Unable to zip command.";
  }

  files = file_join(
    file_relative(file_dirname(dest), file_dirname(files)),
    file_tail(files));

  if(file_exists(dest))
    remove, dest;

  cwd = get_cwd();
  cd, file_dirname(dest);

  // Write out the list of files
  f = open(listing, "w");
  write, f, format="%s\n", files;
  close, f;

  system, cmd;

  // In case we're using sysafe, which runs async
  while(file_exists(listing))
    pause, 1;

  if(rmvdoc)
    remove, files(1);

  cd, cwd;
}

func kml_save(fn, items, .., id=, name=, visibility=, Open=, description=,
styleUrl=) {
/* DOCUMENT kml_save, fn, items, items, ..., id=, name=, visibility=, Open=,
  description=, styleUrl=
  Saves the given items, which should be properly-formatted KML elements as
  strings or string arrays, as a KML file. Items and all options are passed
  through to kml_Document to construct the final data to be written to file.
*/
  while(more_args())
    grow, items, next_arg();
  write, open(fn, "w"), format="%s\n", kml_Document(items, id=id, name=name,
    visibility=visibility, Open=Open, description=description,
    styleUrl=styleUrl);
}

func kml_randomcolor(data, void) {
/* DOCUMENT kml_randomcolor()
  Returns a semi-random color, formatted in KML-appropriate notation. Each
  time this is called, the hue is shifted by a random amount between 0.195 and
  0.196 (which means it cycles through the spectrum of hues every ~5 calls).
  The saturation value will be a random value between 0.8 and 1.0, and the
  lightness will be a random value between .45 and .55.
*/
  hue = data.hue;
  hue += 0.195 + random()*0.001;
  hue %= 1.;
  save, data, hue;
  rgb = hsl2rgb(hue, random()*.2+.8, random()*.1+.45);
  return kml_color(rgb(1), rgb(2), rgb(3));
}
kml_randomcolor = closure(kml_randomcolor, save(hue=random()));
