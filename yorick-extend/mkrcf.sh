#  
#  $Id$
#   
#  This script generates the rcf.c file from rcfbase1.c & rcfbase2.c
#  It then goes on to produce a new yorick executable called rcf_yorick
#
#  Original rcf.i by C.W.Wright
#  Converted to "C" by Conan Noronha
#

 cp rcfbase1.c rcf.c

 mv Makefile Makefile.old

 NAME=rcf
 COMP=compare

 TYPE=float

 cpp -P -C -D CNAME=${TYPE}_${COMP} -D COPY=fcopy -D FNAME0=${NAME}_${TYPE}_0 -D FNAME1=${NAME}_${TYPE}_1 -D FNAME2=${NAME}_${TYPE}_2 -D CNAME2=c_${TYPE}_fillarray -D CSJURY=csfjury -D TCSJURY=tcsfjury -D FNAME3=${NAME}_${TYPE}_3 -D TYPE=float  rcfbase2.c >> rcf.c 

 TYPE=double

 cpp -P -C -D CNAME=${TYPE}_${COMP} -D COPY=dcopy -D FNAME0=${NAME}_${TYPE}_0 -D FNAME1=${NAME}_${TYPE}_1 -D FNAME2=${NAME}_${TYPE}_2 -D CNAME2=c_${TYPE}_fillarray -D CSJURY=csdjury -D TCSJURY=tcsdjury -D FNAME3=${NAME}_${TYPE}_3 -D TYPE=double  rcfbase2.c >> rcf.c

 TYPE=long

 cpp -P -C -D CNAME=${TYPE}_${COMP} -D COPY=lcopy -D FNAME0=${NAME}_${TYPE}_0 -D FNAME1=${NAME}_${TYPE}_1 -D FNAME2=${NAME}_${TYPE}_2 -D CNAME2=c_${TYPE}_fillarray -D CSJURY=csljury -D TCSJURY=tcsljury -D FNAME3=${NAME}_${TYPE}_3 -D TYPE=long  rcfbase2.c >> rcf.c

 TYPE=int

 cpp -P -C -D CNAME=${TYPE}_${COMP} -D COPY=icopy -D FNAME0=${NAME}_${TYPE}_0 -D FNAME1=${NAME}_${TYPE}_1 -D FNAME2=${NAME}_${TYPE}_2 -D CNAME2=c_${TYPE}_fillarray -D CSJURY=csijury -D TCSJURY=tcsijury -D FNAME3=${NAME}_${TYPE}_3 -D TYPE=int  rcfbase2.c >> rcf.c


# YORICK building stuff
  
  yorick -batch make.i rcf_yorick rcf.i triangulate.i
  make

