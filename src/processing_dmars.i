/* DOCUMENT  processing_dmars

 dmarsd -> *.bin -> 
                  dmars2iex.c -> *.imu -> 
                                      Iex -> *.ascii -> 
                                                      iex_ascii2pbd -> *.pbd


Example: iex_ascii2pbd, "/full/path/*imu*.txt"
This will create the .pbd file in the same directory as the .txt file

Now goto "ytk/File/Restore PBD Data file..." to select the generated file.
    iex_head      iex_nav

Next run: iex2tans
This overwrites the tans structure.

> ops_conf = ops_IMU2_default  # You will need to have done
                               # "Process Lidar Data..."

*/
