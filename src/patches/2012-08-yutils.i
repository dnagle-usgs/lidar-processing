/*
  This file contains a patch for the yorick-yutils extension that ALPS relies
  on. Two functions are patched to add additional functionality.

  These functions are being submitted to the maintainer of yorick-yutils for
  inclusion in the extension. If included, this file will be deprecated and
  eventually removed.
*/

func save_plot(fstrm,wsrc,pal=)
/* DOCUMENT save_plot,fstrm,win,pal=
   -or- grp = save_plot(win,pal=)
   Save Yorick plot of window win in fstrm, which may be a filename, file
   stream, or empty oxy group object. If called as a function, will return an
   oxy group object. The plot can be reloaded with load_plot.

   KEYWORDS: pal= : save the palette if any in the file (the default)
   
   EXAMPLE:
   window,0;
   pli,random(100,100);
   pltitle,"Random array";
   limits,20,60,10,70;
   plt,"Zoom In",40,40,tosys=1,color="yellow",height=18;
   save_plot,"rand_array.gdb",0;
   load_plot,"rand_array.gdb",1;
   
   SEE ALSO: load_plot,copy_win
 */
{
  local a,b,c,d,x,y,z;
  local x0,x1,y0,y1,txt;
  local ireg;
  local p1,p2,p3,p4,p5;
  local rp,gp,bp;

  if(is_void(pal)) pal=1;

  autoclose=0;
  if(!am_subroutine()) {
    wrsc=fstrm;
    fstrm=save();
  } else if(is_string(fstrm)) {
    fstrm=createb(fstrm);
    autoclose=1;
  }
  old_win=current_window();
  if(old_win>=0) old_sys=plsys();
  window,wsrc;
  get_style,a,b,c,d;
  save,fstrm,"getstyle_p1",a;
  save,fstrm,"getstyle_p2",b;
  save,fstrm,"getstyle_p3",c;
  save,fstrm,"getstyle_p4",d;

  palette,rp,gp,bp,query=1;
  if(!is_void(rp)&&pal) {
    rgb_pal=long(rp)+(long(gp)<<8)+(long(bp)<<16);
    save,fstrm,"palette",rgb_pal;
  }

  nbsys=get_nb_sys(wsrc);
  for(i=0;i<=nbsys;i++)
    {
      plsys,i;
      lmt=limits();
      nbobj=numberof(plq());
      save,fstrm,swrite(format="system_%d",i),i;
      save,fstrm,swrite(format="limits_%d",i),lmt;
      for(j=1;j<=nbobj;j++)
        {
          prop=plq(j);
          decomp_prop,prop,p1,p2,p3,p4,p5;
          save,fstrm,swrite(format="prop1_%d_%d",i,j),(is_void(p1)?"dummy":p1);
          save,fstrm,swrite(format="prop2_%d_%d",i,j),(is_void(p2)?"dummy":p2);
          save,fstrm,swrite(format="prop3_%d_%d",i,j),(is_void(p3)?"dummy":p3);
          save,fstrm,swrite(format="prop4_%d_%d",i,j),(is_void(p4)?"dummy":p4);

          rslt=reshape_prop(prop);
          save,fstrm,swrite(format="prop5_%d_%d",i,j),(is_void(rslt)?"dummy":rslt);
        }
    }
  if(autoclose) close,fstrm;
  if(old_win>=0)
    {
      window,old_win;
      plsys,old_sys;
    }
  if(!am_subroutine()) return fstrm;
}


func load_plot(fstrm,wout,clear=,lmt=,pal=,style=,systems=)
/* DOCUMENT load_plot,fstrm,wout,clear=,lmt=,pal=,style=,systems=
   Load Yorick plot from fstrm (which may be a filename, file stream, or empty
   oxy group object) and plot in wout. The plot have to be saved with
   save_plot.

   EXAMPLE:
   window,0;
   pli,random(100,100);
   pltitle,"Random array";
   limits,20,60,10,70;
   plt,"Zoom In",40,40,tosys=1,color="yellow",height=18;
   save_plot,"rand_array.gdb",0;
   load_plot,"rand_array.gdb",1;

   KEYWORDS: lmt=   if set (default), restore also the
                    limits
             clear= if set (default) erase the window
                    before loading
             pal=   use the palette saved in the file if any (the default)
             style= use the style saved in the file if any (the default)
             systems= set to an array of system numbers to only load those
                    systems; all systems specified must exist in plot being
                    loaded
   
   SEE ALSO: save_plot,copy_win
 */
{
  if(is_void(clear)) clear=1;
  if(is_void(  lmt)) lmt=1;
  if(is_void(  pal)) pal=1;
  if(is_void(style)) style=1;

  autoclose=0;
  if(is_string(fstrm)) {
    fstrm=openb(fstrm);
    autoclose=1;
  }
  old_win=current_window();
  if(old_win>=0) old_sys=plsys();

  window,wout;
  if(style)
    set_style,fstrm.getstyle_p1,fstrm.getstyle_p2,fstrm.getstyle_p3,fstrm.getstyle_p4;
  if(clear) fma;
  names=is_stream(fstrm) ? *get_vars(fstrm)(1) : fstrm(*,);

  palette_is_present=anyof(names=="palette");
  if(palette_is_present&&pal) {
    rgb=fstrm.palette;
    palette,char(rgb&0x0000FF),char((rgb&0x00FF00)>>8),char((rgb&0xFF0000)>>16);
  }
  
  nnames=numberof(names);
  idx=4+palette_is_present;
  skip=0;
  while(++idx<=nnames)
    {
      if(strmatch(names(idx),"system_"))
        {
          sys=get_member(fstrm,names(idx));
          if(!is_void(systems)) {
            skip=0;
            if(noneof(sys==systems)) {
              skip=1;
              continue;
            }
          }
          plsys,sys;
          limits;
          continue;
        }
      if(strmatch(names(idx),"limits_"))
        {
          if(skip) continue;
          if(lmt) limits,get_member(fstrm,names(idx));
          continue;
        }

      if(strmatch(names(idx),"prop1_"))
        {
          if(skip) {
            idx += 4;
            continue;
          }
          p1  =get_member(fstrm,names(idx));
          p2  =get_member(fstrm,names(++idx));
          p3  =get_member(fstrm,names(++idx));
          p4  =get_member(fstrm,names(++idx));
          rslt=get_member(fstrm,names(++idx));
          
          replot,p1,p2,p3,p4,rslt;
          continue;
        }
      write,format="[WARNING] Unknown variable flag %s !!\n",names(idx);
    }
  if(autoclose) close,fstrm;
  redraw;
  if(old_win>=0)
    {
      window,old_win;
      plsys,old_sys;
    }
}
