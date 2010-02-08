/******************************************************************************\
* This function was moved to the attic on 2010-02-08. It was removed from      *
* manual_filter.i. This function is not in use any longer and provides no      *
* necessary functionality. It is left over from earlier methods of data        *
* processing that are no longer in use.                                        *
\******************************************************************************/

func write_to_final_arr(temp_arr) {
  // amar nayegandhi 11/21/03
  extern final_arr, cur_east, cur_north, cur_csize;
  final_arr = grow(final_arr, temp_arr);
  pldj, [cur_east,cur_east,cur_east+cur_csize,cur_east+cur_csize],
    [cur_north-cur_csize, cur_north, cur_north, cur_north-cur_csize],
         [cur_east, cur_east+cur_csize, cur_east+cur_csize, cur_east],
         [cur_north, cur_north, cur_north-cur_csize, cur_north-cur_csize],
         color="green", width=1.5;
}

