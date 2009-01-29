/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "eaarl.i";
write, "$Id$";

struct IMG_WORLD_FILE {
	double xscale; // x-scale 
	double xrotn; // rotation in x direction
	double yrotn; // rotation in y direction
	double yscale; // negative of y-scale
	double xcoord; // X coordinate of the center of the upper left pixel of image
	double ycoord; // Y coordinate of the center of the upper left pixel of image
}

func read_image(filename) {
/* DOCUMENT read_image(filename)
	This function reads a jpeg file 
	This function requires the yorick-z plugin to be installed.  The yorick-z plugin is available for download at http://www.maumae.net/yorick/doc/plugins.php

	If image is not a jpeg, it will convert to jpeg using ImageMagick's convert command.

	Input:
		filename = name of file to read
		If no filename is given, a dialog box will appear to load file.


	Output:
		3-D image array.


	See also: jpeg_read, jpeg_write

	Orig: Amar Nayegandhi 12/08/2005.
*/
   extern imgdir;
   if (is_void(filename)) {
      filename  = get_openfn( initialdir=imgdir, filetype="*.png *.jpg *.jpeg *.tif *.tiff *.gif", title="Open Image File to read" );
   }

   if (filename=="") {
      write, "No image file name found";
      return;
   }

   file1 = split_path(filename, 0);
   filepath = file1(1);
   fname = file1(2);

   fname_noext = split_path(fname, 0, ext=1);
   fname_jpg = fname_noext(1)+".jpg";

   if (strglob("*.jpg", filename) == 0) {
      // convert to jpg
      system, "convert "+filename+" /tmp/"+fname_jpg;
      write, "File converted to jpg format";
      filename = "/tmp/"+fname_jpg;
      img = jpeg_read(filename);
      // delete tmp file
      remove, "/tmp/"+fname_jpg;
   } else {
      img = jpeg_read(filename);
   }

   return img;
}

func read_lidar_image_location(filename) {
/* DOCUMENT read_lidar_image_location(filename)
	This function reads the lidar image location from the lidar filename which uses the standard naming convention.
	The standard naming convention for EAARL lidar files is:
		t_e310000_n2726000_17_*.jpg
		where 310000 is the UTM Easting, 2726000 is the UTM Northing, and 17 is the UTM zone number.

	INPUT:
		filename:	Input image file name 
	OUTPUT:
		3 element array containing the UTM Easting, UTM Northing, and UTM Zone of the upper left (Northwest) location of the image as defined in the filename.
	Orig: Amar Nayegandhi 12/08/2005.
*/

   file1 = split_path(filename, 0);
   filepath = file1(1);
   fname = file1(2);

   // find the easting, northing, and zone information from the filename
   // check if filename is in the correct naming convention
   if (!strglob("t_e*_n*_*.*", fname)) {
      write, "File name not in standard format.";
      return;
   }
   t = *pointer(fname);
   utmeasting_str = string(&t(4:9));
   utmnorthing_str = string(&t(12:18));
   utmzone_str = string(&t(20:21));

   utmeasting = utmnorthing = utmzone = 0;
   sread, utmeasting_str, utmeasting;
   sread, utmnorthing_str, utmnorthing;
   sread, utmzone_str, utmzone;

   return [utmeasting, utmnorthing, utmzone];
}

func plot_lidar_image(img, location, win=, winsize=, dofma=) {
/* DOCUMENT plot_lidar_image(img, location, win=, winsize=, dofma=)
	This function plots the 2k by 2k lidar image in window, win.

	INPUT:
		img: image array to be plotted (usually (3,x,y))
		location: NW location coordinates of the 2k by 2k image (usually determined from the filename)
		win= window number to plot data. Default win=6;
		winsize = size of window.  If window size has changed, then dofma must be set to 1. Default winsize=1 (small).
		dofma= set to 1 to clear plot (frame advance). 

	OUTPUT:

	Orig: Amar Nayegandhi 12/08/2005.
	Modified: Amar 12/13/2005.
*/

   extern _ytk_window_exists, _ytk_window_size;
   if (is_void(win)) win=6; // default to window, 6.
   if (is_void(_ytk_window_size)) {
      _ytk_window_size = array(int, 64);
   }
   if (is_void(winsize)) winsize = 1; // defaults to smallest window
   w = current_window();

   x0 = location(1);
   y0 = location(2);
   x1 = location(1)+2000;
   y1 = location(2)-2000;

   wset = change_window_size(win, winsize, dofma);

   if (wset) {
      pli, img, x0,y0,x1,y1;
      window, win, width=0, height=0;
      _ytk_window_exists=1;
      window_select, w;
   }

   return;
}

func plot_image(img, location, win=, dofma=, winsize=, nocws=) {
/* DOCUMENT plot_image(img, location, win=, dofma=, winsize=, nocws=)
	This function plots an image in window, win.

	INPUT:
		img: image array to be plotted (usually (3,x,y))
		location: location coordinates of the image in the format (x0,y0,x1,y1)
		win= window number to plot data. Default win=6;
		winsize = size of window.  If window size has changed, then dofma must be set to 1. Default winsize=1 (small).
		dofma= set to 1 to clear plot (frame advance). 
      nocws= set to 1 to disable calling change_window_size. also ignores win, winsize, dofma.

	OUTPUT:

	Orig: Amar Nayegandhi 12/08/2005.
	Modified: Amar 12/13/2005.
*/

   extern _ytk_window_exists, _ytk_window_size;
   if (is_void(win)) win=6; // default to window, 6.
   if (is_void(_ytk_window_size)) {
      _ytk_window_size = array(int, 64);
   }
   if (is_void(winsize)) winsize = 1; // defaults to smallest window
   if (is_void(nocws)) nocws = 0;
   w = current_window();

   if ((dimsof(location))(1) == 1) {
      x0 = location(1);
      y0 = location(2);
      x1 = location(3);
      y1 = location(4);
   } else {
      x0=y0=x1=y1=[];
   }

   if (nocws) {
      pli, img, x0,y0,x1,y1;
      _ytk_window_exists=1;
   } else {
      wset = change_window_size(win, winsize, dofma);

      if (wset) {
         if (is_array(x0)) {
            pli, img, x0,y0,x1,y1;
         } else {
            plf, img, location(2,,), location(1,,); 
         }
         window, win, width=0, height=0;
         _ytk_window_exists=1;
         window_select, w;
      }

   }
   return;
}

func load_and_plot_image(filename, img_world_filename=, img=, location=, win=, winsize=, dofma=) {
/* DOCUMENT load_and_plot_image(filename, img=, location=, win=, dofma=, winsize=)
	This function loads and plots an image in window, win.

	INPUT:
		filename: name of file to load including path.
		img_world_filename: name of file containing the world coordinates (jgw, tfw, etc.)
		img= image array to be plotted (usually (3,x,y))
		location= location coordinates of the image in the format (x0,y0,x1,y1)
		win= window number to plot data. Default win=6;
		winsize = size of window.  If window size has changed, then dofma must be set to 1. Default winsize=1 (small).
		dofma= set to 1 to clear plot (frame advance). 

	OUTPUT:

	Orig: Amar Nayegandhi 12/08/2005.
*/

   extern _ytk_window_exists, _ytk_window_size;
   if (is_void(img)) {
      img = read_image(filename);
   }

   if (!is_void(img_world_filename)) {
      location = read_img_world_file(img_world_filename, img=img);
   }

   if (is_void(location)) {
      loc = read_lidar_image_location(filename);
      if (is_array(loc)) 
         plot_lidar_image, img, loc, win=win, winsize=winsize, dofma=dofma;
   } else {
      plot_image, img, location, win=win, winsize=winsize, dofma=dofma;
   }

   return;
}

func read_img_world_file(filename, img=, xsize=, ysize=, scale=) {
/* DOCUMENT read_img_world_file(filename, img=, xsize=, ysize=, scale=)
	This function reads the image world file name (jgw, tfw) and returns the boundary locations for the image.

	INPUT:
		filename: the image world file (jgw, tfw, etc.)
		img= the image array
		xsize = number of pixels in the image along x-direction
		ysize = number of pixels in the image along y-direction
      scale = scale down by factor (e.g. if scale=10, the image will be 1/10th of its size in each direction, i.e. 1/100th of its original size).
		
		Either img or [xsize,ysize] are needed (not both).
	
	OUTPUT:
		Array containing the [x0,x1,y0,y1] coordinates

	Orig: Amar Nayegandhi 12/22/2005.
*/
   extern gw;

   default, scale, 1;
   f = open(filename, "r");
   if (catch(0x02)) {
      print, "No file found";
      return;
   }

   if (is_array(img)) {
      xsize = numberof(img(1,,1));
      ysize = numberof(img(1,1,));
   }

   if (is_void(xsize) || is_void(ysize)) {
      write, "Image size not available.  Cannot compute boundaries.";
      return;
   }

   gw = IMG_WORLD_FILE();

   val = double();

   // now read the contents of the world file to the struct gw.
   read, f, val;
   gw.xscale = val;
   read, f, val;
   gw.xrotn = val;
   read, f, val;
   gw.yrotn = val;
   read, f, val;
   gw.yscale = val;
   read, f, val;
   gw.xcoord = val;
   read, f, val;
   gw.ycoord = val;

   x0 = gw.xcoord;
   y1 = gw.ycoord;

   if (gw.xrotn == 0) {
      x1 = gw.xscale*xsize + gw.yrotn*ysize + gw.xcoord;
      y0 = gw.xrotn*xsize + gw.yscale*ysize + gw.ycoord;

      return [x0,y1,x1,y0];
   } else {
      // the image is rotated; calculate the rotation for each pixel
      sc_x = int(ceil(xsize*1.0/scale));
      sc_y = int(ceil(ysize*1.0/scale));
      xy_loc = array(double, 2, sc_x,sc_y);
      for (i=1;i<=sc_x;i++) {
         for (j=1;j<=sc_y;j++) {
            xy_loc(1,i,j) = gw.xscale*i*scale + gw.yrotn*j*scale + gw.xcoord;
            xy_loc(2,i,j) = gw.xrotn*i*scale + gw.yscale*scale*j + gw.ycoord;
         }
      }
      return xy_loc;
   }
}
