/* 
      $Id$
*/

local rcf_help
/* DOCUMENT rcf_help
	Rcf - Random Consesus Filter
	
	The following is an array that can be used to test rcf.i:
	a = float([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150])
		
	i -			index
	jury - 		initial set of points
	vote - 		number of points that are included in the window range
				during each pass
	kwinners-	points that have been filtered or maximum of points
				that can be included in the window range.
	w -		window range that points will be tested against
	winners- 	points within the window range after one pass
	wtop -		window upper bound value
*/
	

/* DOCUMENT rcf( jury, w )
   
   Generic Random Concensus filter.  The jury is the 
array to test for concensis, and w is the window range
which things can vary within.

  Orginal: C. W. Wright 6/15/2002

Mode=
	0  Returns an array consisting of two elements
           where the first is the minimum value of the 
           window and the second element is the number 
           of votes.
        
        1  Returns the average of the winners.

	2  Returns a index list of the winners
*/
func rcf( jury, w, mode= ) {
  if ( is_void(mode) )
	mode = 0;
  si = sort(jury);		// order the jury
  nj = numberof(jury);
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
  vote 
  kwinners
  iidx
  	return [ &si(kwinners+iidx-1), &vote ]
  }
  
}
