// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "l1pro.i";

func batch_datum_convert(indir, files=, searchstr=, zone=, outdir=, update=,
excludestr=, src_datum=, src_geoid=, dst_datum=, dst_geoid=, force=, clean=) {
/* DOCUMENT batch_datum_convert, indir, files=, searchstr=, zone=, outdir=,
   update=, excludestr=, src_datum=, src_geoid=, dst_datum=, dst_geoid=, force=

   Performs datum conversion in batch mode.

   Parameter:
      indir: The directory where the files to be converted reside.

   Options:
      files= A manually provided list of files to convert. Using this will
         cause indir, searchstr=, and excludestr= to be ignored.
         Default: none
      searchstr= A search pattern for the files to be converted.
         Default: searchstr="*w84*.pbd"
      excludestr= A search pattern for files to be excluded. If a file matches
         both searchstr and excludestr, it will not be converted.
         Default: none
      zone= The UTM zone for the data.
         Default: determined from file name
      outdir= An output directory for converted files. If not provided, files
         will be created alongside the files they convert.
         Default: none; based on input file
      update= Specifies whether to run in update mode. Possible values:
            update=0  - All files will get converted, possibly overwriting
                        files that were previously converted (default)
            update=1  - Skips files that already exist, useful for resuming a
                        previous conversion
      force= Specifies whether to forcibly convert against the script's
         recommendations.
            force=0   - Skip files where issues are detected. (default)
            force=1   - Always convert, even when issues are detected. This may
                        result in incorrect conversions!
         Use of force=1 can cause major issues. Use with caution!!!
      clean= Specifies whether to use test_and_clean on the data. Settings:
            clean=0  - Do not clean data.
            clean=1  - Clean data. (default)

   The following additional options are more extensively documented in
   datum_convert_data, but have special additional properties here:
      src_datum= If omitted, will be detected from the filename.
      src_geoid= If omitted, will be detected from the filename.
      dst_datum= Default: dst_datum="n88"
      dst_geoid= Default: dst_geoid="09"
   See datum_convert_data for what each option actually means.

   Notes:

      If src_datum/src_geoid are specified and do not match what is detected
      from the filename, then one of two things will happen. If force=0, then
      the file will be skipped; this effectively allows you to use
      src_datum/src_geoid as a filter. If force=1, then the file will be
      forcibly converted; this is often a bad idea and is likely to result in
      double-converted data, which is garbage.

      If dst_datum/dst_geoid match what is detected from the filename, then one
      of two things will happen. If force=0, then the file will be skipped sine
      no conversion is needed. If force=1, then it will be converted anyway,
      which is generally a bad idea.

      If zone is specified and does not match what is detected, then the file
      will either be skipped (if force=0) or will be converted anyway
      (force=1).

      When force=1 results in a forced conversion, the datum, geoid, and zone
      used are the ones specified by the user.

      The default value for dst_geoid is likely to change if new geoids are
      released for NAVD-88 in the future.
*/
   default, searchstr, "*w84*.pbd";
   default, update, 0;
   default, dst_datum, "n88";
   default, dst_geoid, "09";
   default, force, 0;
   default, clean, 1;

   if(!is_void(src_geoid))
      src_geoid = regsub("^g", src_geoid, "");
   dst_geoid = regsub("^g", dst_geoid, "");

   if(is_void(files)) {
      files = find(indir, glob=searchstr);
      if(!is_void(excludestr)) {
         w = where(!strglob(excludestr, file_tail(files)));
         if(numberof(w))
            files = files(w);
         else
            files = [];
      }
      write, format="\nLocated %d files to convert.\n", numberof(files);
   } else {
      files = files(*);
      write, format="\nUsing %d files as specified by user.\n", numberof(files);
   }

   if(is_void(files)) {
      write, "\nNo files found. Aborting.";
      return;
   }

   for(i = 1; i <= numberof(files); i++) {
      tail = file_tail(files(i));
      write, format="\n%d/%d %s\n", i, numberof(files), tail;

      // Attempt to extract datum information from filename
      fn_datum = fn_geoid = part1 = part2 = [];
      assign, parse_datum(tail), fn_datum, fn_geoid, part1, part2;

      // We could now reconstruct the original filename with logic like this:
      // part1 + fn_datum + (fn_geoid ? "_g"+fn_geoid : "") + part2

      // If it's n88 but we don't have a geoid, default to g03.
      if(fn_datum == "n88" && strlen(fn_geoid) == 0)
         fn_geoid = "03";

      // Extract UTM zone
      fn_zone = tile2uz(tail);

      // Construct the output file names
      fn_out = part1 + dst_datum;
      if(dst_datum == "n88")
         fn_out += "_g" + dst_geoid;
      fn_out += part2;
      fn_outdir = is_void(outdir) ? file_dirname(files(i)) : outdir;
      fn_out = file_join(unref(fn_outdir), fn_out);

      if(file_exists(fn_out) && update) {
         write, " Skipping; output file exists.";
         continue;
      }

      write, format="  Detected: zone=%d datum=%s", fn_zone, fn_datum;
      if(fn_datum == "n88")
         write, format=" geoid=%s", fn_geoid;
      write, format="%s", "\n";

      // Now things get complicated... We need to check for various potential
      // problems.
      fatal = messages = [];
      if(files(i) == fn_out) {
         grow, fatal, "Input and output filenames match.";
      }

      if(fn_datum == dst_datum) {
         if(dst_datum == "n88") {
            if(fs_geoid == dst_geoid)
               grow, messages, "Detected datum/geoid matches output datum/geoid.";
         } else {
            grow, messages, "Detected datum matches output datum.";
         }
      }
      if(is_void(src_datum)) {
         if(strlen(fn_datum) == 0) {
            grow, fatal, "Unable to detect file datum.";
         }
      } else {
         if(src_datum != fn_datum)
            grow, messages, "Detected datum does not match user-specified datum.";
         if(src_datum == "n88" && !is_void(src_geoid) && src_geoid != fn_geoid)
            grow, messages, "Detected geoid does not match user-specified geoid.";
      }
      if(!is_void(zone)) {
         if(zone != fn_zone)
            grow, messages, "Detected zone does not match user-specified zone.";
      } else if(fn_zone == 0) {
         grow, fatal, "Unable to detect file zone.";
      }

      // If we aren't yet dead, then try to load the data to check for more
      // errors.
      vname = data = err = [];
      if(!numberof(fatal) && (force || !numberof(messages))) {
         data = pbd_load(files(i), err, vname);
         if(is_void(data)) {
            grow, fatal, "Unable to load file: " + err;
         }
      }

      // If we received a vname, datum-check it
      if(!is_void(vname)) {
      // Check variable name for datum
         var_datum = var_geoid = part1 = part2 = [];
         assign, parse_datum(vname), var_datum, var_geoid, part1, part2;
         if(strlen(var_datum)) {
            // If we have a datum... it should match the file's!
            if(fn_datum == var_datum) {
               // Update the vname to show its new datum...
               vname = part1 + dst_datum + part2;
            } else {
               grow, warnings, "Filename datum does not match variable name datum.";
            }
         } else {
            vname = vname + "_" + dst_datum;
         }
      }

      // If we encountered problems that prevent us from continue, then skip
      // regardless of the force= setting.
      if(numberof(fatal)) {
         write, " Skipping due to fatal problems:";
         write, format="  - %s\n", fatal;
         continue;
      }

      // If we encountered non-fatal problems, then skip unless the user wants
      // to force the issue.
      if(numberof(messages)) {
         if(force) {
            write, " WARNING!!!!! Forcing conversion despite detected problems:";
            write, format="  - %s\n", messages;
         } else {
            write, " Skipping due to detected problems:";
            write, format="  - %s\n", messages;
            continue;
         }
      }
      if(file_exists(fn_out)) {
         write, " Output file already exists; will be overwritten.";
      }

      // Set up source datums and zone
      cur_src_datum = is_void(src_datum) ? fn_datum : src_datum;
      cur_src_geoid = is_void(src_geoid) ? fn_geoid : src_geoid;
      cur_zone = is_void(zone) ? fn_zone : zone;

      // Now... we can actually convert the data!

      if(strlen(err)) {
         write, format=" Error encountered loading file: %s\n", err;
         continue;
      } else if(!numberof(data)) {
         write, " Skipping, no data in file.";
         continue;
      }

      if(clean)
         data = test_and_clean(unref(data));
      if(is_void(data)) {
         write, " WARNING!!! test_and_clean eliminated all the data!!!";
         write, " This isn't supposed to happen!!! Skipping...";
         continue;
      }

      datum_convert_data, data, zone=cur_zone, src_datum=cur_src_datum,
         src_geoid=cur_src_geoid, dst_datum=dst_datum, dst_geoid=dst_geoid;

      if(is_void(data)) {
         write, " WARNING!!! Datum conversion eliminated the data!!!";
         write, " This isn't supposed to happen!!! Skipping...";
         continue;
      }

      pbd_save, fn_out, vname, data;
   }
}
