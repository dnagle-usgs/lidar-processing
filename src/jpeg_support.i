// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func read_image(filename) {
/* DOCUMENT img = read_image(filename)

   Reads the image file specified. The returned img will be an array which is
   3-by-width-by-height for RGB images or width-by-height for grayscale images.
   Rows are ordered from top to bottom; columns from left to right.

   This function requires the yorick-z plugin to be installed. The yorick-z
   plugin is available for download at
      http://www.maumae.net/yorick/doc/plugins.php

   If the image is not a jpeg (detected by the .jpg extension), it will be
   temporarily converted to JPEG using ImageMagick's convert command. If you
   will be reloading an image many times, it will be much more efficient to
   externally convert your image to jpeg format first.

	See also: jpeg_read jpeg_write
*/
// Orig: Amar Nayegandhi 12/08/2005.
   extern imgdir;
   if(is_void(filename))
      error, "No image file provided.";

   if(anyof(strlower(file_extension(filename)) == [".jpg",".jpeg"])) {
      img = jpeg_read(filename);
   } else {
      tempdir = mktempdir("read_image");
      tempfn = file_join(tempdir, "temp.jpg");
      system, swrite(format="convert '%s' '%s'", filename, tempfn);
      img = jpeg_read(tempfn);
      remove, tempfn;
      rmdir, tempdir;
   }

   return img;
}

func read_georef_image(filename, &img, &location, worldfile=) {
/* DOCUMENT
   Reads the image file specified. Its data will be stored to img and its
   location information will be stored to location. The location will be in a
   format suitable for plot_image; see plot_image for details.
*/
   img = read_image(filename);
   location = [];

   // Automatically locate worldfile, if possible
   if(is_void(worldfile)) {
      ext = strchar(file_extension(filename));
      if(numberof(ext) == 5) {
         // changes .abc -> .acw (png/pgw, tif/tfw, jpg/jgw)
         worldfile = file_rootname(filename)+strchar(ext([1,2,4]))+"w";
         if(!file_exists(worldfile))
            worldfile = [];
      }
   }

   if(!is_void(worldfile)) {
      location = read_img_worldfile(worldfile, dimsof(img)(-1), dimsof(img)(0));
   } else {
      // Try to parse filename using our tiling scheme
      tile = extract_tile(file_tail(filename));
      if(tile) {
         bbox = tile2bbox(tile);
         location = bbox([4,1,2,3]);
      }
   }
}

func read_img_worldfile(filename, xsize, ysize) {
/* DOCUMENT read_img_worldfile(filename, xsize, ysize)
   This function reads an image's worldfile (jgw, tfw) and returns the boundary
   coordinates for the image.

   Parameters:
      filename: The path to the world file.
      xsize: Size of image, number of pixels in x-direction.
      ysize: Size of image, number of pixels in y-direction.

   The return result will be an array of coordinates suitable for passing to
   plot_image; see plot_image for information on the formats.

   This is primarily intended for use by read_georef_image.
*/
   if(!file_exists(filename))
      error, "File not found.";

   jgw = read_ascii(filename)(*);

   xbox = [0,0,xsize,xsize];
   ybox = [0,ysize,ysize,0];
   affine_transform, xbox, ybox, jgw;

   // Checks to see if the image is non-rotated; if it's not, we can return
   // bounding coordinates.
   if(allof([xbox([1,3]),ybox([1,3])] == [xbox([2,4]),ybox([4,3])])) {
      return [xbox(1), ybox(1), xbox(3), ybox(3)];
   } else {
      return [xbox,ybox];
   }
}

func plot_image(img, location, win=, dofma=, winsize=, nocws=, skip=) {
/* DOCUMENT plot_image(img, location, win=, dofma=, winsize=, nocws=)

   This function plots a located image. The img argument should be an image
   array, typically 3-by-x-by-y. The location argument can be in one of four
   formats:

      If location is omitted or specified as [], then the image will be plotted
      with its lower-left corner at (0,0) and each cell with be a 1x1 unit
      square.

      If location is a two-element array [x1,y1], then the image will be
      plotted with its lower left corner at (0,0) and its upper right corner at
      (x1,y1).

      If location is a four-element array [x0,y0,x1,y1], then the image will be
      plotted with its lower left corner at (x0,y0) and its upper right corner
      at (x1,y1).

      if location is an 8-element, 2-dimensional array
      [[x0,x1,x2,x3],[y0,y1,y2,y3]], it is interpreted as being coordinate
      pairs for the lower left, upper left, upper right, and lower right
      corners (in that order). This enables the plotting of rotated and skewed
      images.

   If the location argument does not fit any of those four formats, an error
   will occur.

   Options:
      win= The window to plot in. By default, it uses the current window.
      dofma= If set to 1, an fma will be issued prior to plotting. By default,
         it is not.
      skip= A skipping factor to use to downsample the image when plotting.
            skip=1   Use all rows/columns (default)
            skip=10  Use every 10th row and every 10th column

   Legacy options:
   These options are deprecated and should not be used in new code.
      winsize= Size of the window, passed to change_window_size.
      nocws= Forces the function to ignore any values provided for win=,
         dofma=, and winsize=.
*/
   local x, y, x0, y0, x1, y1;
   wbkp = current_window();

   // Legacy support...
   if(!nocws) {
      if(!is_void(winsize)) {
         wset = change_window_size(win, winsize, dofma);
         if(!wset)
            error, "Unknown error.";
      } else {
         if(!is_void(win))
            window, win;
         if(!is_void(dofma))
            fma;
      }
   }

   // Allows for faster plotting of really big images
   default, skip, 1;
   if(skip > 1) {
      skip = long(skip);
      img = img(..,::skip,::skip);
   }

   x = y = x0 = y0 = x1 = y1 = [];
   // No location - use behavior of pli, z
   if(is_void(location)) {
      x0 = 0;
      y0 = 0;
      x1 = dimsof(img)(-1);
      y1 = dimsof(img)(0);
   // Two coordinates - use behavior of pli, x0, y0, x1, y1
   } else if(numberof(location) == 4) {
      x0 = location(1);
      y0 = location(2);
      x1 = location(3);
      y1 = location(4);
   // One coordinate - use behavior of pli, x1, y1
   } else if(numberof(location) == 2) {
      x0 = 0;
      y0 = 0;
      x1 = location(1);
      y1 = location(2);
   // 8 coordinates - use plf
   } else if(dimsof(location)(1) == 2 && numberof(location) == 8) {
      xsize = dimsof(img)(-1);
      ysize = dimsof(img)(0);
      xbox = location(..,1);
      ybox = location(..,2);

      // x values across the bottom
      xb = span(xbox(1), xbox(4), xsize);
      // x values across the top
      xt = span(xbox(2), xbox(3), xsize);
      // x values for each row
      x = transpose(span(xb, xt, ysize));
      xb = xt = [];

      // y values up the left
      yl = span(ybox(1), ybox(2), ysize);
      // y values up the right
      yr = span(ybox(4), ybox(3), ysize);
      // y values for each column
      y = span(yl, yr, xsize);
      yl = yr = [];
   } else {
      error, "Invalid location provided.";
   }

   if(is_array(x0))
      pli, img, x0, y0, x1, y1;
   else
      plf, img, y, x;

   window_select, wbkp;
}

func load_and_plot_image(filename, worldfile=, location=, win=, winsize=,
dofma=, skip=) {
/* DOCUMENT load_and_plot_image, filename, worldfile=, location=, win=,
   winsize=, dofma=, skip=

   Wrapper around read_georef_image and plot_image to do both in one shot. Does
   not return anything. See read_georef_image and plot_image for details.
*/
   local img;
   if(is_void(location))
      read_georef_image, filename, img, location, worldfile=worldfile;
   else
      img = read_image(filename);

   plot_image, img, location, win=win, winsize=winsize, dofma=dofma, skip=skip;
}

func jpg_shrink(src, dst, amt, type=, quality=, fast=) {
/* DOCUMENT jpg_shrink, src, dst, amt, type=, quality=, fast=
   Shrinks a JPG image using NetPBM utilities.

   If you want to shrink a single image to several downscaled sizes, you can
   wrap it all in a single call by using dst and amt as arrays. This is more
   efficient than calling this function repeatedly.

   Parameters:
      src: The path and filename for the source image.
      dst: The path and filename where the resized image(s) should go. This can
         be scalar or array.
      amt: The amount to shrink by. The meaning of this varies based on the
         type= argument. This can be scalar or array and must have the same
         numberof() as dst.
   Options:
      type= Controls how amt is interpreted.
            type="reduce" (default)
               The amt parameter is interpreted as a factor to reduce by. Each
               dimension will be divided by this factor. Only integer values
               are valid.
            type="pixels"
               The amt parameter constrains the area of the shrunk image. The
               image will be reduced so that it has no more than this many
               pixels area. Only integer values are valid.
            type="scale"
               The amt parameter is the ratio by which to scale the image. Each
               dimension will be multiplied by this factor. Floating point
               values are permitted. (This is effectively the reciprocal of
               "reduce".)
      fast= Specifies which is more important, image quality or fast
         generation/small size.
            fast=1   Emphasizes faster generation and smaller file size (default)
            fast=0   Emphasizes better image quality
      quality= The JPG quality setting. Should be an integer between 1 and 100.
            quality=70     Default if fast==1
            quality=80     Default if fast==0
*/
   default, type, "reduce";
   default, fast, 1;
   default, quality, (fast ? 70 : 80);
   tempdir = mktempdir("jpg_shrink");
   tempfile = file_join(tempdir, "original.pnm");

   cmd = swrite(format="jpegtopnm -dct %s %s '%s' > '%s' 2> /dev/null;",
      (fast ? "fast" : "int"), (fast ? "-nosmooth" : ""),
      src, tempfile);

   rcmd = "";
   if(type == "reduce") {
      rcmd = swrite(format="-reduce %d", long(amt));
   } else if(type == "pixels") {
      rcmd = swrite(format="-pixels %d", long(amt));
   } else if(type == "scale") {
      rcmd = swrite(format="-xscale %f -yscale %f", double(amt), double(amt));
   } else {
      error, "Unknown type= specified";
   }

   cmd += swrite(format="%s %s '%s' 2> /dev/null | pnmtojpeg -optimize -quality %d -dct %s > '%s';",
      (fast ? "pnmscalefixed" : "pamscale"), rcmd, tempfile,
      long(quality), (fast ? "fast" : "int"), dst)(sum);

   system, cmd;

   remove, tempfile;
   rmdir, tempdir;
}

func image_size(fn) {
/* DOCUMENT image_size(fn)
   Returns an array [width, height] indicating the image's size in pixels.
   Requires ImageMagick.
*/
   local w, h;
   cmd = swrite(format="identify -format '%%w %%h' \"%s\"", fn);
   f = popen(cmd, 0);
   w = h = long(0);
   read, f, format="%d %d", w, h;
   return [w,h];
}

// rgb2hsl and hsl2rgb math from:
// http://www.easyrgb.com/index.php?X=MATH

func rgb2hsl(R, G, B, &H, &S, &L) {
/* DOCUMENT hsl = rgb2hsl(r, g, b);
   rgb2hsl, r, g, b, h, s, l;

   Converts a color in RGB notation to HSL. Works for scalars and arrays.
*/
   if(numberof(R) > 1) {
      H = array(double, dimsof(R));
      S = array(double, dimsof(R));
      L = array(double, dimsof(R));
      for(i = 1; i <= numberof(R); i++) {
         temp = rgb2hsl(R(i), G(i), B(i));
         H(i) = temp(1);
         S(i) = temp(2);
         L(i) = temp(3);
      }
      return [H,S,L];
   }

   R /= 255.;
   G /= 255.;
   B /= 255.;

   mn = min(R,G,B);
   mx = max(R,G,B);
   delta = mx - mn;

   L = (mx + mn) / 2.;

   H = S = 0;

   if(mx != 0 && mx != mn) {
      if(L < 0.5)
         S = delta / (mx + mn);
      else
         S = delta / (2 - mx - mn);

      dR = (((mx - R)/6.) + (delta/2.)) / delta;
      dG = (((mx - G)/6.) + (delta/2.)) / delta;
      dB = (((mx - B)/6.) + (delta/2.)) / delta;

      if(R == mx)
         H = dB - dG;
      else if(G == mx)
         H = 1/3. + dR - dB;
      else if(B == mx)
         H = 2/3. + dG - dR;

      if(H < 0)
         H++;
      if(H > 1)
         H--;
   }

   return [H, S, L];
}

func hsl2rgb(H, S, L, &R, &G, &B) {
/* DOCUMENT rgb = hsl2rgb(h, s, l);
   hsl2rgb, h, s, l, r, g, b;

   Converts a color in HSL notation to RGB. Works for scalars and arrays.
*/
   if(numberof(H) > 1) {
      R = array(short, dimsof(H));
      G = array(short, dimsof(H));
      B = array(short, dimsof(H));
      for(i = 1; i <= numberof(H); i++) {
         temp = hsl2rgb(H(i), S(i), L(i));
         R(i) = temp(1);
         G(i) = temp(2);
         B(i) = temp(3);
      }
      return [R,G,B];
   }

   R = G = B = 0;

   if(S == 0) {
      R = G = B = L * 255;
   } else {
      if(L < 0.5)
         v2 = L * (1 + S);
      else
         v2 = (L + S) - (S * L);

      v1 = 2 * L - v2;

      R = 255 * __hue2rgb(v1, v2, H + 1/3.);
      G = 255 * __hue2rgb(v1, v2, H);
      B = 255 * __hue2rgb(v1, v2, H - 1/3.);
   }

   return short([R,G,B]);
}

func __hue2rgb(v1, v2, H) {
/* DOCUMENT c = __hue2rgb(v1, v2, H)
   Helper function for hsl2rgb.
*/
   if(H < 0)
      H++;
   if(H > 1)
      H--;
   if(6 * H < 1)
      return v1 + (v2 - v1) * 6 * H;
   if(2 * H < 1)
      return v2;
   if(3 * H < 2)
      return v1 + (v2 - v1) * (2/3. - H) * 6;
   else
      return v1;
}
