/* 
      $Id$

   8-20-02 -ww Added to Document comment. Fixed spelling.
*/

local rcf_help
/* DOCUMENT rcf_help

*/

func rcf( jury, w, mode= ) {
/* DOCUMENT rcf( jury, w, mode= )
Generic Random Consensus filter.  The jury is the 
array to test for consensis, and w is the window range
which things can vary within.

  Orginal: C. W. Wright 6/15/2002 wright@lidar.wff.nasa.gov

jury       The array of points used to reach the consenus.

w          The window width.

Mode=
	0  Returns an array consisting of two elements
           where the first is the minimum value of the 
           window and the second element is the number 
           of votes.
        
        1  Returns the average of the winners.

	2  Returns a index list of the winners
	
	Explanation of variables:
	i -		index
	jury - 		initial set of points
	vote - 		number of points that are included in the window 
                        range during each pass
	kwinners-	points that have been filtered or maximum of points
                        that can be included in the window range.
	w -		window range that points will be tested against
	winners- 	points within the window range after one pass
	wtop -		window upper bound value

	The following is a simple method to test the filter:

	For jury we will use the array a:
    a = float([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150])
	And lets set the window size to 6: w = 6
	
	The default mode:
	rcf(a, w) and Enter
	The result printed on the screen will be the following:
	[98, 100] where 98 is the minimum value of the points in the window

	Mode 1
	rcf(a, w, mode= 1) and Enter
	The result printed on the screen will be:
	[100.1, 10] where 100.1 is the average value within the window
	and 10 is the number of points within that window range.

	Mode 2
	rcf(a, w, mode= 2) and Enter
	The result printed on the screen will be: 
	10			number of points within the window
	[1,2,3,4,5,6,7,8,9,10]	 kwinners array
	4 	       	      vote
	[0x81121bc,0x814d9bc]	location in memory of sorted list of kwinners
	and address of vote.


For a description on this method, see:

Random Sample Consensus - A paradigm for model-fitting 
with applications to image-analysis and automated cartography,

Fischler MA, Bolles RC, Communications of the ACM, 
24 (6): 381-395 1981
 
FISCHLER MA, SRI INT,CTR ARTIFICIAL INTELLIGENCE,MENLO PK,CA 94025
 
Publisher:
ASSOC COMPUTING MACHINERY, NEW YORK


*/


  if ( is_void(mode) )
	mode = 0;
  si = sort(jury);		// order the jury
  nj = numberof(jury);
  if ( nj > 10000 )
  write,format="** Warning **  %d points in rcf jury pool... May be slow...", nj
  vote = 0;
  nvote = -1;
  for (i=1; i<=nj; i++ ) {
    wtop = jury(si(i)) + w;   // set top value
   winners = where(jury(si(i:0)) < wtop )
   nvote = numberof( winners )
    if ( nvote >= vote ) { 
       vote = nvote;
       iidx = i;
       kwinners = winners
    }
    if ( vote > (nj-i) ) 
	break;
  }
  if ( mode == 0 ) {     
	 return [jury(si(iidx)), vote];
  } else if ( mode == 1 ) {
    return [  jury(si(iidx : iidx + vote -1))(avg), vote ];
  } else if ( mode == 2 ) {
  	return [ &si(kwinners+iidx-1), &vote ]
  }
}




func moving_rcf( yy, fw, n) {
/* DOCUMENT moving_rcf( yy, fw, n )

 This function filters a vector of data (yy) with rcf using a filter width of (fw) 
and a jury of +/-(n).  It returns an index list to yy of the points within the 
filter.  This is used in transect.i.


See also: rcf, rcf.i, transect, mtransect.
Original:  W. Wright 9/30/2003

*/

   np = numberof(yy);
   edt = array(0, np);
   for ( i=n+1; i<= np-n; i++ ) {
     rv = rcf(yy(i-n:i+n),  fw, mode=0);
     if ( (rv(2) >=2) ) {
       v = yy(i);
       ll = rv(1); ul=ll+fw;
       if (( v >= ll) && ( v <= ul))  {
            edt(i) = 1;
       }
     }
   }
   return (where( edt )) ;
 }


