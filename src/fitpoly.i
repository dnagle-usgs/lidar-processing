
/*
 * fitpoly.i
 * least squares fit of polynomial to data

   $Id$
 */

func fitpoly(n, x, y, w)
/* DOCUMENT fitpoly(n, x, y)
         or fitpoly(n, x, y, w)

     return [a0,a1,a2,...aN], the coefficients of the least squares
     fit polynomial of degree N to the data points (X, Y).

     X and Y must be arrays of N+1 or more points.  The optional
     parameter W is a weight array, which must be conformable with
     X and Y; it defaults to 1.0.  If the standard deviation of Y
     is sigma, conventional wisdom is that W = 1/sigma^2.

   SEE ALSO: poly2
 */
{
  if (is_void(w)) w= 1.;
  scale= 1./max(abs(x));
  x*= scale;
  y= double(y);

  xi= w*array(1.,dimsof(x));
  matrix= array(sum(xi), n+1, n+1);
  rhs= array(sum(y), n+1);

  power= indgen(0:n)(,-:1:n+1) + indgen(0:n)(-:1:n+1,);
  for (i=1 ; i<=2*n ; i++) {
    xi*= x;
    matrix(where(power==i))= sum(xi);
    if (i<=n) rhs(i+1)= sum(y*xi);
  }

  xi= LUsolve(matrix, rhs);
  xi(2:n+1)*= scale^indgen(n);

  return xi;
}

func poly2(x, a)
/* DOCUMENT poly(x, a0, a1, a2, ..., aN)
     returns the polynomial  A0 + A1*x + A2*x^2 + ... + AN*X^N
     The data type and dimensions of the result, and conformability rules
     for the inputs are identical to those for the expression.
   SEE ALSO: poly
 */
{
  y= array(structof(x), dimsof(x));
  for (n=dimsof(a)(0) ; n>0 ; n--) y= a(..,n) + y*x;
  return y;
}


