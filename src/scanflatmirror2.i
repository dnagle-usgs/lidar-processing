func scanflatmirror2_direct_vector(arZ, arX, arY, gx, gy, gz, dx, dy, dz, maZ, laX, maX, maY, mag, &mx, &my, &mz, &px, &py, &pz)
{
/* DOCUMENT scanflatmirror2_direct_vector(arZ, arX, arY, gx, gy, gz, dx, dy,
   dz, maZ, laX, maX, maY, mag, &mx, &my, &mz, &px, &py, &pz)

  This function computes a vector (M) of xyz points projected in 3D space from
  the origin...which in this case is the center of rotation of planar mirror
  rotated about the y-axis.  The mirror will face the negative y-axis with a
  pitch angle of -22.5 degrees. An incident vector intersects this mirror 45
  degs.  from vertical. The direction of this vector is positive going giving
  [0 mag 0] as our incident vector.

  In the 'incident vector' above, 'mag' is the distance from the mirror to the
  ground point.

  Input parameters:

    arZ - yaw angle (z) of aircraft
    arX - pitch angle (x) of aircraft
    arY - roll angle (y) of aircraft
    gx  - GPS antenna x position
    gy  - GPS antenna y position
    gz  - GPS antenna z position
    dx  - delta x distance from GPS antenna to mirror exit
    dy  - delta y distance from GPS antenna to mirror exit
    dz  - delta z distance from GPS antenna to mirror exit
    maZ - mounting angle of mirror/laser chassis about z-axis (same angle used
          for both mirror and laser)
    laX - mounting angle of laser about x-axis
    maX - mounting angle of mirror about x-axis
    maY - current angle of mirror rotating about y-axis
    mag - magnitude of vector in 'y' direction (distance mirror to ground)

  Return array is as follows (all values are in meters)
    mx = mirror east
    my = mirror north
    mz = mirror elevation
    px = target point east
    py = target point north
    pz = target point elevation

  Mathematics involved:

  --- Matrices of rotation ---

  There are two cases where we use a set of rotations about the y-, x-, and z-
  axes to shift from one frame of reference to another. The mathematics in both
  cases are the same. For brevity, those mathematics are described generally
  here, then related more specifically later.

  Given values for rotation about the y-axis (typically called roll), about the
  x-axis (typically called pitch) and about the z-axis (typically called yaw or
  heading) repesented by variables X, Y, and Z, respectively; each in radians.

  Define the sine and cosine of each angle as follows:
    sx = sin(X)
    sy = sin(Y)
    sz = sin(Z)
    cx = cos(X)
    cy = cos(Y)
    cz = cos(Z)

  The matrices for rotation about the three axes will be called Ry, Rx, and Rz.
  They are defined as follows.

         / 1 0  0   \        / cy  0 sy \        / cz -sz 0 \
    Rx = | 0 cx -sx |   Ry = | 0   1 0  |   Rz = | sz cz  0 |
         \ 0 sx cx  /        \ -sy 0 cy /        \ 0  0   1 /

  These three matrices must be applied in the order Y-X-Z. If we were
  converting a vector P, we would perform the following calculations:

    Rz * Rx * Ry * P

  Where * represents matrix multiplication. The part "Rz * Rx * Ry" can be
  multiplied out and simplified.

                   / cz -sz 0 \   / 1 0   0  \   /  cy 0 sy \
    Rz * Rx * Ry = | sz  cz 0 | * | 0 cx -sx | * |  0  1 0  |
                   \ 0   0  1 /   \ 0 sx  cx /   \ -sy 0 cy /

                   / cz -sz 0 \   / (cy)     (0)  (sy)     \
                 = | sz  cz 0 | * | (sx*sy)  (cx) (-sx*cy) |
                   \ 0   0  1 /   \ (-cx*sy) (sx) (cx*cy)  /

                   / (cy*cz - sx*sy*sz) (-cx*sz) (sy*cz + sx*cy*sz) \
                 = | (cy*sz + sx*sy*cz) (cx*cz)  (sy*sz - sx*cy*cz) |
                   \ (-cx*sy)           (sx)     (cx*cy)            /

                    / A B C \
                 -> | D E F |
                    \ G H I /

  The 9 matrix elements are stored in variable components named A through I.

    / A B C \   / (cy*cz - sx*sy*sz) (-cx*sz) (sy*cz + sx*cy*sz) \
    | D E F | = | (cy*sz + sx*sy*cz) (cx*cz)  (sy*sz - sx*cy*sz) |
    \ G H I /   \ (-cs*sy)           (sx)     (cx*cy)            /

  --- Rotation of aircraft wrt real world ---

  The angles arZ, arX, and arY define a set of rotations necessary to change
  from the aircraft's rotational frame of reference to the real world's
  rotational frame of reference. These angles are applied as described in
  "Matrices of rotation" above.

  In the code for this function, these three rotations are achieved using a
  matrix Rar (*R*otation from *a*ircarft to *r*eal world) which is comprised of
  nine variables as follows:

    / RarA RarB RarC \   / (cy*cz - sx*sy*sz) (-cx*sz) (sy*cz + sx*cy*sz) \
    | RarD RarE RarF | = | (cy*sz + sx*sy*cz) (cx*cz)  (sy*sz - sx*cy*sz) |
    \ RarG RarH RarI /   \ (-cs*sy)           (sx)     (cx*cy)            /

  --- Location of mirror ---

  To determine the location of the mirror, the displacement vector from the GPS
  unit to the mirror is changed from the aircraft's rotational frame of
  reference to that of the real world; then the displacement vector is added to
  the GPS unit's location. We represent the GPS antenna's location using the
  variable g (gx, gy, gz) and the displacement vector using the variable d (dx,
  dy, dz). The rotations are handled using the rotation matrix Rar as described
  above. The mirror's location is stored in the variable m (mx, my, mz).
  Mathematically:

    m = g + Rar * d

  Where * represents matrix multiplication. In the code, this is separated out
  into individual variables:

    mx = RarA*dx + RarB*dy + RarC*dz + gx
    my = RarD*dx + RarE*dy + RarF*dz + gy
    mz = RarG*dx + RarH*dy + RarI*dz + gz

  --- Rotation of mirror wrt aircraft ---

  The angles maZ, maX, and maY define a set of rotations necessary to change
  from the mirror's rotation frame of reference to the aircraft's rotation
  frame of reference. These angles are applied as described in "Matrices of
  rotation" above.

  In the code for this function, these three rotations are acehived using a
  matrix Rma (*R*otation from *m*irror to *a*ircraft) which is comprised of
  nine variables as follows:

    / RmaA RmaB RmaC \   / (cy*cz - sx*sy*sz) (-cx*sz) (sy*cz + sx*cy*sz) \
    | RmaD RmaE RmaF | = | (cy*sz + sx*sy*cz) (cx*cz)  (sy*sz - sx*cy*sz) |
    \ RmaG RmaH RmaI /   \ (-cs*sy)           (sx)     (cx*cy)            /

  For reasons described elsewhere, we only end up actually using three of those
  variables (RmaC, RmaF, and RmaI) so the other six are not actually defined in
  the code.

  --- Rotation of laser wrt aircraft ---

  The angles maZ and laX define a set of rotations necessary to change from the
  laser's frame of rotation to the aircraft's frame of rotation. There is no
  rotation necessary about the Y axis, so there is an implicit laY=0. These
  angles are applied as described in "Matrices of rotation" above. However,
  since the rotation about the Y axis is zero, the math can be simplified.

  The individual rotation matrices:

         / 1 0  0   \        / cy  0 sy \        / cz -sz 0 \
    Rx = | 0 cx -sx |   Ry = | 0   1 0  |   Rz = | sz cz  0 |
         \ 0 sx cx  /        \ -sy 0 cy /        \ 0  0   1 /

  However, Ry simplifies to the identity matrix:

         / cy  0 sy \   / cos(0)  0 sin(0) \   / 1 0 0 \
    Ry = | 0   1 0  | = | 0       1 0      | = | 0 1 0 |
         \ -sy 0 cy /   \ -sin(0) 0 cos(0) /   \ 0 0 1 /

  The composite matrix is not used as is in the code, but it will be referred
  to as Rla (*R*otation from *l*aser to *a*ircraft) in these notes. The
  composite rotation matrix simplifies as follows:

                         / cz -sz 0 \   / 1 0   0  \   / 1 0 0 \
    Rla = Rz * Rx * Ry = | sz  cz 0 | * | 0 cx -sx | * | 0 1 0 |
                         \ 0   0  1 /   \ 0 sx  cx /   \ 0 0 1 /

                         / cz -sz 0 \   / 1 0   0  \
                       = | sz  cz 0 | * | 0 cx -sx |
                         \ 0   0  1 /   \ 0 sx  cx /

                         / (cz) (-cx*sz) (sx*sz)  \
                       = | (sz) (cx*cz)  (-sx*cz) |
                         \ (0)  (sx)     (cx)     /

  --- Incidence vector for laser ---

  In its own frame of rotation, the laser comes in from the y axis and is
  represented by an incidence vector of <0, -1, 0>.

  Using the rotation matrix Rla from "Rotation of laser wrt aircraft" above,
  the vector can be put in the aircraft's frame of rotation. We can then
  further transition it into the real world's frame of reference using the
  matrix Rar from "Rotation of aircraft wrt real world" above.

  The vector of incidence in its own frame of reference is refered to as LIl;
  in the real world's frame of reference, LIr.

    LIr = Rar * Rla * LIl

          / RarA RarB RarC \   / (cz) (-cx*sz) (sx*sz)  \   /  0 \
    LIr = | RarD RarE RarF | * | (sz) (cx*cz)  (-sx*cz) | * | -1 |
          \ RarG RarH RarI /   \ (0)  (sx)     (cx)     /   \  0 /

          / RarA RarB RarC \   / cx*sz  \
        = | RarD RarE RarF | * | -cx*cz |
          \ RarG RarH RarI /   \ -sx    /

          / RarA*cx*sz + -RarB*cx*cz + -RarC*sx \
        = | RarD*cx*sz + -RarE*cx*cz + -RarF*sx |
          \ RarG*cx*sz + -RarH*cx*cz + -RarI*sx /

          / (RarA*sz - RarB*cz)*cx - RarC*sx \   / LIrX \
        = | (RarD*sz - RarE*cz)*cx - RarF*sx | = | LIrY |
          \ (RarG*sz - RarH*cz)*cx - RarI*sx /   \ LIrZ /

  --- Normal vector for laser ---

  The laser reflects off the mirror. The mirror lies within the plane formed by
  the X and Y axes of its own frame of rotation. Thus, the surface normal
  vector would be along the Z axis: <0,0,1>.

  The normal vector in its own frame of reference is refered to as LNm; in the
  real world's frame of reference, LNr. Following similar math as in other
  sections above, LNr is derived as follows.

    LNr = Rar * Rma * LNm

          / RarA RarB RarC \   / RmaA RmaB RmaC \   / 0 \
    LNr = | RarD RarE RarF | * | RmaD RmaE RmaF | * | 0 |
          \ RarG RarH RarI /   \ RmaG RmaH RmaI /   \ 1 /

          / RarA RarB RarC \   / RmaC \
        = | RarD RarE RarF | * | RmaF |
          \ RarG RarH RarI /   \ RmaI /

          / RarA*RmaC RarB*RmaF RarC*RmaI \   / LNrX \
        = | RarD*RmaC RarE*RmaF RarF*RmaI | = | LNrY |
          \ RarG*RmaC RarH*RmaF RarI*RmaI /   \ LNrZ /

  --- Reflection vector for laser ---

  The vector of spectral reflection (in the real world's frame of rotation) is
  refered to as LSr. It is derived using the equation for spectral reflection
  off of a mirror.

    LSr = 2 * (LNr . LIr) * LNr - LIr

  Where the period "." stands for dot product.

  The dot product of LNr and LIr is referred to as DP below. It is computed as
  follows:

    DP = LNrX*LIrX + LNrY*LIrY + LNrZ*LIrZ

  The earlier equation for LSr then simplifies to:

    LSr = 2 * DP * LNr - LIr

                   / LNrX \   / LIrX \
    LSr = 2 * DP * | LNrY | - | LIrY |
                   \ LNrZ /   \ LIrZ /

  --- Location of target ---

  The mirror has a known location m. The target point is at a distance of mag
  in the direction of LSr. Thus, the target point p is derived as follows.

    p = LSr * mag + m

    px = LSrX * mag + mx
    py = LSrY * mag + my
    pz = LSrZ * mag + mz
*/
  z = arZ * DEG2RAD;
  x = arX * DEG2RAD;
  y = arY * DEG2RAD;
  arZ = arX = arY = [];

  cx = cos(x);
  cy = cos(y);
  cz = cos(z);
  sx = sin(x);
  sy = sin(y);
  sz = sin(z);
  x = y = z = [];

  SXSY = sx*sy;
  CYCZ = cy*cz;
  CYSZ = cy*sz;

  RarA = CYCZ - sz*SXSY;
  RarB = -sz*cx;
  RarC = cz*sy + CYSZ*sx;
  RarD = CYSZ + cz*SXSY;
  RarE = cz*cx;
  RarF = sz*sy - CYCZ*sx;
  RarG = -cx*sy;
  RarH = sx;
  RarI = cx*cy;
  SXSY = CYCZ = CYSZ = cx = cy = cz = sx = sy = sz = [];

  mx = RarA*dx + RarB*dy + RarC*dz + gx;
  my = RarD*dx + RarE*dy + RarF*dz + gy;
  mz = RarG*dx + RarH*dy + RarI*dz + gz;
  dx = dy = dz = gx = gy = gz = [];

  laX = laX * DEG2RAD;
  maX = maX * DEG2RAD;
  maY = maY * DEG2RAD;
  maZ = maZ * DEG2RAD;

  clax = cos(laX);
  slax = sin(laX);
  cmax = cos(maX);
  smax = sin(maX);
  cmay = cos(maY);
  smay = sin(maY);
  cmaz = cos(maZ);
  smaz = sin(maZ);
  laX = maX = maY = maZ = [];

  LIrX = (RarA*smaz - RarB*cmaz)*clax - RarC*slax;
  LIrY = (RarD*smaz - RarE*cmaz)*clax - RarF*slax;
  LIrZ = (RarG*smaz - RarH*cmaz)*clax - RarI*slax;
  clax = slax = [];

  RmaC = cmaz*smay+smaz*smax*cmay;
  RmaF = smaz*smay-cmaz*smax*cmay;
  RmaI = cmax*cmay;
  cmax = smax = cmay = smay = cmaz = smaz = [];

  LNrX = RarA*RmaC + RarB*RmaF + RarC*RmaI;
  LNrY = RarD*RmaC + RarE*RmaF + RarF*RmaI;
  LNrZ = RarG*RmaC + RarH*RmaF + RarI*RmaI;

  DP = LNrX*LIrX + LNrY*LIrY + LNrZ*LIrZ;

  LSrX = 2 * DP * LNrX - LIrX;
  LSrY = 2 * DP * LNrY - LIrY;
  LSrZ = 2 * DP * LNrZ - LIrZ;
  DP = LNrX = LNrY = LNrz = LIrX = LIrY = LIrZ = [];

  px = LSrX * mag + mx;
  py = LSrY * mag + my;
  pz = LSrZ * mag + mz;
}
