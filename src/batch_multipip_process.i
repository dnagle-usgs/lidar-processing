
func batch_multipip_process (pip_var, data_var, fname_var, ptype_var, qname_var, ply_var, plyname_var) {
   /* amar nayegandhi 05/19/03
   */

  for (i=1;i<=numberof(pip_var);i++) {
	if (ptype_var(i) == 0)  {
	   fs_all = make_fs(latutm=1, q=*pip_var(i), ext_bad_att=1, usecentroid=1);
	   //fs_all = clean_fs(fs_all);
	   write, format="processing for region %d complete\n",i;
	 }
	 if (ptype_var(i) == 1)  {
	   depth_all = make_bathy(latutm = 1, q = *pip_var(i), ext_bad_depth=1, ext_bad_att=1);
	   //depth_all = clean_bathy(depth_all);
	   write, format="processing for region %d complete\n",i;
	   //tkcmd, swrite(format="exp_send \"%s = depth_all \\r\\n\"",data_var(i));
	 }
	 if (ptype_var(i) == 2)  {
	   veg_all = make_veg(latutm=1, q=*pip_var(i), ext_bad_att=1, ext_bad_veg=1, use_centroid=1, use_highelv_echo=1);
	   veg_all = clean_veg(veg_all);
	   write, format="processing for region %d complete\n",i;
	   //tkcmd, swrite(format="exp_send \"%s = veg_all; \\r\\n\"",data_var(i));
	   //tkcmd, swrite(format="expect \">\"");
         }
	 if (ptype_var(i) == 3)  {
	   cveg_all = make_veg(latutm=1, q=*pip_var(i), use_peak=1, multi_peaks=1);
	   write, format="processing for region %d complete\n",i;
	   //tkcmd, swrite(format="exp_send \"%s = cveg_all \\r\\n\"",data_var(i));
         }
	
         // now write processed data to a pbd file
	 q = *pip_var(i);
	 vname = data_var(i);
	 qname = qname_var(i);
	 plyname = plyname_var(i);
	 ply = *ply_var(i);

	 f = createb(fname_var(i));
	 add_variable, f, -1, qname, structof(q), dimsof(q);
	 get_member(f, qname) = q;

	 add_variable, f, -1, plyname, structof(ply), dimsof(ply);
	 get_member(f, plyname) = ply;

	 save, f, vname, qname, plyname;
        /*
	 tkcmd, swrite(format="exp_send \"extern %s\\r\\n\"",data_var(i));
	 tkcmd, swrite(format="exp_send \"vname=\\\"%s\\\"\\r\\n\"",data_var(i));
	 pause (1000);
	junk = 3;
         tkcmd, swrite(format="exp_send \"save, createb(\\\"%s\\\"),vname,%s; \\r\\n\"",fname_var(i),data_var(i));
	junk = 3;
	 tkcmd, swrite("exp_send \"junk = 3\\r\\n\"");
	 pause( 1000);
        */

	 if ((ptype_var(i) == 0) && (is_array(fs_all))) {
	    add_variable, f, -1, vname, structof(fs_all), dimsof(fs_all);
	    get_member(f, vname) = fs_all;
	    close, f;
	    fs_all=[];
	 }
	 if ((ptype_var(i) == 1) && (is_array(depth_all))) {
	    add_variable, f, -1, vname, structof(depth_all), dimsof(depth_all);
	    get_member(f, vname) = depth_all;
	    close, f;
	    depth_all=[];
	 }
	 if ((ptype_var(i) == 2) && (is_array(veg_all))) {
	    add_variable, f, -1, vname, structof(veg_all), dimsof(veg_all);
	    get_member(f, vname) = veg_all;
	    close, f;
	    veg_all=[];
 	 }
	 if ((ptype_var(i) == 3) && (is_array(cveg_all))) {
	    add_variable, f, -1, vname, structof(cveg_all), dimsof(cveg_all);
	    get_member(f, vname) = cveg_all;
	    close, f;
	    cveg_all=[];
	 }
 
   }

}
