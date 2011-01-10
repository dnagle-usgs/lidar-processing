// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func pcobj_to_old_fs(data, fs=, mirror=) {
   extern current_cs;
   default, fs, "first_surface";
   default, mirror, "mirror";

   fsdata = data(index, fs);
   if(is_void(fsdata) || !fsdata(count,))
      return [];

   result = array(FS, fsdata(count,));
   result.soe = fsdata(soe,);
   result.east = long(fsdata(x,)*100. + 0.5);
   result.north = long(fsdata(y,)*100. + 0.5);
   result.elevation = long(fsdata(z,)*100. + 0.5);
   result.intensity = fsdata(intensity,);
   fsdata = [];

   mirdata = data(index, mirror);
   if(is_void(mirdata) || !mirdata(count,))
      return result;

   result = result(sort(result.soe));
   mirdata = mirdata(index, sort(mirdata(soe,)));
   i = j = 1;
   in = numberof(result);
   jn = mirdata(count,);
   while(i <= in && j <= jn) {
      if(result.soe(i) < mirdata(soe,j))
         i++;
      if(mirdata(soe,j) < result.soe(i))
         j++;
      if(result.soe(i) == mirdata(soe,j)) {
         result(i).meast = long(mirdata(x,j)*100. + 0.5);
         result(i).mnorth = long(mirdata(y,j)*100. + 0.5);
         result(i).melevation = long(mirdata(z,j)*100. + 0.5);
         i++;
         j++;
      }
   }
   return result;
}

func pcobj_to_old_veg(data, fs=, be=, mirror=) {
   default, be, "bare_earth";
   temp = pcobj_to_old_fs(data, fs=fs, mirror=mirror);

   if(is_void(temp)) {
      temp = pcobj_to_old_fs(data, fs=be, mirror=mirror);
      if(is_void(temp))
         return [];
      result = struct_cast(temp, VEG__);
      result.least = result.east;
      result.lnorth = result.north;
      result.lelv = result.elevation;
      result.fint = result.lint = temp.intensity;
      return result;
   }

   result = struct_cast(temp, VEG__);
   result.fint = temp.intensity;
   temp = [];

   bedata = data(index, be);
   if(is_void(bedata) || !bedata(count,))
      return result;

   result = result(sort(result.soe));
   bedata = bedata(index, sort(bedata(soe,)));
   i = j = 1;
   in = numberof(result);
   jn = bedata(count,);
   beused = array(short(0), in);
   while(i <= in && j <= jn) {
      if(result.soe(i) < bedata(soe,j))
         i++;
      if(bedata(soe,j) < result.soe(i))
         j++;
      if(result.soe(i) == bedata(soe,j)) {
         beused(j) = 1;
         result(i).least = long(bedata(x,j)*100. + 0.5);
         result(i).lnorth = long(bedata(y,j)*100. + 0.5);
         result(i).lelv = long(bedata(z,j)*100. + 0.5);
         result(i).lint = bedata(intensity,j);
         i++;
         j++;
      }
   }
   
   w = where(!beused);
   if(!numberof(w))
      return result;

   grow, result, pcobj_to_old_veg(bedata(index, w), fs=fs, be=be,
      mirror=mirror);

   return result;
}
