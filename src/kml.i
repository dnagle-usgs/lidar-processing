// vim: set ts=3 sts=3 sw=3 ai sr et:
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

   files = file_relative(file_dirname(dest), files);

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
   while(more_args())
      grow, items, next_arg();
   write, open(fn, "w"), format="%s\n", kml_Document(items, id=id, name=name,
      visibility=visibility, Open=Open, description=description,
      styleUrl=styleUrl);
}

func kml_randomcolor(data, void) {
   hue = data.hue;
   hue += 0.195 + random()/1000.;
   hue %= 1.;
   save, data, hue;
   rgb = hsl2rgb(hue, random()*.2+.8, random()*.1+.45);
   return kml_color(rgb(1), rgb(2), rgb(3));
}
kml_randomcolor = closure(kml_randomcolor, save(hue=random()));
