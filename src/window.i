require, "eaarl.i";

func change_window_style(style, win=, dofma=, dpi=) {
/* DOCUMENT change_window_style, style, win=, dofma=, dpi=
   Changes the style of a Yorick window.
   Parameter:
      style: Name of style sheet to use, such as "work" or "nobox"
   Options:
      win= Window number to change. If not provided, uses current window. If
         there is no current window, then uses window 0.
      dofma= Set to 1 to issue an FMA prior to changing. This avoids the need
         to re-plot the window's contents.
      dpi= The DPI setting to use. Normally either dpi=75 or dpi=100.
*/
   local wdata;
   default, win, current_window();
   default, dofma, 0;
   default, dpi, 75;

   if(win < 0)
      win = window();

   width = height = [];
   if(style == "landscape11x85") {
      if(dpi == 75) {
         width = 825;
         height = 638;
      } else if(dpi == 100) {
         width = 1100;
         height = 850;
      }
   } else {
      if(dpi == 75) {
         width = height = 450;
      } else if(dpi == 100) {
         width = height = 600;
      }
   }

   if(!dofma)
      wdata = plot_hash(win);

   winkill, win;
   window, win, dpi=dpi, style=style+".gs", width=width, height=height;
   window, win, width=0, height=0;
   limits, square=1;

   if(!dofma)
      plot_restore, win, wdata, style=0;
}

func change_window_size(win, winsize, dofma) {
/* DOCUMENT change_window_size(win, winsize, dofma)
   This function is used to change the size of the yorick window.
   INPUT:
      win: window number
      winsize: window size (1=small, 2=medium, 3=large, 4=huge)
      dofma: clear plot (fma).  must be set to 1 to change window size.
   OUTPUT:
      wset: 1 if window size has been changed, 0 otherwise.

      Original: Amar Nayegandhi 12/12/2005.
*/
   if(winsize == 1)
      change_window_style, "work", win=win, dpi=75, dofma=dofma;
   else if(winsize == 2)
      change_window_style, "work", win=win, dpi=100, dofma=dofma;
   else if(winsize == 3)
      change_window_style, "landscape11x85", win=win, dpi=75, dofma=dofma;
   else if(winsize == 4)
      change_window_style, "landscape11x85", win=win, dpi=100, dofma=dofma;
   return 1;
}

func copy_limits(src, dst) {
/* DOCUMENT copy_limits, src, dst
   -or- copy_limits, src
   Copies the limits from window SRC to window DST. DST may be an array to
   apply to multiple windows. If DST is omitted, then the limits from SRC are
   applied to all open windows.
*/
   wbkp = current_window();
   window, src;
   lims = limits();
   default, dst, window_list();
   for(i = 1; i <= numberof(dst); i++) {
      window, dst(i);
      limits, lims(1), lims(2), lims(3), lims(4);
   }
   window_select, wbkp;
}

func window2image(file, win=) {
/* window2image, filename, win=
   Creates an image from the specified window.

   file: The destination filename, such as /path/to/file.png
   win= The window to dump (if not provided will use current window)

   Caveats:
      * This will only work if xwd is on your path.
      * This will only work if convert is on your path.
      * This will only work if the Yorick window is named "Yorick 0" or
        similar. If you have multiple Yoricks running and this one's windows
        are named "Yorick 0 <2>" or similar, this will grab the wrong window.
*/
   // Original David Nagle 2009-01-28
   default, win, max(current_window(), 0);
   dir = mktempdir();
   xwdfile = file_join(dir, "temp.xwd");
   system, swrite(format="xwd -out %s -name 'Yorick %d'", xwdfile, win);
   system, swrite(format="convert %s %s", xwdfile, file);
   remove, xwdfile;
   rmdir, dir;
}

func plot_hash(wsrc, pal=) {
/* DOCUMENT p = plot_hash(wsrc, pal=)

   Save Yorick plot of window wsrc in a Yeti hash. This plot can be restored
   with plot_restore.

   Use pal=0 if you do not want the palette saved.

   See also: plot_restore plot_save plot_load

   Modified from function save_plot in copy_plot.i
*/
   local a,b,c,d,x,y,z;
   local x0,x1,y0,y1,txt;
   local ireg;
   local p1,p2,p3,p4,p5;
   local rp,gp,bp;
   default, pal, 1;

   p = h_new();

   old_win = current_window();
   if(old_win >= 0)
      old_sys = plsys();

   window, wsrc;
   get_style, a, b, c, d;
   h_set, p, "getstyle_p1", a;
   h_set, p, "getstyle_p2", b;
   h_set, p, "getstyle_p3", c;
   h_set, p, "getstyle_p4", d;

   palette, rp, gp, bp, query=1;
   if(!is_void(rp) && pal) {
      rgb_pal = long(rp) + (long(gp)<<8) + (long(bp)<<16);
      h_set, p ,"palette", rgb_pal;
  }

   nbsys = get_nb_sys(wsrc);
   for(i = 0; i <= nbsys; i++) {
      plsys, i;
      lmt = limits();
      nbobj = numberof(plq());
      h_set, p, swrite(format="system_%d",i), i;
      h_set, p, swrite(format="limits_%d",i), lmt;
      for(j = 1; j <= nbobj; j++) {
          prop=plq(j);
          decomp_prop, prop, p1, p2, p3, p4, p5;
          h_set, p, swrite(format="prop1_%d_%d",i,j), (is_void(p1) ? "dummy" : p1);
          h_set, p, swrite(format="prop2_%d_%d",i,j), (is_void(p1) ? "dummy" : p2);
          h_set, p, swrite(format="prop3_%d_%d",i,j), (is_void(p1) ? "dummy" : p3);
          h_set, p, swrite(format="prop4_%d_%d",i,j), (is_void(p1) ? "dummy" : p4);

          rslt = reshape_prop(prop);
          h_set, p, swrite(format="prop5_%d_%d",i,j), (is_void(rslt) ? "dummy" : rslt);
      }
   }

   if(old_win >= 0) {
      window, old_win;
      plsys, old_sys;
   }

   return p;
}

func plot_restore(wout, p, style=, clear=, lmt=, pal=) {
/* DOCUMENT plot_restore, wout, p, clear=, lmt=, pal=

   Restores a plot saved to hash by plot_hash.

   Use lmt=0 to disable restoration of limits.
   Use clear=0 to disable clearing of window before plotting.
   Use pal=0 to disable using palette saved (if present).

   See also: plot_hash plot_save plot_load

   Modified from function load_plot in copy_plot.i
*/
   default, style, 1;
   default, clear, 1;
   default, lmt, 1;
   default, pal, 1;

   old_win = current_window();
   if(old_win >= 0)
      old_sys = plsys();

   window, wout;

   if(style)
      set_style, h_get(p, "getstyle_p1"), h_get(p, "getstyle_p2"),
         h_get(p, "getstyle_p3"), h_get(p, "getstyle_p4");

   if(clear)
      fma;

   if(pal && h_has(p, "palette")) {
      rgb = p.palette;
      palette, char(rgb&0x0000FF), char((rgb&0x00FF00)>>8), char((rgb&0xFF0000)>>16);
   }

   i = 0;
   while(h_has(p, swrite(format="system_%d", ++i))) {
      plsys, p(swrite(format="system_%d", i));
      limits;
      if(lmt)
         limits, p(swrite(format="limits_%d", i));
      j = 0;
      while(h_has(p, swrite(format="prop1_%d_%d", i, ++j))) {
         p1 = h_get(p, swrite(format="prop1_%d_%d", i, j));
         p2 = h_get(p, swrite(format="prop2_%d_%d", i, j));
         p3 = h_get(p, swrite(format="prop3_%d_%d", i, j));
         p4 = h_get(p, swrite(format="prop4_%d_%d", i, j));
         p5 = h_get(p, swrite(format="prop5_%d_%d", i, j));
         replot, p1, p2, p3, p4, p5;
      }
   }
   redraw;

   if(old_win >= 0) {
      window, old_win;
      plsys, old_sys;
   }
}

func plot_save(win, pbd) {
/* DOCUMENT plot_save, win, pbd

   Saves a window's plot to a pbd, which can then later be restored with
   plot_load.

   See also: plot_hash plot_restore plot_load
*/
   if(!is_hash(win))
      win = plot_hash(win);
   hash2pbd, win, pbd;
}

func plot_load(win, pbd) {
/* DOCUMENT plot_load, win, pbd

   Loads a plot to a window that had been saved by plot_save.

   See also: plot_hash plot_restore plot_save
*/
   hash = pbd2hash(pbd);
   plot_restore, win, hash, style=0;
}
