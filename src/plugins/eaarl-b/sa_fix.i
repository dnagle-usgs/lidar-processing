// vim: set ts=2 sts=2 sw=2 ai sr et:

/*
   Test program to fix scan angle error:  Richard Mitchell

   This file isn't loaded by default.
*/

struct SAB {
  int    beg;
  int    end;
  double svg;   // sa average
}

func sa_fix( rtrs ) {
  cnt = numberof(rtrs);
  sa_err = array(0, cnt);

  for ( i=1; i<=cnt; ++i ) {
    x = rtrs(i);
    if ( x.sa(1) > x.sa(118) ) {
      sa_err(i) = 200 - x.sa(1)
    } else {
      sa_err(i) = 200 - x.sa(118)
    }
  }
  return sa_err;
}

func compute_sa ( arr, fix= ) {
  /*
  arr  is the output from irg(()
  fix= is the desired scan angle value)
  */
  cnt = numberof( arr );
  t   = array(0, cnt);
  beg = array(0, 100);
  end = array(0, 100);
  shf = 1;
  default, fix, 0;

  x = 0.0;

  beg(shf) = 1;
  b  = arr.sa(1,beg(shf):9);
  op = abs(b(ptp));

  gap = 7; // XYZZY - make larger to get fewer adjustments
  for ( i=10; i<=cnt; ++i) {
    b = arr.sa(1,beg(shf):i);
    p = abs(b(ptp));
    // if ( abs(p - op) > gap ) {
    if ( p > 36 ) {
      end(shf) = i-1;
      my_avg = arr.sa(1, beg(shf):end(shf))(avg);
      ++shf;
      beg(shf) = i;

      /*
      write, format="DELTA  %7d:  %4d : %4d %4d : (%f) (%4d : %4d)\n",
        i,
        abs(p - op),
        op, p,
        my_avg,
        beg(shf-1), end(shf-1);
      */

      b  = arr.sa(1,beg(shf):i+(9));
      p = abs(b(ptp));
      i += 10;
    }
    op = p;

  }
  end(shf) = cnt;
  my_avg = arr.sa(1, beg(shf):end(shf))(avg);

  /*
  write, format="Delta  %7d:  %4d : %4d %4d : (%f)\n",
    i,
    abs(p - op),
    op, p,
    my_avg;
  */

  beg = beg(where(beg));
  end = end(where(end));
  // beg;
  // end;

  qux = arr.sa;
  sab = array(SAB, numberof(beg));
  for (i=1; i <= numberof(beg); ++i ) {
    my_avg = arr.sa(1, beg(i):end(i))(avg);
    qux(*,beg(i):end(i)) = arr.sa(*,beg(i):end(i)) - my_avg + fix;

    sab(i).beg = beg(i);
    sab(i).end = end(i);
    sab(i).svg = my_avg;

  }
  arr.sa = qux;

  return sab;
}

func comp_alt_sa( edb ) {
  lim = numberof(edb);

  default, set_sa, [120, -120];

  // *******************   Determine the major shifts
  foo=irg(1,lim, usecentroid=0, skip=200);
  bpark = compute_sa(foo, fix=fix);
  "BALLPARK:"
  bpark.end *= 200;   // adjust for skip
  bpark.end(0) = lim; // reset last value to limit
  bpark;

  // *******************   Fine tune the solution
  sab = [];
  for ( i=1; i<numberof(bpark); ++i) {
    /*
    write, format="i=%d : %7d\n", i, bpark(i).end;
    write, format="lim= %d to %d\n",
      bpark(i).end-100,
      min(lim, bpark(i).end+100);
    */

    foo=irg( bpark(i).end-100, min(lim, bpark(i).end+100), usecentroid=0, skip=1);

    if ( foo(1).sa(1) > foo(1).sa(118) ) {
      fix=set_sa(1);
    } else {
      fix=set_sa(2);
    }

    tsab  = compute_sa(foo, fix=fix);
    tsab.end += bpark(i).end;
    sab = grow(sab, tsab(1));
    sab(0) = bpark(i);
  }
  sab = grow(sab, bpark(0));

  // *******************   print the final report
  write, "Start Report";
  for ( i=1; i<=numberof(sab); ++i) {
    write, format="%2d: %7d to %7d:",
      i,
      sab(i).beg, sab(i).end;
    foo = irg( sab(i).beg, sab(i).end, usecentroid=0, skip=100);
    write, format="\t%4d  %8.3f  : %d\n",
      foo.sa(1,*)(ptp), foo.sa(1,*)(avg),
      sab(i).end - sab(i).beg;

    sab(i).svg = foo.sa(1,*)(avg);

    if ( i<numberof(sab) ) sab(i+1).beg = sab(i).end+1;
  }

  return sab;
}

func sa_wrapper( orig_edb ) {
  extern sab1, sab2,
       fix_sa1, fix_sa2;

  edb1 =  orig_edb(1::2);
  edb2 =  orig_edb(2::2);

  sab1 = comp_alt_sa(edb1);
  sab2 = comp_alt_sa(edb2);

  --sab1.beg
  --sab1.end
  sab1.beg *= 2;
  sab1.end *= 2;
  ++sab1.beg;
  ++sab1.end;

  fix_sa1 = array(0, numberof(orig_edb))
  fix_sa2 = array(0, numberof(orig_edb))

  for ( i=1; i<=numberof(sab1); ++i ) {
    fix_sa1(sab1(i).beg:sab1(i).end) = sab1(i).svg;
  }
  for ( i=1; i<=numberof(sab2); ++i ) {
    fix_sa2(sab2(i).beg:sab2(i).end) = sab2(i).svg;
  }
}
