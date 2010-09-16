// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func pcobj_from_old(data, cs=) {
   return pcobj_from_old_modes(data, cs=cs);
}

func pcobj_from_old_modes(data, cs=) {
/* DOCUMENT result = pcobj_from_old_modes(data, cs=)
   Converts data in the old ALPS format into a point cloud object.

   DATA must be an array using one of the old ALPS structures such as VEG__,
   FS, GEO, etc.

   CS should be the coordinate system of the data. It will default to WGS84
   using extern CURZONE for the zone (or, if not defined, uses lat/long). This
   is probably not trustworthy though, so you should provide the coordinate
   system directly. Examples:
      cs=cs_wgs84(zone=18)
      cs=cs_nad83(zone=14)
      cs=cs_navd88(zone=17, geoid="03")

   SEE ALSO: pcobj
*/
   local raw_xyz, intensity, soe, record, class;
   default, cs, cs_wgs84(zone=curzone);

   modes = ["ba","be","fs"];
   mode_intensity = ["lint", "lint", "fint"];
   mode_name = ["submerged_topo", "bare_earth", "first_surface"];

   nmodes = numberof(modes);
   for(i = 1; i <= nmodes; i++) {
      if(!datahasmode(data, mode=modes(i)))
         continue;
      tp_grow, raw_xyz, data2xyz(data, mode=modes(i));
      if(datahasmode(data, mode=mode_intensity(i)))
         tp_grow, intensity, data2xyz(data, mode=mode_intensity(i))(..,3);
      else
         tp_grow, intensity, array(0, dimsof(data));
      tp_grow, soe, data.soe;
      tp_grow, record, data.rn;
      tp_grow, class, array(mode_name(i), dimsof(data));
   }

   res = pcobj(save(cs, raw_xyz, intensity, soe, record));

   class_names = set_remove_duplicates(class);
   nclass = numberof(class_names);
   for(i = 1; i <= nclass; i++)
      res, class, set, class_names(i), (class == class_names(i));

   return res;
}
