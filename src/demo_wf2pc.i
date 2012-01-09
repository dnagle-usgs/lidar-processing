// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func batch_wf2pc(dir, outdir=, searchstr=, files=) {
   default, searchstr, "*.pbd";
   if(is_void(files)) {
      files = find(dir, glob=searchstr);
   }

   outfiles = file_rootname(files) + "_pc.pbd";
   if(!is_void(outdir)) {
      mkdirp, outdir;
      outfiles = file_join(outdir, file_tail(outfiles));
   }

   for(i = 1; i <= numberof(files); i++) {
      write, format="%d/%d: %s\n", i, numberof(files), file_tail(outfiles(i));
      file_wf2pc, files(i), outfiles(i);
   }
}

func file_wf2pc(fnwf, fnpc) {
   pc = wf2pc(wfobj(fnwf));
   pc, save, fnpc;
}

func wf2pc(wf) {
   raw_xyz = array(double, 3, wf.count);
   soe = array(double, wf.count);
   raster_seconds = raster_fseconds = array(long, wf.count);
   pulse = channel = flag_irange_bit14 = flag_irange_bit15 =
         array(char, wf.count);
   intensity = tx_pixel = rx_pixel = array(float, wf.count);
   return_number = number_of_returns = array(short, wf.count);

   last = 0;

   _txs = wfs_extract("peak", wf.tx);
   _rxs = wfs_extract("peak", wf.rx);

   sample2m = wf.sample_interval * NS2MAIR;
   for(i = 1; i <= wf.count; i++) {
      _tx = *_txs(i);
      _rx = *_rxs(i);
      for(j = 1; j <= numberof(_rx); j++) {
         last++;
         if(last > numberof(soe)) {
            array_allocate, raw_xyz, last;
            array_allocate, soe, last;
            array_allocate, raster_seconds, last;
            array_allocate, raster_fseconds, last;
            array_allocate, pulse, last;
            array_allocate, channel, last;
            array_allocate, flag_irange_bit14, last;
            array_allocate, flag_irange_bit15, last;
            array_allocate, intensity, last;
            array_allocate, tx_pixel, last;
            array_allocate, rx_pixel, last;
            array_allocate, return_number, last;
            array_allocate, number_of_returns, last;
         }
         soe(last) = wf.soe(i);
         raster_seconds(last) = wf.raster_seconds(i);
         raster_fseconds(last) = wf.raster_fseconds(i);
         pulse(last) = wf.pulse(i);
         channel(last) = wf.channel(i);
         flag_irange_bit14(last) = wf.flag_irange_bit14(i);
         flag_irange_bit15(last) = wf.flag_irange_bit15(i);
         intensity(last) = interp(*wf.rx(i), indgen(numberof(*wf.rx(i))), _rx(j));
         tx_pixel(last) = _tx;
         rx_pixel(last) = _rx(j);
         return_number(last) = j;
         number_of_returns(last) = numberof(_rx);

         dist = (_rx(j) - _tx) * sample2m;
         raw_xyz(..,last) = point_project(wf(raw_xyz0,i,), wf(raw_xyz1,i,), dist);
      }
   }
   if(last < numberof(soe)) {
      raw_xyz = raw_xyz(.., :last);
      soe = soe(:last);
      raster_seconds = raster_seconds(:last);
      raster_fseconds = raster_fseconds(:last);
      pulse = pulse(:last);
      channel = channel(:last);
      flag_irange_bit14 = flag_irange_bit14(:last);
      flag_irange_bit15 = flag_irange_bit15(:last);
      intensity = intensity(:last);
      tx_pixel = tx_pixel(:last);
      rx_pixel = rx_pixel(:last);
      return_number = return_number(:last);
      number_of_returns = number_of_returns(:last);
   }
   raw_xyz = transpose(raw_xyz);

   pc = save(cs=wf.cs);
   if(wf(*,"source")) save, pc, source=wf.source;
   if(wf(*,"system")) save, pc, system=wf.system;
   save, pc, raw_xyz, soe, raster_seconds, raster_fseconds, pulse, channel,
      intensity, tx_pixel, rx_pixel, return_number, number_of_returns,
      flag_irange_bit14, flag_irange_bit15;
   pcobj, pc;
   pc, class, set, "first_surface", pc.return_number == 1;
   pc, class, set, "bare_earth", pc.return_number == pc.number_of_returns;

   return pc;
}
