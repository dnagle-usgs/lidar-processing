
require, "comparison_fns.i"
require, "dir.i"
func read_file_list(path, fname=, ext=) {
  /* DOCUMENT read_file_list(path, fname=, ext=)
     This function reads the files in the path defined by the ext keyword and writes the list of files onto an array. 
*/
  if (fname) {
     file_names = path+fname;
  } else {
     if (ext) {
       path1 = path+ext;
       system("ls -1 "+path1+" > /tmp/pathls.out");
     } else {
       system("ls -1 "+path+" > /tmp/pathls.out");
     }
     f = open("/tmp/pathls.out", "r");
     line = rdline(f);
     while (strlen(line) > 0) {
       grow, file_names, line;
       line = rdline(f);
     }
     close, f;
     //system("\\rm /tmp/pathls.out");
  }

  if (is_array(file_names)) {
    return file_names
  } 
}
  
func batch_analysis(path, kings=, plot=, ext=, out_txt_results_file=, elv=) {
  /*DOCUMENT batch_analysis(path, plot=, ext=)
    This function does the analysis in a batch mode.  It will first read in all the .bin files in the path and run function compare_pts.  It will then optionally plot the be v/s kings plot.*/
  
  extern diff1;
  //if (!ext) ext = "*.bin";
  if (!kings) kings = read_xyz_ascii_file("/home/amar/terra_ceia_comparison/kings_data/tb_utm.txt", 9829);

  // read all the files in the path
  fname_arr = read_file_list(path,  ext=ext); 
  if (out_txt_results_file) {
    f1 = open(path+out_txt_results_file, "w");
    write, f1, "file/rgnname RMSE ME";
  }

  for (ai = 1; ai <= numberof(fname_arr); ai++) {
    diff1 = 0;
    if (strpart(fname_arr(ai), 0:0) != "L") {
    ptr_out = read_yfile(path, fname_arr = fname_arr(ai));
    data_out = *ptr_out(1);
    afname = (split_path(fname_arr(ai), 0, ext=1))(1)+"_anal.txt";
    compare_pts, data_out, kings, fname=path+afname, buf=100, read_file=1, elv=elv;
    diff1(rms);
    if (out_txt_results_file) {
      iindx = where(abs(diff1) < 1.0);
      write, f1, format="%s %d %d %4.2f %4.2f %d %4.2f %4.2f\n", fname_arr(ai), numberof(data_out), numberof(diff1), diff1(rms)*100, diff1(avg)*100, numberof(diff1)-numberof(iindx), diff1(iindx)(rms)*100, diff1(iindx)(avg)*100;
    }
    //plot_be_kings_elv(path+afname);
    }
  }
  close, f1;

       
}
require, "fitlsq.i"
func plot_be_kings_elv(file_name, ps_ofname=,pse=,out_txt_file=, win=, saveplot=, head_anal=, pdop_anal=, n_data=, path=, donotplot=, cl=, plotcl=, xtitle=, ytitle=) {

// cl = confidence level
// plotcl = set to 1 if you want to plot using the cl value. Otherwise, it only write the RMSE value based on the cl.

  w = window();
  if (is_void(win)) window, 4;
  if (!pse) pse = 1;
  if (is_void(cl)) cl = 0.95 // defaults to 95% cl
  if (is_void(xtitle)) xtitle = "Ground Truth Data (m)"
  if (is_void(ytitle)) ytitle = "Lidar Data (m)"
  
  extern i, n, be, kings_elv, diff1, edb, tans, pnav, pdop_val;
  
  if (path) {
     //find files 
     cmd = swrite(format="find %s -name '*.txt'", path);
     files= "";
     s = array(string,10000);
     f = popen(cmd, 0);
     nn = read(f,format="%s",s);
     s = s(where(s));
     sidx = strmatch(s, "results");
     s = s(where(!sidx));
     numfiles = numberof(s);
  } else numfiles = 1;
     
  if (pdop_anal) pdop=1;
  if (out_txt_file) {
    if (!path) path = (split_path(file_name(1), 0))(1);
    f1 = open(path+out_txt_file, "w");
    write, f1, "n\tRMSE\tME\tMAE\tno_outliers\tR^2\tRMSE_lsq";
  }
  if (!donotplot) {
  winkill, win;
  window, win,dpi=100,style="boxed.gs", width=639, height=639, legends=0;
  if (!ps_ofname) ps_ofname = "~/test_hcp.ps";
  hcp_file, ps_ofname;
  }
  for (ai=1;ai<=numfiles;ai++) {
    if (!file_name) file_name = s(ai);
    read_txt_anal_file, file_name, pdop=pdop;
    diff1(rms);
/*
    idx0 = where(kings_elv > 0);
    i = i(idx0);  be_elv = be_elv(idx0); be = be(idx0); kings_elv = kings_elv(idx0);
    diff1 = diff1(idx0);
    idx0 = where(be > 0);
    i = i(idx0);  be = be(idx0); kings_elv = kings_elv(idx0);
    diff1 = diff1(idx0);
  */  
    if (pdop_anal) {
   	//pdop_ret = pdop_analysis(pnav, edb, i=i);
        //pidx = where(pdop_ret <= pdop_anal+0.01);
        pidx = where(pdop_val <= pdop_anal+0.01);
        diff1 = diff1(pidx);
	be = be(pidx);
	kings_elv = kings_elv(pidx);
    }
    n_orig = numberof(diff1);
    // at confidence level
    noc = cl*numberof(diff1);
    clmx = max(abs(diff1));
    for (cli=clmx;cli>0;) {
      iindx = where(abs(diff1) < cli);
      if (numberof(iindx) <= noc) break;
      cli -= 0.01;
    }
    write, format="At %2d%% confidence level, number of points = %d, within %f m\n",int(cl*100),numberof(iindx), cli
    if (plotcl) {
      diff1 = diff1(iindx);
      kings_elv = kings_elv(iindx);
      be = be(iindx);
      i = i(iindx);
    }
    fma;
    if (!donotplot) {
    plmk, be, kings_elv, width=10, marker=4, msize=0.1, color="black";
    limits, square=1;
  //  limits, -1,3,-1,3
   // limits, max(be), min(be), max(kings_elv), min(kings_elv)
    limits;
    xytitles, xtitle, ytitle;
    //pltitle, (split_path(file_name(ai), -1))(2);
    }
    mx_y = min(max(be), max(kings_elv));
    mx_x = max(min(be), min(kings_elv));
    //if (numberof(iindx) < numberof(diff1)) {
    //rleg = swrite(format="RMSE = %4.2f cm, RMSE_o_ = %4.2f cm", diff1(rms)*100, diff1(iindx)(rms)*100); 
    //aleg = swrite(format="ME = %4.2f cm, ME_o_ = %4.2f cm", diff1(avg)*100, diff1(iindx)(avg)*100); 
    //nleg = swrite(format="n = %d, Outliers = %d", numberof(diff1), numberof(diff1) - numberof(iindx)); 
    //} else {
    mae = sum(abs(be-kings_elv))/numberof(be);
    if (cl) {
      //rleg = swrite(format="RMSE_%2d%%_ = %4.1f cm", int(cl*100), diff1(iindx)(rms)*100); 
      rleg = swrite(format="RMSE = %4.1f cm", diff1(rms)*100); 
    } else {
      rleg = swrite(format="RMSE = %4.1f cm", diff1(iindx)(rms)*100); 
    }
    aleg = swrite(format="ME = %4.1f cm", diff1(avg)*100);
    nleg = swrite(format="n = %d", numberof(diff1));
    maeleg = swrite(format="MAE = %4.2f cm", mae*100);
    //}
    // least squares fit line
    xp = [min(kings_elv), max(kings_elv)];
    //xp = [-1,3]
    yp = fitlsq(be, kings_elv, xp);
    // find m and c for the lsfit straight line y = mx + c;
    m = (yp(2)-yp(1))/(xp(2)-xp(1));
    c = yp(1) - m*xp(1);
    // computing correlation coefficient r squared (rsq)
    ydash = m*kings_elv + c;
    xmean = avg(kings_elv);
    ymean = avg(be);
    //rsq = (sum((kings_elv-xmean)*(be-ymean)))^2/((sum((kings_elv-xmean)^2))*(sum((be-ymean)^2)));
    rsq = (sum((ydash-ymean)^2))/(sum((be-ymean)^2));
    //write, format="rsq new = %6.4f; rsq old = %6.4f\n",rsq, rsq1;
    rmslsq = (ydash-be)(rms);
    rsqleg = swrite(format="R^2^ = %4.3f", rsq);
    rmslsqleg = swrite(format="RMSE_lsq_ = %4.2f cm",rmslsq*100);
    if (pdop_anal) pdopleg = swrite(format="PDOP <= %3.1f",double(pdop_anal));
    if (!donotplot) {
    plg, [mx_x, mx_y], [mx_x, mx_y], width=3.0, type=2;
    plg, yp, xp, color="black", width=3.0;
    plt, rleg, 0.2, 0.82;
    plt, aleg, 0.2, 0.8;
    //plt, maeleg, 0.2, 0.80;
    plt, rsqleg, 0.2, 0.78;
    //plt, rmslsqleg, 0.2, 0.76;
    if (pdop_anal) {
      plt, pdopleg, 0.2, 0.74
      plt, nleg, 0.2, 0.72;
    } else {
      plt, nleg, 0.2, 0.74;
    }
    hcp;
    pause, pse;
    }
    if (saveplot) {
      system("/usr/bin/xwd -out "+file_name(ai)+".xwd");
      system("/usr/bin/convert "+file_name(ai)+".xwd "+file_name(ai)+".png");
      system("\\rm "+file_name(ai)+".xwd");
    }
    if (out_txt_file) {
      write, f1, format="%d\t%4.2f\t%4.2f\t%4.2f\t%d\t%4.2f\t%4.2f\n", numberof(diff1), diff1(rms)*100, diff1(avg)*100, mae*100, n_orig-numberof(diff1), rsq, rmslsq*100.;
    }
  }
  close, f1

  window, w;
  return

}


func batch_rgn_anal(eaarl, kings_arrays=, analpath=, type=, win=, buf=, date=, saveplot=, selall=, results_file=, rgn_name=, pdop=, rcfw=, n_data=) {
  // amar nayegandhi 07/30/03
  
  extern kings;
  if (!analpath) analpath="/home/amar/terra_ceia_comparison/s03/s03_anal/"
  if (!type) type = VEG__;

  if (is_void(win)) win = 5;
  if (!buf) buf = 100;
  time = timestamp();
  if (!date) {
      p = *pointer(time);
      q = where(p == ' ');
      p(q) = '_';
      q = where(p == ':');
      p(q) = '-';
      date = string(&p);
  }
  //if (!date) date = strpart(timestamp(), 5:7)+strpart(timestamp(),10:10)+strpart(timestamp(),-3:0);
  window, win;
  cont = 1;
  sel = "";
  count = 0;
  if (!rgn_name) rgn_name = "rgn";
  while (cont) {
    if (is_array(kings_arrays)) {
        kings_fs = kings_arrays;
	kings = transpose([kings_fs.east/100., kings_fs.north/100., kings_fs.elevation/100.]);
	cont=0;
    } else {
      n = read(prompt="Select another region? y/n:", sel); 
      if (sel != "y") break;
    }
	  count++;
          if (type == VEG__) {
	   if (!selall) {
            eaarl1 = sel_data_rgn(eaarl, mode=3, win=win)
	   } else {
    	    if (is_array(kings_arrays)) {
		e1 = data_box(eaarl.east/100., eaarl.north/100., min(kings(1,))-5, max(kings(1,))+5, min(kings(2,))-5, max(kings(2,))+5);
		eaarl1 = eaarl(e1);
            } else {
	       eaarl1 = eaarl;
	    }
	    cont = 0;
	   }
	    fname = swrite(format="eaarl-%s%d-buf%d-%s.txt",rgn_name, count, buf, date);
	    if (rcfw) fname = swrite(format="rcf-eaarl-%s%d-buf%d-%s.txt",rgn_name, rcfw, buf, date);
            if (results_file) out_txt_file=swrite(format="eaarl-%s%d-buf%d-%s-results.txt",rgn_name, count,buf,date);
          } 
          if (type == FS) {
	   if (!selall) {
            eaarl1 = sel_data_rgn(eaarl, mode=3, win=win)
           } else {
              if (is_array(kings_arrays)) {
                e1 = data_box(eaarl.east/100., eaarl.north/100., min(kings(1,))-5, max(kings(1,))+5, min(kings(2,))-5, max(kings(2,))+5);
                eaarl1 = eaarl(e1);
              } else {
		eaarl1 = eaarl;
	      }
	      cont = 0;
	    }
	    fname = swrite(format="uf-%s%d-buf%d-%s.txt",rgn_name, count, buf, date);
            if (results_file) out_txt_file=swrite(format="uf-%s%d-buf%d-%s-results.txt",rgn_name, count,buf,date);
          }
 	  rgn = [min(eaarl1.east)/100., max(eaarl1.east)/100., 
		  min(eaarl1.north)/100., max(eaarl1.north)/100.];
          if (type == VEG__) {
	    compare_pts(eaarl1, kings, rgn, fname=analpath+fname, buf=buf, pdop=pdop);
          } 
	  if (type == FS) {
	    compare_pts(eaarl1, kings, rgn, fname=analpath+fname, buf=buf, elv=1);
          }
 	  plot_be_kings_elv, analpath+fname, win=3, saveplot=saveplot, out_txt_file=out_txt_file, n_data=n_data;
  }
  return
}


func pdop_analysis(pnav, edb, txt_file=, i=) {
  // amar nayegandhi 080803
  if (txt_file)
    read_txt_anal_file, txt_file;
  count = 0;
  i_raster = i & 0xffffff;
  pdop_ret = array(float, numberof(i));
  for (ic=1;ic<=numberof(i); ic++) {
    idx = where(pnav.sod ==  edb.seconds(i_raster(ic)) - soe_day_start);
    pdop_ret(ic) = pnav.pdop(idx(1));
  }
  return pdop_ret;
}

func heading_analysis(tans, edb, txt_file=) {
  // amar nayegandhi 080803
  dhead = tans.heading(dif);
  read_txt_anal_file, txt_file;
  i_raster = i & 0xffffff;
  head_ret = array(float, numberof(i));
  for (ic=1;ic<=numberof(i); ic++) {
    idx = (abs(tans.somd -  ((edb.seconds(i_raster(ic))+edb.fseconds(i_raster(ic))*1e-6) - soe_day_start))(mnx));
    head_ret(ic) = avg(dhead(idx(1))+dhead(idx(1)));
  }
  return head_ret;
  
}

func batch_pdop_anal(txt_file, out_dir=, pdop_range=, win=){
//amar nayegandhi 080803
  extern be, kings_elv, diff1, edb, tans, pnav;
  if (!win) win = 3;
  fname = split_path(txt_file, 0);
  ffn = split_path(fname(2), 0, ext=1);
  for (pi=pdop_range(1); pi<=pdop_range(2); pi+=0.1) {
    out_txt_file = ffn(1)+"-pdop-"+swrite(format="%2.1f",pi)+ffn(2);
    plot_be_kings_elv, txt_file, out_txt_file=out_txt_file, pdop_anal = pi, win=win, saveplot=1;
  }
}


func day_pdop_vals(eaarl, pnav) {
 // amar nayegandhi 080903
 extern soe_day_start;
 eaarl = eaarl(sort(eaarl.soe));
 day_soe = int(eaarl.soe + 0.5 - soe_day_start);
 idx = unique(day_soe, ret_sort=1);
 day_pnav = array(float, numberof(eaarl));
 for (ic = 1; ic<= numberof(idx); ic++) {
   iidx = (abs(pnav.sod - day_soe(idx(ic))))(mnx)
   if (ic == numberof(idx)) {
     day_pnav(idx(ic):) = pnav.pdop(iidx(1));
   } else {
     day_pnav(idx(ic):idx(ic+1)-1) = pnav.pdop(iidx(1));
   }
 }
 return day_pnav;
}


func batch_tans_pdop_anal(txt_file, tans_split=, pdop_split=, cumulative=) {
  // amar nayegandhi 080903
  if (!tans_split) tans_split = 12;
  if (!pdop_split) pdop_split = 0.1;
  if (is_void(cumulative)) cumulative = 1;
  //PI = atan(1)*4.0;
  extern i, no, be, kings_elv, diff1, pdop_val, be_avg_pts, diff2, be_elv;
  fname = split_path(txt_file, 0);
  ffn = split_path(fname(2), 0, ext=1);
  out_txt_file = fname(1)+ffn(1)+"-pdop-tans-results.txt"
  f1 = open(out_txt_file, "w");
  write, f1, "tans pdop n RMSE ME MAE no_outliers R^2 RMSE_lsq";
  read_txt_anal_file, txt_file, pdop=1;
  //split by tans
  rns = i / 0xffffff;
  ntans = 120/tans_split;
  min_pdop = min(pdop_val);
  max_pdop = max(pdop_val);
  npdop = (max_pdop - min_pdop)/pdop_split;
  for (ic=1;ic<=tans_split;ic++) {
    tans1 = 60 - ntans*ic/2.;
    tans2 = 60 + ntans*ic/2.;
    tidx = where((rns >= tans1) & (rns <= tans2));
    if (!is_array(tidx)) continue;
    // split by pdop
    for (jc=min_pdop;jc<=max_pdop;jc+=pdop_split) {
      if (cumulative) {
        pidx = where(pdop_val(tidx) <= jc+0.01);
      } else {
        pidx = where((pdop_val(tidx) >= jc-0.01) & (pdop_val(tidx) <= jc+0.01));
      }
      if (numberof(pidx)<=1) continue;
      tpi = i(tidx(pidx));
      tpdiff1 = diff1(tidx(pidx));
      tpno = no(tidx(pidx));
      tpbe = be(tidx(pidx));
      tpkings_elv = kings_elv(tidx(pidx));
      
      n_orig = numberof(tpdiff1);
      // at 95% confidence level
      noc = .95*numberof(tpdiff1);
      for (cli=2.0;cli>0;) {
        iindx = where(abs(tpdiff1) < cli);
        if (numberof(iindx) <= noc) break;
        cli -= 0.01;
      }
      write, format="At 95%% confidence level, number of points = %d, within %f m\n",numberof(iindx), cli
      tpdiff1 = tpdiff1(iindx);
      tpkings_elv = tpkings_elv(iindx);
      tpbe = tpbe(iindx);
      mx_y = min(max(tpbe), max(tpkings_elv));
      mx_x = max(min(tpbe), min(tpkings_elv));
      mae = sum(abs(tpbe-tpkings_elv))/numberof(tpbe);
      // least squares fit line
      xp = [min(tpkings_elv), max(tpkings_elv)];
      yp = fitlsq(tpbe, tpkings_elv, xp);
      // find m and c for the lsfit straight line y = mx + c;
      m = (yp(2)-yp(1))/(xp(2)-xp(1));
      c = yp(1) - m*xp(1);
      // computing correlation coefficient r squared (rsq)
      ydash = m*tpkings_elv + c;
      ymean = avg(tpbe);
      rsq = (sum((ydash-ymean)^2))/(sum((tpbe-ymean)^2));
      rmslsq = (ydash-tpbe)(rms);
      write, f1, format="%6.3f %4.2f %d %4.2f %4.2f %4.2f %d %4.2f %4.2f\n", ((tans2- tans1)/120.)*45., jc, numberof(tpdiff1), tpdiff1(rms)*100, tpdiff1(avg)*100, mae*100, n_orig-numberof(tpdiff1), rsq, rmslsq*100.;
      
     }
  }
  close, f1;  
  return
  
}

func read_batch_tans_pdop_file(fname) {
  //amar nayegandhi 081203
  extern tans_val,pdop_val, no, rmse, me, mae, no_outliers, rsq, rmse_lsq;
  f = open(fname, "r");
  xx = 0;
  do {
    line = rdline(f);
    xx++;
  } while (strlen(line) > 0);
  n = xx-1;
  close, f;

  tans_val = array(float,n)
  pdop_val = array(float, n)
  no =  array(int, n)
  rmse = array(float, n)
  me = array(float, n)
  mae = array(float, n)
  no_outliers = array(int, n)
  rsq  = array(float, n)
  rmse_lsq = array(float, n)
  f1 =open(fname, "r");
  read, f1, format="%f %f %d %f %f %f %d %f %f",tans_val,pdop_val, no, rmse, me, mae, no_outliers, rsq, rmse_lsq;
  pdop_val = int(pdop_val*100)/100.0;
  rmse = int(rmse*100)/100.0;
  me = int(me*100)/100.;
  mae = int(mae*100)/100.;
  rsq = int(rsq*10000)/10000.0;
  rmse_lsq = int(rmse_lsq*100)/100.0;
  close, f1;
  return
}

func make_2d_tans_pdop_array(junk, fname=) {
  //amar nayegandhi 081303
  extern tans_val,pdop_val, no, rmse, me, mae, no_outliers, rsq, rmse_lsq;
  if (fname) read_batch_tans_pdop_file, fname;
  idx = unique(tans_val);
  xx = unique(pdop_val);
  rmsearr = array(float, numberof(idx), numberof(xx));
  noarr = array(int, numberof(idx), numberof(xx));
  for (ic=1;ic<=numberof(idx);ic++) {
     for (jc=1;jc<=numberof(xx);jc++) {
        tpidx = where((tans_val == tans_val(idx(ic))) & (pdop_val == pdop_val(xx(jc))));
        if (is_array(tpidx)) {
          rmsearr(ic,jc) = rmse(tpidx);
          noarr(ic,jc) = no(tpidx);
        }
     }
  }
  frmse = fname+".rmse";
  f = open(frmse,"w");
  for (ic=1;ic<=numberof(idx);ic++) {
    write, f, format="%4.2f ",rmsearr(ic,);
    write, f, "\n"
  }
  close, f;
  fno = fname+".no"
  f = open(fno,"w");
  for (ic=1;ic<=numberof(idx);ic++) {
    write, f, format="%d ",noarr(ic,);
    write, f, "\n"
  }
  close, f;
  
return [&rmsearr, &noarr]
}
         
	
func batch_rcf_compare(day123, path=, kings_fs=) {
  //amar nayegandhi
  // 081403
  if (!path) path = "/home/amar/terra_ceia_comparison/s03/s03_anal/good/eaarl-density-effect/";
  if (!is_array(kings_fs)) {
    kf = openb("/home/amar/terra_ceia_comparison/s03/s03_eaarl_data/kings_data_fs_format_080503.pbd")
    restore, kf, vname;
    kings_fs = get_member(kf,vname);
  }
  if (!rgn_name) rgn_name="rgn";
  for (ic=5;ic<=100;ic+=5) { 
    time = timestamp();
    p = *pointer(time);
    q = where(p == ' ');
    p(q) = '_';
    q = where(p == ':');
    p(q) = '-';
    date = string(&p);
    fname = swrite(format="rcf-eaarl-%s-b400-w%d-%s.pbd",rgn_name, ic, date);
     write, format="Rcf'ing region %d\n",ic;
     rcf_day = rcfilter_eaarl_pts(day123, buf=400, w=ic, mode=3);
     f = createb(path+fname);
     vname = "rcf_day123_"+swrite(format="%d",ic);
     add_variable, f, -1, vname, structof(rcf_day), dimsof(rcf_day);
     get_member(f,vname) = rcf_day;
     close, f;
     batch_rgn_anal, rcf_day, kings_arrays=kings_fs, analpath=path, type=VEG__, win=5, date=date,  selall=1, results_file=1, rgn_name=rgn_name, rcfw=ic, n_data=numberof(rcf_day);
     
  }

return
}
     

func plot_batch_veg_kings_rgns(day123, ll) {
   //amar nayegandhi 08/18/03
   f = openb("/home/amar/terra_ceia_comparison_s03/s03_kings/kings-vegtype-regions-080703.pbd");
   restore, f;
   close, f;
   winkill, 5; window, 5, dpi=100, width=1100, height=850, style="landscape11x85.gs";fma; limits, square=1;
   display_veg, day123, win=5, cmin=-1.0, cmax = 14.0, size = 1.3, edt=1, felv = 1, lelv=0, fint=0, lint=0, cht = 0, marker=1, skip=1;
   plmk, k_aus_pine.north/100., k_aus_pine.east/100., msize=0.1, marker=1, color="black",width=5.0;
   plmk, k_dense_bp.north/100., k_dense_bp.east/100., msize=0.1, marker=2, color="red",width=5.0;
   plmk, k_sparse_bp.north/100., k_sparse_bp.east/100., msize=0.1, marker=3, color="blue",width=5.0;
   plmk, k_needle_grass.north/100., k_needle_grass.east/100., msize=0.1, marker=4, color="green",width=5.0;
   plmk, k_mangrove.north/100., k_mangrove.east/100., msize=0.1, marker=5, color="yellow",width=5.0;
   plmk, k_mulched.north/100., k_mulched.east/100., msize=0.1, marker=6, color="magenta",width=5.0;
   limits, ll(1), ll(2), ll(3), ll(4);
   xytitles, "UTM Easting(m)", "UTM Northing(m)";
   plmk, 3052120, 346100, marker=1, msize=1.5, color="black", width=10;
   plt, "Australian Pine", 346200, 3052120, tosys=1, color="black";
   plmk, 3051920, 346100, marker=2, msize=1.5, color="red", width=10;
   plt, "Dense Brazilian Pepper", 346200, 3051920, tosys=1, color="red";
   plmk, 3051720, 346100, marker=3, msize=1.5, color="blue", width=10;
   plt, "Sparse Brazilian Pepper", 346200, 3051720, tosys=1, color="blue";
   plmk, 3052120, 347200, marker=4, msize=1.5, color="green", width=10;
   plt, "Needle Grass", 347300, 3052120, tosys=1, color="green";
   plmk, 3051920, 347200, marker=5, msize=1.5, color="yellow", width=10;
   plt, "Mangroves", 347300, 3051920, tosys=1, color="yellow";
   plmk, 3051720, 347200, marker=6, msize=1.5, color="magenta", width=10;
   plt, "Mulched Area", 347300, 3051720, tosys=1, color="magenta";
   
   
   return
}


