#!/usr/local/ActiveTcl/bin/wish

#
#
#  $Id$
#
#  Orginal W. Wright 8/25/2002
#

    set ifn [ tk_getOpenFile -initialdir "/data/" ]
    set ifd [ open $ifn "r" ] 
    
    set data [ read $ifd] 

    text .txt \
	-width 125 \
	-height 20 \
	-wrap none \
 	-yscrollcommand { .ysbar set }	
	scrollbar .ysbar -orient vertical   -command { .txt yview }
    grid .txt .ysbar -sticky nsew
    grid columnconfigure . 0 -weight 1
    .txt insert end $data	
 



