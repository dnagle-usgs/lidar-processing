// Header used by all EDF files
struct EDF_HEADER {
   long marker;   // Endian marker 0x0000ffff (65535)
   long type;     // Type of file
   long words;    // Number of words per record
   long records;  // Number of records
}

// unknown? GEODEPTH -- use GEO
struct EDF_TYPE_1_4 {
   long rn;
   long north, east;
   short depth;
}

// unknown? GEOBATH -- use GEO
struct EDF_TYPE_3_6 {
   long rn;
   long north, east, sr2;
   short depth, bottom_peak;
}

// corresponds to FS
struct EDF_TYPE_3_8 {
   long rn;
   long mnorth, meast, melevation;
   long north, east, elevation;
   short intensity;
}

// corresponds to GEO
struct EDF_TYPE_4_11 {
   long rn;
   long north, east;
   short sr2;
   long elevation;
   long mnorth, meast, melevation;
   short bottom_peak, first_peak;
   short depth;
}

// corresponds to VEG
struct EDF_TYPE_5_12 {
   long rn;
   long north, east, elevation;
   long mnorth, meast, melevation;
   short felv, fint, lelv, lint;
   char nx;
}

// corresponds to VEG_
struct EDF_TYPE_6_12 {
   long rn;
   long north, east, elevation;
   long mnorth, meast, melevation;
   long felv;
   short fint;
   long lelv;
   short lint;
   char nx;
}

// corresponds to CVEG_ALL
struct EDF_TYPE_7_9 {
   long rn;
   long north, east, elevation;
   long mnorth, meast, melevation;
   short intensity;
   char nx;
}

// corresponds to VEG__
struct EDF_TYPE_8_13 {
   long rn;
   long north, east, elevation;
   long mnorth, meast, melevation;
   long lnorth, least, lelv;
   short fint, lint;
   char nx;
}

// corresponds to FS
struct EDF_TYPE_101_9 {
   long rn;
   long mnorth, meast, melevation;
   long north, east, elevation;
   short intensity;
   double soe;
}

// corresponds to GEO
struct EDF_TYPE_102_12 {
   long rn;
   long north, east;
   short sr2;
   long elevation;
   long mnorth, meast, melevation;
   short bottom_peak, first_peak;
   short depth;
   double soe;
}

// corresponds to VEG__
struct EDF_TYPE_103_14 {
   long rn;
   long north, east, elevation;
   long mnorth, meast, melevation;
   long lnorth, least, lelv;
   short fint, lint;
   char nx;
   double soe;
}

// corresponds to CVEG_ALL
struct EDF_TYPE_104_10 {
   long rn;
   long north, east, elevation;
   long mnorth, meast, melevation;
   short intensity;
   char nx;
   double soe;
}

// corresponds to BOTRET
struct EDF_TYPE_1001_10 {
   long rn;
   short idx, sidx, range;
   float ac, cent, centidx, peak;
   short peakidx;
   double soe;
}

func edf_header(edf) {
/* DOCUMENT edf_header, edf_stream
   -or- edf_header, filename
   -or- edf_header, filenames

   Given an EDF file (either as an open EDF stream, a scalar filename, or an
   array of file names), this will display some information about the file
   based on its header.

   SEE ALSO: edf_open
*/
   if(is_string(edf) && numberof(edf) > 1) {
      for(i = 1; i <= numberof(edf); i++)
         edf_header, edf(i);
      return;
   }

   if(is_string(edf))
      edf = edf_open(edf);
   header = (edf.header);
   fn = filepath(edf);
   size = sizeof(edf);
   if(has_member(edf, "data"))
      varsize = sizeof(edf.header) + sizeof(edf.data);
   else
      varsize = sizeof(edf.header);
   close, edf;

   estruct = swrite(format="EDF_TYPE_%d_%d", header.type, header.words);
   eexists = symbol_exists(estruct);

   write, format="\nHeader information for:\n  %s\n\n", file_tail(fn);
   write, format="  %-14s : %d (%s)\n", "Marker", header.marker,
      (header.marker == 65535 ? "correct" : "wrong");
   write, format="  %-14s : %d\n", "Type", header.type;
   write, format="  %-14s : %d\n", "Words", header.words;
   write, format="  %-14s : %d\n", "Records", header.records;
   write, format="  %-14s : %s\n", "File size", bytes2text(size);
   write, format="  %-14s : %s\n", "Variables size", bytes2text(varsize);
   write, format="  %-14s : %s (%s)\n", "EDF struct", estruct,
      (eexists ? "known" : "unknown");

   descs = h_new(
      EDF_TYPE_1_4="GEO (partial, no soe)",
      EDF_TYPE_3_6="GEO (partial, no soe)",
      EDF_TYPE_3_8="FS (no soe)",
      EDF_TYPE_4_11="GEO (no soe)",
      EDF_TYPE_5_12="VEG (no soe)",
      EDF_TYPE_6_12="VEG_ (no soe)",
      EDF_TYPE_7_9="CVEG_ALL (no soe)",
      EDF_TYPE_8_13="VEG__ (no soe)",
      EDF_TYPE_101_9="FS",
      EDF_TYPE_102_12="GEO",
      EDF_TYPE_103_14="VEG__",
      EDF_TYPE_104_10="CVEG_ALL",
      EDF_TYPE_1001_10="BOTRET"
   );

   if(h_has(descs, estruct))
      match = descs(estruct);
   else
      match = "unknown";

   write, format="  %-14s : %s\n", "Corresponds to", match;
}

func edf_install_primitives(stream) {
/* DOCUMENT edf_install_primitives, stream;
   Configures the primitive data types in stream for edf compatibility. This is
   essential! Otherwise, data types will take the wrong amount of space or will
   not align properly on byte boundaries.

   SEE ALSO: edf_open
*/
   extern __i86;
   // Generally equivalent to i86 primitives
   prims = __i86;
   // However, we align on each byte
   prims(2:17:3) = 1;
   set_primitives, stream, prims;
}

func edf_open(fn, mode=) {
/* DOCUMENT f = edf_open(fn, mode=)
   Opens a file handle to an EDF file. By default, it will open the file in
   read-only mode, but the mode= option can be used to specify read-write
   access using mode="wb+" or write-only access using mode="wb".

   In all cases, the primitive data types will be installed and the header
   variable will be defined. If the file is 32 bytes or larger, it will also
   attempt to define the data variable using the type and word count in the
   header.

   Variables defined in the file:
      f.header, always defined, struct EDF_HEADER
      f.data, conditionally defined, struct EDF_TYPE_* based on header

   SEE ALSO: edf_load, edf_import
*/
   default, mode, "rb";
   f = open(fn, mode);
   edf_install_primitives, f;
   add_variable, f, -1, "header", EDF_HEADER;
   if(sizeof(f) > 32) {
      type = swrite(format="EDF_TYPE_%d_%d", f.header.type, f.header.words);
      if(symbol_exists(type))
         add_variable, f, -1, "data", symbol_def(type), f.header.records;
   }
   return f;
}

func edf_load(fn) {
/* DOCUMENT data = edf_load(fn)
   Loads data defined in the given EDF file. The data will be in an EDF_TYPE_*
   structure.

   SEE ALSO: edf_open, edf_import
*/
   f = edf_open(fn);
   data = (f.data);
   close, f;
   return data;
}

func edf_export(fn, data, append=, type=, words=) {
/* DOCUMENT edf_export, fn, data, append=, type=, words=
   Exports ALPS data to an EDF file. The ALPS data should be in one of these
   structures: FS, GEO, VEG__, CVEG_ALL, ATM2.

   Parameters:
      fn: The output EDF file to create.
      data: The ALPS data to export.
   Options:
      append= If the file already exists, data will be appended instead of
         overwriting it. The new data will also be coerced to the same type as
         the data from the file.
      type= Specifies the EDF type to use.
      words= Specifies the EDF word count to use.

   By default, type= and words= are auto-determined based on the data
   structure. However, you can also manually specify them if you need to coerce
   the data to a different structure. Both type= and words= must be defined for
   either of them to have an effect; if only one is defined, it is ignored.
   (Note: It is required that both be defined because type= does not uniquely
   determine an EDF structure type; there are two versions of type 3.)

   SEE ALSO: edf_import, edf_export_cast, pbd2edf
*/
   default, append, 0;
   if(append && file_exists(fn)) {
      prev_data = edf_load(fn);
      edf_parse_struct, prev_data, in_type, in_words;
      if(!is_void(in_type)) {
         type = in_type;
         words = in_words;
      } else {
         error, "Uh oh!";
      }
   }
   edf_export_cast, data, type=type, words=words;
   if(!is_void(prev_data))
      data = grow(prev_data, data);

   edf_parse_struct, data, type, words;
   if(is_void(type))
      error, "Uh oh!";

   f = edf_open(fn, mode="wb");
   f.header.marker = 0x0000ffff;
   f.header.type = type;
   f.header.words = words;
   f.header.records = numberof(data);

   add_variable, f, -1, "data", structof(data), dimsof(data);
   f.data = data;
   close, f;

   if(file_exists(fn+"L"))
      remove, fn+"L";
}

func edf_export_cast(&data, type=, words=) {
/* DOCUMENT edf_export_cast, data, type=, words=
   Converts data in an ALPS structure (FS, GEO, VEG__, CVEG_ALL, or ATM2) to an
   EDF structure. The structure will be mapped to the most approprorate EDF
   structure based on the data. You can also manually specify a conversion by
   specifying both type= and words=; see edf_export for important information
   regarding that.

   SEE ALSO: edf_export
*/
   s = nameof(structof(data));

   if(s == "ATM2") {
      fint = data.fint;
      struct_cast, data, FS;
      data.intensity = unref(fint);
      s = "FS";
   }

   if(is_void(type) || is_void(words)) {
      mapping = h_new(
         "FS", h_new(nosoe=3, soe=101, words=8),
         "GEO", h_new(nosoe=4, soe=102, words=11),
         "VEG__", h_new(nosoe=8, soe=103, words=13),
         "CVEG_ALL", h_new(nosoe=7, soe=104, words=9)
      );

      if(h_has(mapping, s)) {
         if(noneof(data.soe)) {
            type = mapping(s).nosoe;
            words = mapping(s).words;
         } else {
            type = mapping(s).soe;
            words = mapping(s).words + 1;
         }
      } else {
         error, "Uh oh";
      }
   }

   edfs = swrite(format="EDF_TYPE_%d_%d", type, words);
   if(!symbol_exists(edfs))
      error, "Uh oh!";
   struct_cast, data, symbol_def(edfs);
}

func edf_import(fn) {
/* DOCUMENT data = edf_import(fn)
   Imports data from an EDF file into an ALPS data structure. The structure is
   auto-determined based on the type used in the EDF file and will always be
   one of FS, GEO, VEG__, or CVEG_ALL.

   SEE ALSO: edf_load, edf_export, edf_import_cast, edf2pbd
*/
   data = edf_load(fn);
   edf_import_cast, data;
   return data;
}

func edf_import_cast(&data) {
/* DOCUMENT edf_import_cast, data
   Converts data in an EDF structure to the most appropriate ALPS structure for
   its type.

   SEE ALSO: edf_import
*/
   s = nameof(structof(data));

   mapping = h_new(
      EDF_TYPE_1_4=GEO,
      EDF_TYPE_3_6=GEO,
      EDF_TYPE_3_8=FS,
      EDF_TYPE_4_11=GEO,
      EDF_TYPE_5_12=VEG,
      EDF_TYPE_6_12=VEG_,
      EDF_TYPE_7_9=CVEG_ALL,
      EDF_TYPE_8_13=VEG__,
      EDF_TYPE_101_9=FS,
      EDF_TYPE_102_12=GEO,
      EDF_TYPE_103_14=VEG__,
      EDF_TYPE_104_10=CVEG_ALL,
      EDF_TYPE_1001_10=BOTRET
   );

   if(h_has(mapping, s))
      struct_cast, data, mapping(s);
   else
      error, "Unknown EDF type; cannot convert";
}

func edf_parse_struct(s, &type, &words) {
/* DOCUMENT edf_parse_struct, edf, type, words
   Returns the type and word count for the given edf data, which may be an
   array of data in an EDF structure, an EDF structure, or the name of an EDF
   structure. If the type and word count can't be determined (which would
   happen if, for example, the data isn't in an EDF structure), then both type
   and words will be void.

   SEE ALSO: edf_import, edf_export
*/
   if(!is_string(s) && !is_struct(s))
      s = structof(s);
   if(!is_string(s))
      s = nameof(s);
   type = words = 0;
   res = sread(s, format="EDF_TYPE_%d_%d", type, words);
   if(res == 2)
      return;
   type = words = [];
}

func pbd2edf(pbd, edf=, type=, words=) {
/* DOCUMENT pbd2edf, pbd, edf=, type=, words=
   Converts a PBD file to an EDF file.

   Parameter:
      pbd: The path to a PBD file.
   Options:
      edf= Path to the EDF file to create. By default, it will be the same as
         the PBD file but with the extension changed to .edf.
      type= See edf_export for details.
      words= See edf_export for details.

   SEE ALSO: batch_pbd2edf, edf2pbd, edf_export
*/
   default, edf, file_rootname(pbd) + ".edf";
   edf_export, edf, pbd_load(pbd), type=type, words=words;
}

func edf2pbd(edf, pbd=, vname=) {
/* DOCUMENT edf2pbd, edf, pbd=, vname=
   Converts an EDF file to a PBD file.

   Parameter:
      edf: The path to an EDF file.
   Options:
      pbd= Path to the PBD file to create. By default, it will be the same as
         the EDF file but with the extension changed to .pbd.
      vanme= The vname to store the data as. By default, it will be the pbd
         file's name without a path or extension.

   SEE ALSO: batch_edf2pbd, pbd2edf, edf_import
*/
   default, pbd, file_rootname(edf) + ".pbd";
   default, vname, file_rootname(file_tail(pbd));
   pbd_save, pbd, vname, edf_import(edf);
}

func batch_pbd2edf(dirname, files=, searchstr=, outdir=, update=, type=, words=) {
/* DOCUMENT batch_pbd2edf, dirname, files=. searchstr=, outdir=, update=,
   types=, words=

   Batch converts PBD files to EDF files.

   Parameter:
      dirname: The input directory where PBD files reside.

   Options:
      files= An array of files to convert. If provided, dirname and searchstr=
         are ignored.
      searchstr= A search string to use for locating files in dirname.
            searchstr="*.pbd" (default)
      outdir= Specifies an output directory for the EDF files. By default, they
         are created alongside the PBD files.
      update= Allows you to skip existing EDF files instead of overwriting.
            update=0    Overwrite existing (default)
            update=1    Skip existing

   The type= and words= options are advanced options and shouldn't normally be
   needed. See edf_export for details.

   SEE ALSO: pbd2edf, edf_export
*/
   default, searchstr, "*.pbd";
   default, update, 0;

   if(is_void(files))
      files = find(dirname, glob=searchstr);

   pbds = unref(files);
   edfs = file_rootname(pbds) + ".edf";
   if(!is_void(outdir))
      edfs = file_join(outdir, file_tail(edfs));

   sizes = file_size(pbds);
   exists = file_exists(edfs);
   if(update && anyof(exists))
      sizes(where(exists)) = 0;
   if(numberof(sizes) > 1)
      sizes = sizes(cum)(2:);
   if(!sizes(0))
      sizes(0) = 1;

   count = numberof(pbds);
   t0 = array(double, 3);
   timer, t0;
   for(i = 1; i <= count; i++) {
      write, format="%d/%d: %s\n", i, count, file_tail(edfs(i));
      if(exists(i)) {
         if(update) {
            write, "-- exists, skipping";
            continue;
         } else {
            write, "-- exists, overwriting";
         }
      }
      pbd2edf, pbds(i), edf=edfs(i), type=type, words=words;
      timer_remaining, t0, sizes(i), sizes(0);
      write, "";
   }
   timer_finished, t0;
}

func batch_edf2pbd(dirname, files=, searchstr=, outdir=, update=) {
/* DOCUMENT batch_edf2pbd, dirname, files=. searchstr=, outdir=, update=

   Batch converts EDF files to PBD files.

   Parameter:
      dirname: The input directory where EDF files reside.

   Options:
      files= An array of files to convert. If provided, dirname and searchstr=
         are ignored.
      searchstr= A search string to use for locating files in dirname.
            searchstr="*.edf" (default)
      outdir= Specifies an output directory for the PBD files. By default, they
         are created alongside the EDF files.
      update= Allows you to skip existing PBD files instead of overwriting.
            update=0    Overwrite existing (default)
            update=1    Skip existing

   SEE ALSO: edf2pbd, edf_import
*/
   default, searchstr, "*.edf";
   default, update, 0;

   if(is_void(files))
      files = find(dirname, glob=searchstr);

   edfs = unref(files);
   pbds = file_rootname(edfs) + ".pbd";
   if(!is_void(outdir))
      pbds = file_join(outdir, file_tail(pbds));

   sizes = file_size(edfs);
   exists = file_exists(pbds);
   if(update && anyof(exists))
      sizes(where(exists)) = 0;
   if(numberof(sizes) > 1)
      sizes = sizes(cum)(2:);
   if(!sizes(0))
      sizes(0) = 1;

   count = numberof(edfs);
   t0 = array(double, 3);
   timer, t0;
   for(i = 1; i <= count; i++) {
      write, format="%d/%d: %s\n", i, count, file_tail(pbds(i));
      if(exists(i)) {
         if(update) {
            write, "-- exists, skipping";
            continue;
         } else {
            write, "-- exists, overwriting";
         }
      }
      edf2pbd, edfs(i), pbd=pbds(i);
      timer_remaining, t0, sizes(i), sizes(0);
      write, "";
   }
   timer_finished, t0;
}
