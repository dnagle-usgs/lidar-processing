extern processing_dmars
/* DOCUMENT  processing_dmars

 dmarsd -> *.bin -> 
                  dmars2iex.c -> *.imu -> 
                                      Iex -> *.ascii -> 
                                                      iex_ascii2pbd -> *.pbd


// Example:
> #include "dmars.i"
> iex_ascii2pbd, "/full/path/*ins.txt"
// This will create the .pbd file in the same directory as the .txt file

// Now goto "ytk/File/Restore PBD Data file..." to select the generated file.
//    iex_head      iex_nav

// Next run:
> iex2tans
// This overwrites the tans structure.

> ops_conf = ops_IMU2_default  // You will need to have done
                               // "Process Lidar Data..."

*/


extern processing_dmars_cat
/* DOCUMENT Processing DMARS cat files.

  The DMARS "cat" files are raw dmars datafiles captured directly from the DMARS unit
  without any error checking, or time stamping at all.  These files can be manually
  synced with time and post processed into *.imu files which IEX will read.  This is
  generally only required when the normal dmars datasystem had a problem.


  O 	Generate a .imu file using dmars2iex
  O	Run ytk and load "dmars.i"
  O	Run the function load_iex, "your imu file"
  O	Copy the data to iex0 variable.
  O 	Plot the vertical accel vs time with:
 	window,0; fma; plg, iex.sensors(0,),iex.sow, color="red"       
  O	Adjust the limits to see the data. If there's bad data in the file
        the good data may be in a thin vertical line.  Zoom in on it.
  O	Now process the "cat" file with:
        dmarscat2iex -d incputfile -O outputfile
  O	Load it with: load_iex, "your cat imu file"
  O	Plot it with:
	window,1; fma; plg, iex.sensors(0,),iex.sow, color="red"
  O     Now, lets find the delta time between the two data sets.
  O	Identify the same feature in each data set and zoom in on each one.
  O	Now run:
	   window,0; m = mouse(); window,1; int((mouse(1) -m)(1))
        to determin the time difference between the two.
  O 	Now rerun the dmarscat2iex with the -t option as follows:
        dmarscat2iex -t NNN -d incputfile -O outputfile
        ** NNN = the time diff you determined above.
  O	Reload the new file with:
           load_iex, "your cat imu file
  O    Replot it with: 
           window,1; fma; plg, iex.sensors(0,),iex.sow, color="red"
  O 	Compare the two for time differences.



 

*/



