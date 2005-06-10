	require, "dir.i"
	require, "bathy_filter.i"

func webview(data_dir, webdir, mode, rcfmode=, min_elv=, max_elv=, getcolor=, datum=, update=, fltdir=, indir=, nohtml=, title=, alwaysdrawmap=) {
/* DOCUMENT webview(data_dir, webdir, mode, num_reef, reeffile, onlymerged=, min_elv, max_elv, pres, getcolor, update)
This program searches through data_dir for all i_e######_n####### folders runs through various plotting options for each one.
The user may save the plain image with a title, an image w/ a grid of named datatiles, and choose several individual data
tiles to display in full resolution. The user may also choose to run the qaqc flightline analysis on the data tile level and 
display coral reef boxes if they have been defined. It stores images in webdir in a format which is then used by a perl script to generate a webpage.

Options: data_dir = string for directory containing index tile directories created using batch_process
webdir=where images and associated directory structure is placed.
mode = Display mode, 1 = first surface (from veg), 2 = bathymertry 3 = veg (bare earth)
rcfmode= Set to 1 for RCF or 2 for IRCF or 3 for ircf_mf (manually filtered)
min_elv/max_elv = the min and max elevations to be displayed. The default is -40 to -28 for bathy or -30 to 0 for veg (wgs84). 
getcolor = if one,automatically selects a color bar that covers a certain number of standard deviations of the data
datum= Set to "NAVD88" or "WGS84"
update= If 1, only creates pics for index tiles that do not already exist in webdir. This is on by default.
fltdir= To plot flightlines on the bigmap, set to the directory containing EAARL mission days (i.e. /data/0/Tampa_Bay_04)
indir= If all GGA files are located in a single directory, use fltdir=<gga directory> and indir = 1
nohtml = Only create images, do not generate the webpage
title = The title of the web page. e.g. title="Tampa Bay 2004"
alwaysdrawmap = If 1, will draw the coastline map on every image

To make updates simply place the new data in a folder broken down into the normal indextile/datatile/data file sturcture and run the command

Original: Lance Mosher
*/


	if(!(is_array(update))){update=1;}   
	if ((!is_array(getcolor)) && ((!min_elv) && (!max_elv))) getcolor=1;
	if (!is_array(datum)) datum = "WGS84";
	if(!onlymerged) onlymerged=0;
   
	if (mode == 2) {
		ss = "b";
		if (!min_elv) min_elv = -28.0;
		if (!max_elv) max_elv = -40.0;
   	}
	if ((mode == 1) || (mode == 3)) {
		ss = "v";
		if (!min_elv) min_elv = 0.0;
		if (!max_elv) max_elv = -30.0;
   	}
   
  	if (!ss) {
		write, "Mode must be 1, 2 or 3 for first surface (from veg), bathy, or veg"; 
		return;
   	}

	min_elv = float(min_elv);
	max_elv = float(max_elv);
	elvs = [min_elv, max_elv]; 

//-----Search for files to put in webpage
   
	s=array(string, 10000);
	if (!onlymerged) scmd = swrite(format = "find %s -name '*_%s.pbd'", data_dir, ss);    //finds no merged
	if (onlymerged)  scmd = swrite(format = "find %s -name '*_%s*merged*.pbd'", data_dir, ss);
	fp = 1; lp = 0;
	for (i=1; i<=numberof(scmd); i++) {   //makes array "s" containing names of data all.pbd files of correct type
		f=popen(scmd(i), 0);
		n = read(f,format="%s",s);
		close, f;
		lp = lp + n;
		if (n) fil_list = s(fp:lp);
		fp = fp + n;
	}

//-----Extract list of unique directories containing data
	
	dir_list = array(string, numberof(fil_list));
	for (j=1;j<=numberof(fil_list);j++) dir_list(j) = (split_path(fil_list(j),-1))(1);
	dir_list = dir_list(unique(dir_list));
	write, format="%d areas found...\n", numberof(dir_list); 
	norings= array(long, numberof(dir_list));
	easings= array(long, numberof(dir_list));
   
//-----Read strings from file name into numbers
	for (i=0;i<numberof(dir_list);i++) {
		t = *pointer(dir_list(i));
		nn = where(t == 'i')
		nn = nn(0);			//nn is the first location where 'i' is located in the file, which is used to find the easting and northing
		e = sread(strpart(dir_list(i), (nn+3):(nn+8)), format="%d", easings(i));
		e = sread(strpart(dir_list(i), (nn+11):(nn+17)), format="%d", norings(i));
	}

	maxeasings = easings+10000;
	minnorings = norings-10000;
	border = [min(easings), max(maxeasings), min(minnorings), max(norings)];

//-----Check if bigmap exists
   	bigpicname = webdir+"bigpic.ps"
	if (update) {
		bpexist = [];
		scmd = swrite(format="ls %s", bigpicname);
		n = read(popen(scmd,0), format="%s", s);
		n = where(s);
		if (is_array(n)) bpexist = 1;
	}
		
		
//-----Plot bigmap window of index tiles
		winkill,0;window,0,legends=0,dpi=100,style="landscape11x85.gs";	
		pldj, easings, minnorings, easings, norings, color="green",width =6.0;
		pldj, easings, minnorings, maxeasings, minnorings, color="green", width = 6.0;
	        pldj, maxeasings, minnorings, maxeasings, norings, color="green", width =6.0;
		pldj, maxeasings, norings, easings, norings, color="green", width=6.0;
		limits, square=1;
		limits;
		save_lmt = limits();
		save_lmt(5) = 0;
		load_map(utm=1);
		picmaker(rgn = border, index=1);

//-----Draw flightlines if fltdir is specified
	if (fltdir) {
   		s=array(string, 10000);
  		scmd = swrite(format = "ls %s*/gps-*/*gga.ybin", fltdir);
   		if (indir) scmd = swrite(format = "ls %s*.ybin", fltdir);
   		fp = 1; lp = 0;
   		for (i=1; i<=numberof(scmd); i++) {
			f=popen(scmd(i), 0);
      			n = read(f,format="%s",s);
			close, f;
      			lp = lp + n;
      			if (n) gga_list = s(fp:lp);
      			fp = fp + n;
   		}
		if (numberof(gga_list) == 0) lance();
		for (i=1; i<=numberof(gga_list); i++){
			gga = rbgga(ifn=gga_list(i), utm=utm);
			splits = ceil(numberof(gga_list)/6.0);
			delta = ceil(155.0/splits);
			n = i/6;
			c = i%6;
			if (scalecolor) {
				c = scalecolor;
				n = i;
				delta = ceil(155.0/numberof(gga_list));
				if (scalecolor == 6) c = 0;
			}
			if (c == 1) col = [255-delta*n, 0, 0]
			if (c == 2) col = [0, 255-delta*n, 0]
			if (c == 3) col = [0, 0, 255-delta*n]
			if (c == 4) col = [255-delta*n, 255-delta*n, 0]
			if (c == 5) col = [255-delta*n, 0, 255-delta*n]
			if (c == 0) {n=n-1; col = [0, 255-delta*n, 255-delta*n];}
			fil_list(i) = gga_list(i);
			if (color) col = color;
			show_gga_track, color=col, skip=0,marker=0,msize=.1, width=1, utm=1, win=0;
		}
	}
	window, 0;
	show_map, dllmap, utm=1, width=4;
	limits, save_lmt;
	if (is_void(bpexist)) {
		hcp_file, bigpicname;
		hcp;
		write, "*****Converting bigmap postscript to png..\n"
		system, "convert -quality 9 -rotate 90 "+webdir+"bigpic.ps "+webdir+"bigpic.png";
	}
	
//-----Find the pixel dimensions of the bigpic for the web page
	if (!nohtml) {
		ppm = 504/(save_lmt(4)-save_lmt(3));			//Pixels per meter. 504 is # of pixels in map area in the .png file
		slen = int(10000*ppm);					//Length of index tile * ppm = pixels per index side
		spixe = int((border(1)-save_lmt(1))*ppm+54);	//Number of horizontal pixels fromt left to first tile. 54 is pixels to the left of map area
		spixn = 8;						//Number of vertical pixels fromt top to first tile = 8
		sutme = border(1); 
		sutmn = border(4);
	}
	winkill, 0;

//-----Find the index tile for each file in fil_list
	indxname = array(string, numberof(fil_list)); 
	for(j=1; j<=numberof(fil_list);j++){
		la = split_path(fil_list(j), -1);
		indxname(j) = split_path(la(1), -1)(2);
        }

//-----Go through each index tile to create images
	ni = numberof(dir_list);	
	for (i=1;i<=ni;i++) {
		ename = easings(i)/1000;			//Shorted eastings/northings to 3/4 digits
		nname = norings(i)/1000;
		newdiris = swrite(format="%d%d", ename, nname); //Shortened web directory
		newdiri = webdir+newdiris+"/";			//Shortened full path

		e = mkdir(newdiri);				//Make new directory

//-----Select the region and extract the index easting and northing
		write, format="Opening region %d of %d...\n", i, numberof(dir_list);
		t = *pointer(dir_list(i));
		nn = where(t == 'i');
		nn = nn(0);
		tle = strpart(dir_list(i), nn:nn)+"!"+strpart(dir_list(i), (nn+1):(nn+8))+"!"+strpart(dir_list(i), (nn+9):(nn+17))+"!"+strpart(dir_list(i), (nn+18):(nn+21));
		idx_emin = 0;
	        idx_nmax = 0;
        	sread(strpart(dir_list(i), (nn+3):(nn+8)), format="%d", idx_emin);
	        sread(strpart(dir_list(i), (nn+11):(nn+17)), format="%d", idx_nmax);
		searchstr = "*_"+ss+".pbd"; 	//Excludes filtered
		if (rcfmode == 1)  searchstr = "*_"+ss+"*_rcf.pbd";
		if (rcfmode == 2)  searchstr = "*_"+ss+"*_ircf.pbd";
		if (rcfmode == 3)  searchstr = "*_"+ss+"*_ircf_mf.pbd";


//-----If file already exists continue loop
		idxtilename = swrite(format="%s%di%d.ps", newdiri, idx_emin/1000, idx_nmax/1000)
		iexist=0;
		if (update) {
			scmd = swrite(format="ls %s",idxtilename);
			n = read(popen(scmd,0), format="%s", s);
			n = where(s);
			if (is_array(n)) iexist = 1;
		}

//-----Load, plot and save data in each index tile
		if (iexist != 1) {
			depth_all = merge_data_pbds(dir_list(i), skip = 10, searchstring=searchstr);
			if (is_void(depth_all)) continue;
			depth_all = depth_all(data_box(depth_all.east/100., depth_all.north/100., idx_emin, idx_emin + 10000, idx_nmax-10000, idx_nmax)); //Crop data to exact size of index tile
			if (!is_array(depth_all)) {
				write, "No good data in selected region..."; 
				skipthis = 1;
			}
		
			winkill,5;window,5,dpi=100,style="landscape11x85.gs",width=1100,height=850;		//Prepare window
			if ((mode == 1) && (!skipthis)) {
				elv = depth_all.elevation(where((depth_all.elevation >= -50000) & (depth_all.elevation <=50000)));
				if (getcolor) elvs = stdev_min_max(elv/100., N_factor=1.5);
				display_veg, depth_all, win=5, cmin=elvs(1), cmax = elvs(2), size = 1.0, edt=1, felv = 1, lelv=0, fint=0, lint=0, cht = 0, marker=1, skip=1;
		                pltitle, tle + " first surface";
       				xytitles, "UTM easting (M)", "UTM northing (M)";
			 }
       			 if (mode == 2) {
				elv = depth_all(where((depth_all.elevation >= -50000) & (depth_all.elevation <=50000)));
				if (getcolor) elvs = stdev_min_max((elv.elevation + elv.depth)/100., N_factor=1.5);
				plot_bathy, depth_all, win=5, ba=1, fs = 0, de = 0 , fint = 0, lint = 0, cmin=elvs(1), cmax=elvs(2), msize = 1.0, marker=1, skip=1;
				pltitle, tle + " bathy";
				xytitles, "UTM easting (M)", "UTM northing (M)";
			}
			if (mode == 3) {
				lelv = depth_all.lelv(where((depth_all.elevation >= -50000) & (depth_all.elevation <=50000)));
				if (getcolor) elvs = stdev_min_max(lelv/100., N_factor=1.5);
				display_veg, depth_all, win=5, cmin=elvs(1), cmax=elvs(2), size = 1.0, edt=1, felv = 0, lelv=1, fint=0, lint=0, cht = 0, marker=1, skip=1;
				pltitle, tle + " bare earth";
				xytitles, "UTM easting (M)", "UTM northing (M)";
			}
			limits, idx_emin-2000, idx_emin+12000, idx_nmax - 10000, idx_nmax;
			colorbar, elvs(1), elvs(2), landscape=1, datum=dattag, units="M";
	
//-----	Plot gridlines over the data tiles
			write, "Now drawing gridlines over data...\n";
			idx_rgn = [idx_emin, idx_emin+10000, idx_nmax-10000, idx_nmax];
			picmaker, color="black", rgn=idx_rgn;
			limits, square=1;
			window, 5, legends=0;
			if (alwaysdrawmap) {
				idxlmt = limits();
				show_map, dllmap, utm=1, width=2;			//draw coastline map
				limits, idxlmt(1), idxlmt(2), idxlmt(3), idxlmt(4);
			}

//-----Save postscript of index tile
			idx_emin = idx_emin/1000;
			idx_nmax = idx_nmax/1000;
			hcp_file, idxtilename; 
			hcp;
			swrite, format="*****Converting index tile %i of %i to png...\n", i, ni;
			system, "convert -quality 9 -rotate 90 "+swrite(format="%s%di%d.ps", newdiri, idx_emin, idx_nmax)+" "+swrite(format="%s%di%d.png", newdiri, idx_emin, idx_nmax);
		}
		if(iexist == 1){
			swrite(format="Index tile %s exists... continuing", idxtilename);
		}

//-----Create array of data tiles in this index tile
		this_idx = split_path(dir_list(i), -1)(2);
	        dirindx = where(indxname == this_idx);					//Where indxname (index tiles of files in fil_list) are in this tile
        	fil_list2 = fil_list(dirindx);
		nj=numberof(fil_list2);
		storeemin = 0;
		storenmax = 0;		

//-----Go through each data tile
		for (j=1;j<=nj;j++) {
			window, 5;
			emin=1;
			nmax=1;
			fil = fil_list2(j);
			fil = split_path(fil,0);
			fil = fil(2);
			e=sread(strpart(fil, 4:9), format="%d", emin);
			e=sread(strpart(fil, 12:18), format="%d", nmax);
			if (storeemin==emin && storenmax == nmax){continue;} //Check to make sure this file is not the same as the previous
			storeemin = emin;
			storenmax = nmax;
			
//-----Set up bounding box and directory name for the data tile
			emax = emin+2000;
			nmin = nmax-2000;
			ename = emin/1000;
			nname = nmax/1000;
			newdird = swrite(format="%d%d", ename, nname);			
			newdird = newdiri+newdird+"/"
			mkdir, newdird;
			rgn = [emin, emax, nmin, nmax];
		
//-----If file already exists continue loop
			tilename = swrite(format="%s%dd%d.ps", newdird, emin/1000, nmax/1000);
			texist=0;
			if (update) {
				scmd = swrite(format="ls %s",tilename);
				n = read(popen(scmd,0), format="%s", s);
				n = where(s);
				if (is_array(n)) texist = 1;
			}
			if(texist==1){
				swrite(format="Data tile %s exists... continuing", tilename);
				continue;
			}

//-----Load data in the bounding box and save the plot
			winkill,4;window,4,dpi=100,style="landscape11x85.gs", width=1100, height=850;		//Set up the window
			if(mode==1){fixmode = 3;}else{fixmode=mode;}	

			if (rcfmode == 1) search_str = "*_rcf.pbd";
			if (rcfmode == 2) search_str = "*_ircf.pbd";
			if (rcfmode == 3) search_str = "*_ircf_mf.pbd";
			data_sel = sel_rgn_from_datatiles(rgn=rgn, data_dir=data_dir,mode=fixmode, win=5, search_str=search_str);
			if (!is_array(data_sel)) {write, "bad \n"; continue;}
			if ((mode == 1) && (!skipthis)) {
				elv = data_sel.elevation(where((data_sel.elevation >= -50000) & (data_sel.elevation <=50000)));
				if (getcolor) elvs=stdev_min_max(elv/100., N_factor=1.5);
       		 	        display_veg, data_sel, win=4, cmin=elvs(1), cmax=elvs(2), size=1.0, edt=1, felv=1, lelv=0, fint=0, lint=0, cht = 0, marker=1,skip=1;
				pltitle, swrite(format="t!_e%6.0f!_n%7.0f first surface", float(emin), float(nmax));
			        xytitles, "UTM easting (M)", "UTM northing (M)";
			}
			if (mode == 2) {
				elv = data_sel(where((data_sel.elevation >= -50000) & (data_sel.elevation <=50000)));
				if (getcolor) elvs=stdev_min_max((elv.elevation+elv.depth)/100., N_facotor=1.5);
				plot_bathy, data_sel, win=4, ba=1, fs = 0, de = 0 , fint = 0, lint = 0, cmin=elvs(1), cmax=elvs(2), msize = 1.0, marker=1, skip=1;
				pltitle, swrite(format="t!_e%6.0f!_n%7.0f bathy", float(emin), float(nmax));
				xytitles, "UTM easting (M)", "UTM northing (M)";
			}
       		 	if (mode == 3) {
				lelv = data_sel.lelv(where((data_sel.elevation >= -50000) & (data_sel.elevation <=50000)));
       	 			if (getcolor) elvs=stdev_min_max(lelv/100., N_factor=1.5);
				display_veg, data_sel, win=4, cmin=elvs(1), cmax=elvs(2), size = 1.0, edt=1, felv = 0, lelv=1, fint=0, lint=0, cht = 0,marker=1, skip=1;
				pltitle, swrite(format="t!_e%6.0f!_n%7.0f bare earth", float(emin), float(nmax));
				xytitles, "UTM easting (M)", "UTM northing (M)";
			}
			colorbar, elvs(1), elvs(2), landscape=1, datum = dattag, units="M";
			limits, square=1;
			window, 4, legends=0;
			if (alwaysdrawmap) {
				tillmt = limits();
				show_map, dllmap, utm=1, width=2;
				limits, tillmt(1), tillmt(2), tillmt(3), tillmt(4);
			}
			emint = emin/1000;
			nmaxt = nmax/1000;
			hcp_file, tilename; 
			hcp;
			write, format="*****Converting data tile %i of %i (index tile %i of %i) to png...\n", j, nj, i, ni;
			system, "convert -quality 9 -rotate 90 "+swrite(format="%s%dd%d.ps", newdird, emint, nmaxt)+" "+swrite(format="%s%dd%d.png", newdird, emint, nmaxt);
   		}
	}
	if (!nohtml) {
		write, "*****Generating web page\n";
		srcdir = "";
		n = read(popen("pwd", 0), srcdir);
		makeweb = srcdir+"/makeweb"
		scmd = swrite(format="%s --rootdir %s --eslen %i --nslen %i --spixe %i --spixn %i --sutme %i --sutmn %i --title \"%s\"", makeweb, webdir, slen, slen, spixe, spixn, sutme, sutmn, title);
		system, scmd;
		write, "Web page generated...\n";
		
	}
	write, "Webview complete!\n";
}

func plot_fltlines(fltdir, win=, color=, utm=, width=, scalecolor=, indir=) {
/* DOCUMENT plot_flightlines(fltdir, win=, color=, utm=, width=, scalecolor=, indir=)
This function plots flightline of all gga files from the fltdir.
Generall fltdir is the EAARL mission directory (e.g. /data/0/tampa_bay04/) such that gga
files are located in "/data/0/tampa_bay04/ * / gps-* / *-gga.ybin"

Alternatively, one may place all gga files directly in fltdir. In this case set indir=1

Options:
fltdir= The directory containing EAARL mission dates (indir=0) or gga files (indir=0)
win= The plot window
color= The color to plot each flightline
utm= Set to 1 if viewing UTM vs lat/lon
width= The width of the line
scalecolor= Scales the flightlines along a particular shade. 0=cyan, 1=red, 2=green, 3=blue, 4=yellow, 5=magenta
indir= Set to 1 if fltdir itself contains the gga files to plot.

Original: Lance Mosher
*/

//-----Find gga files
	if (!width) width = 1.0;
   	s=array(string, 10000);
   	scmd = swrite(format = "ls %s*/gps-*/*gga.ybin", fltdir);
   	if (indir) scmd = swrite(format = "ls %s*.ybin", fltdir);
   	fp = 1; lp = 0;
   	for (i=1; i<=numberof(scmd); i++) {
		f=popen(scmd(i), 0);
      		n = read(f,format="%s",s);
		close, f;
      		lp = lp + n;
      		if (n) gga_list = s(fp:lp);
      		fp = fp + n;
   	}
	if (numberof(gga_list) == 0) lance();

//-----Go through each gga file, choose a color and plot
	fil_list = array(string, numberof(gga_list));
	col_list = array(double, numberof(gga_list), 3);
	for (i=1; i<=numberof(gga_list); i++){
		gga = rbgga(ifn=gga_list(i), utm=utm);
		splits = ceil(numberof(gga_list)/6.0);		//Number of shades required to give unique color for each gga
		delta = ceil(155.0/splits);			//The intensity step such that the first shade is 255 and the last is 155
		n = i/6;					//Number of times i%6 has been zero (i.e. the step number)
		c = i%6;					//Cycle though each color 0 - 6
		if (scalecolor) {
			c = scalecolor;
			n = i;
			delta = ceil(155.0/numberof(gga_list));
			if (scalecolor == 6) c = 0;
		}
		if (c == 1) col = [255-delta*n, 0, 0]
		if (c == 2) col = [0, 255-delta*n, 0]
		if (c == 3) col = [0, 0, 255-delta*n]
		if (c == 4) col = [255-delta*n, 255-delta*n, 0]
		if (c == 5) col = [255-delta*n, 0, 255-delta*n]
		if (c == 0) {n=n-1; col = [0, 255-delta*n, 255-delta*n];}
		fil_list(i) = gga_list(i);
		if (!color) col_list(i,) = col;
		if (color) col = color;
		show_gga_track, color=col, skip=0,marker=0,msize=.1, width=width, utm=utm;
	}
	return;
}

 
func picmaker(junk, color=, rgn=, index=) {
/* DOCUMENT picmaker(junk, color=, rgn=, index=
This function plots boxes around data tiles or index tiles that enclose rgn.
The function will plot the text label of each data tile if index is not defined.
Options:
color= sets color of the boxes. e.g. "red" or [250,150,0]
rgn=The coordinates to plot in [xmin,xmax,ymin,ymax] format
index= set to 1 to plot index tiles. 

Original: Brendan Penney
Comments: Lance Mosher
*/

//-----Choose the region (if not defined)
	if (!is_array(color)){color=green;}
	if (!is_array(rgn)) {
		rgn = array(float, 4);
		a = mouse(1,1, "select region: ");
	        rgn(1) = min( [ a(1), a(3) ] );
        	rgn(2) = max( [ a(1), a(3) ] );
        	rgn(3) = min( [ a(2), a(4) ] );
        	rgn(4) = max( [ a(2), a(4) ] );
	}

//-----Find the boundaries of the index and data tiles.
//+++++This can be done more efficently using ceil and floor...
        til_e_min = 2000 * (int((rgn(1)/2000)));
        til_e_max = 2000 * (1+int((rgn(2)/2000)));
        if ((rgn(2) % 2000) == 0) til_e_max = rgn(2);
        til_n_min = 2000 * (int((rgn(3)/2000)));
        til_n_max = 2000 * (1+int((rgn(4)/2000)));
        if ((rgn(4) % 2000) == 0) til_n_max = rgn(4);
        
	ind_e_min = 10000 * (int((rgn(1)/10000)));
        ind_e_max = 10000 * (1+int((rgn(2)/10000)));
        if ((rgn(2) % 10000) == 0) ind_e_max = rgn(2);
        ind_n_min = 10000 * (int((rgn(3)/10000)));
        ind_n_max = 10000 * (1+int((rgn(4)/10000)));
        if ((rgn(4) % 10000) == 0) ind_n_max = rgn(4);

//-----Find number of east and north for index and data tiles
        n_east = (ind_e_max - ind_e_min)/2000;
        n_north = (ind_n_max - ind_n_min)/2000;
        n = n_east * n_north;
	in = n * 25;
        n_tieast = (til_e_max - til_e_min)/2000;
        n_tinorth = (til_n_max - til_n_min)/2000;
        nti = n_tieast * n_tinorth;
	
        min_e = array(float, nti);
        max_e = array(float, nti);
        min_n = array(float, nti);
        max_n = array(float, nti);
        
	imin_e = array(float, in);
	imax_e = array(float, in);
	imax_n = array(float, in);
	imin_n = array(float, in);

//-----Build arrays containing data tile dimensions and plot/label them
	i = 1;
        for (e=til_e_min; e<=(til_e_max-2000); e=e+2000) {
                for(north=(til_n_min+2000); north<=til_n_max; north=north+2000) {
                min_e(i) = e;
                max_e(i) = e+2000;
                min_n(i) = north-2000;
        	max_n(i) = north;
                i++;
                }
        }
	if(!(index)){
		pldj, min_e, min_n, min_e, max_n, color=color
		pldj, min_e, min_n, max_e, min_n, color=color
		pldj, max_e, min_n, max_e, max_n, color=color
		pldj, max_e, max_n, min_e, max_n, color=color
		for (i=1; i<=numberof(min_e); i++) {
			plt, swrite(format="t!_e%6.0f!_n%7.0f", float(min_e), float(max_n))(i), min_e(i)+30, max_n(i)-200, tosys=1, height=8
		}
	}

//-----Build arrays containing index tile dimesions and plot them 
	i=1
	for (e=ind_e_min;e<=(ind_e_max-10000);e=e+10000){
		for(north=(ind_n_min+10000); north<=ind_n_max; north=north+10000){
			imin_e(i) = e;
			imax_e(i) = e+10000
			imin_n(i) = north-10000;
			imax_n(i) = north
			i++
		}
	}
	
	if (index){  

        egooddata = where(imin_e !=0 );
	ngooddata = where(imax_n !=0 );	
	imin_e = imin_e(where(egooddata));
	imin_n = imin_n(where(ngooddata));	
        imax_e = imax_e(where(egooddata));
	imax_n = imax_n(where(ngooddata));

	if (!color) color="black"
        pldj, imin_e, imin_n, imin_e, imax_n, color=color
	pldj, imin_e, imin_n, imax_e, imin_n, color=color
        pldj, imax_e, imin_n, imax_e, imax_n, color=color
        pldj, imax_e, imax_n, imin_e, imax_n, color=color
        limits, min(imin_e), max(imax_e), min(imin_n), max(imax_n);
	}
}
