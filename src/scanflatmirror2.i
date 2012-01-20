func scanflatmirror2_direct_vector(yaw, pitch, roll, gx, gy, gz, dx, dy, dz, cyaw, lasang, mirang, curang, mag, &mx, &my, &mz, &px, &py, &pz)
{
/* DOCUMENT scanflatmirror2_direct_vector(yaw, pitch, roll, gx, gy, gz, dx, dy,
   dz, cyaw, lasang, mirang, curang, mag, &mx, &my, &mz, &px, &py, &pz)

  This function computes a vector (M) of xyz points projected in 3D space from
  the origin...which in this case is the center of rotation of planar mirror
  rotated about the y-axis.  The mirror will face the negative y-axis with a
  pitch angle of -22.5 degrees. An incident vector intersects this mirror 45
  degs.  from vertical. The direction of this vector is positive going giving
  [0 mag 0] as our incident vector.

  In the 'incident vector' above, 'mag' is the distance from the mirror to the
  ground point.

  Input parameters:

    yaw    - yaw angle (z) of aircraft
    pitch  - pitch angle (x) of aircraft
    roll   - roll angle (y) of aircraft
    gx     - GPS antenna x position
    gy     - GPS antenna y position
    gz     - GPS antenna z position
    dx     - delta x distance from GPS antenna to mirror exit
    dy     - delta y distance from GPS antenna to mirror exit
    dz     - delta z distance from GPS antenna to mirror exit
    cyaw   - yaw angle (z) about laser/mirror chassis
    lasang - mounting angle of laser about x-axis
    mirang - mounting angle of mirror about x-axis
    curang - current angle of mirror rotating about y-axis
    mag    - magnitude of vector in 'y' direction (distance mirror to ground)

  Return array is as follows (all values are in meters)
    mx = mirror east
    my = mirror north
    mz = mirror elevation
    px = target point east
    py = target point north
    pz = target point elevation
*/

// These are the dimensions upon which everything else is based.
dims = dimsof(yaw, pitch, roll, gx, gy, gz, dx, dy, dz, cyaw, lasang, mirang,
   curang, mag);

// Convert the yaw, pitch, roll into radians. We name the variables z, x, y
// because these are the rotations about those axes.
z = yaw * DEG2RAD;
x = pitch * DEG2RAD;
y = roll * DEG2RAD;

// Clear memory
yaw = pitch = roll = [];

/*
Following, we define a matrix that will transform coordinates from the plane's
frame of reference to the GPS (world) frame of reference. We define nine
variables, A through I, to represent this matrix:

   / A B C \
   | D E F |
   \ G H I /

The deriviation of this matrix is as follows.

We have values for roll, pitch, and heading, which are the angular rotations
performed to transform between the two frames of reference. These correspond to
angular transforms about the y-axiz, x-axis, and z-axis, in that order. To
tranform a coordinate vector P in plane coordinates [Px,Py,Pz] to the
equivalent gps coordinate G in gps coordinates [Gx,Gy,Gz], we need to perform a
series of matrix multipications as follows:

   Rz * Rx * Ry * P -> G

Rz, Rx, and Ry are the matrixes used to rotate about the z-axis, x-axis, and y-axis respectively. They are defined as follows:

        / 1 0   0  \        /  cy 0 sy \        / cz -sz 0 \
   Rx = | 0 cx -sx |   Ry = |  0  1 0  |   Rz = | sz  cz 0 |
        \ 0 sx  cx /        \ -sy 0 cy /        \ 0   0  1 /

If we multiply the three matrices together, the result is the following:

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

As indicated, we store the matrix elements in the variables A through I.

   / A B C \   / (cy*cz - sx*sy*sz) (-cx*sz) (sy*cz + sx*cy*sz) \
   | D E F | = | (cy*sz + sx*sy*cz) (cx*cz)  (sy*sz - sx*cy*sz) |
   \ G H I /   \ (-cs*sy)           (sx)     (cx*cy)            /

Note: In the above, sin(x), sin(y), cos(z), etc. are abbreviated as sx, sy, cz,
etc.

TODO: It would probably be more efficient to define cx, cy, cz, sx, sy, sz and
use them in the calculations instead of a series of sin/cos operations. This
would let us reduce 23 trig operations to 6 trig operations.
*/

cx = cos(x);
cy = cos(y);
cz = cos(z);
sx = sin(x);
sy = sin(y);
sz = sin(z);

// Clear memory
x = y = z = [];

S1 = sx*sy; // Common terms, computed here to reduce computations
C1 = cz*cy; // later
SC1 = sz*cy;

A  =  C1 - sz*S1;          // Variables A-I make up the
B  = -sz*cx;               // aircraft rotations about
C  =  cz*sy + SC1*sx;      // Yaw, Pitch, and Roll
D  =  SC1 + cz*S1;
E  =  cz*cx;
F  =  sz*sy - C1*sx;
G  = -cx*sy;
H  =  sx;
I  =  cx*cy;

// Clear memory
S1 = C1 = SC1 = cx = cy = cz = sx = sy = sz = [];

/*
Let R be the above matrix consisting of A through I. In yorick:
   M = [[A,B,C],[D,E,F],[G,H,I]]

Let D be the delta distance vector from the GPS antenna to the mirror exit. In
yorick:
   D = [dx,dy,dz]

Let G be the GPS antenna coordinates. In yorick:
   G = [gx,gy,gz]

In order to calculate the mirror position, we apply our rotation matrix to our
displacement vector to convert it into real-world coordinates, then add it to
the gps position. In Yorick:
   mir = M(,+,) * D(+) + G(-,)

The next sequence of code should be equivalent to the above, but is broken up
into steps instead.

TODO: Replace the next chunk of code with the above code. This should not be
done unless the replacement is thoroughly tested to be absolutely, positively
certain that they are equivalent.
*/

// Preallocate mir; we'll fill in half now, and half later
mx = my = mz = array(double, dims);
mx = A*dx + B*dy + C*dz + gx;   // Calc. freespace mirror
my = D*dx + E*dy + F*dz + gy;   // position
mz = G*dx + H*dy + I*dz + gz;

// Clear memory
dx = dy = dz = gx = gy = gz = [];

// NOTE: mir contains the east/north/elev values stored in meast/mnorth/melev

// Convert additional angular values into radians.
la = lasang * DEG2RAD; // mounting angle of laser about x-axis
ma = mirang * DEG2RAD; // mounting angle of mirror about x-axis
ca = curang * DEG2RAD; // current angle of mirror rotating about y-axis
pa = cyaw * DEG2RAD;   // yaw angle (z) about laser/mirror chassis

// No longer need these variables, free some memory.
lasang = mirang = curang = cyaw = [];

// Create shortcuts for sin/cos of each of the above
cla  = cos(la);
sla  = sin(la);
cpa  = cos(pa);
spa  = sin(pa);
cca  = cos(ca);
sca  = sin(ca);
cma  = cos(ma);
sma  = sin(ma);

// No longer need these variables now either, free more memory.
la = pa = ca = ma = [];

/*
Here we compensate for rotation of the laser beam (the vector between the
mirror and the ground point).

Let x be the rotation about the x axis (refered to as la in the yorick code).
Let z be the rotation about the z axis (refered to as pa in the yorick code).
Our y axis is defined as the laser vector itself; thus, there is no rotation
about the y axis.

Let Rx be the rotation matrix about the x axis and Rz be the rotation matrix
about the z axis. Then Rx and Rz are:

        / cz -sz 0 \        / 1 0   0  \
   Rz = | sz  cz 0 |   Rx = | 0 cx -sx |
        \ 0   0  1 /        \ 0 sx  cx /

The composite rotation matrix R is thus:

                 / (cz) (-cx*sz) (sx*sz)  \
   R = Rz * Rx = | (sz) (cx*cz)  (-sx*cz) |
                 \ (0)  (sx)     (cx)     /

Our laser vector is coming in solely from the y direction, which can be
represented by a unit vector thus:

       /  0 \
   D = | -1 |
       \  0 /

Now, the above rotation matrix R is to transform from the laser beam's
inertial reference to the plane intertial reference. We then have to transform
from the plane's intertial reference to the real world's inertial reference.
Thus, we need the matrix defined by yorick variables A through I further up
above.

Let Rlp be the rotation matrix to transform from the laser to the plane. Let
Rpg be the rotation matrix to transform from the plane to the real world (gps).
Then to transform D into a real-world vector, we need to do the following:

                   / A B C \   / (cz) (-cx*sz) (sx*sz)  \   /  0 \
   Rpg * Rlp * D = | D E F | * | (sz) (cx*cz)  (-sx*cz) | * | -1 |
                   \ G H I /   \ (0)  (sx)     (cx)     /   \  0 /

                   / A B C \   / cx*sz \
                 = | D E F | * | -cx*cz  |
                   \ G H I /   \ -sx     /

                   / A*cx*sz + -B*cx*cz + -C*sx \
                 = | D*cx*sz + -E*cx*cz + -F*sx |
                   \ G*cx*sz + -H*cx*cz + -I*sx /

                   / (A*sz - B*cz)*cx - C*sx \
                 = | (D*sz - E*cz)*cx - F*sx |
                   \ (G*sz - H*cz)*cx - I*sx /
*/

a = array(double, dims, 3); // x-axis
// Move incident vector with aircraft attitude and then rotate about z-axis
a(..,1) = (A*spa - B*cpa)*cla - C*sla;
a(..,2) = (D*spa - E*cpa)*cla - F*sla;
a(..,3) = (G*spa - H*cpa)*cla - I*sla;

// No longer need, clear memory
cla = sla = [];

/*
Rotation angles for the mirror
ma - angle about x (constant mounting angle)
ca - angle about y (varies with mirror oscillation)
pa - angle about z (constant mounting angle))
*/

/*
The matrix below (J-R) is constructed just like the earlier matrix (A-I) to
handle the 3 rotations needed for a planar mirror. Only the third column gets
used, so the other values are not created.
*/

//J = cpa*cca-spa*sma*sca;
//K = -spa*cma;
L = cpa*sca+spa*sma*cca;
//M = spa*cca+cpa*sma*sca;
//N = cpa*cma;
O = spa*sca-cpa*sma*cca;
//P = -cma*sca;
//Q = sma;
R = cma*cca;

// No longer need these, clear memory
cma = sma = cca = sca = cpa = spa = [];

/*
J-R rotates the mirror into the plane's vector space. A-I rotates the plane's
vector space into the real world's vector space. To rotate from mirror vector
space directly to real world vector space, the two need to get matrix
multiplied together.

  / A B C \   / J K L \
  | D E F | * | M N O |
  \ G H I /   \ P Q R /

We need to know what vector is normal to the plane of the mirror. The mirror
lies in the plane that contains the X and Y axes of its own vector space. So,
the Z axis is normal: <0,0,1>. Multiplying this by the rotations above yields a
vector that is normal in real world vector space. We call this vector "RM"
below.

        / A B C \   / J K L \   / 0 \
  RM  = | D E F | * | M N O | * | 0 |
        \ G H I /   \ P Q R /   \ 1 /

        / A B C \   / L \
      = | D E F | * | O |
        \ G H I /   \ R /

        / AL+BO+CR \
      = | DL+EO+FR |
        \ GL+HO+IR /
*/
RM = array(double, dims, 3);
RM(..,1) = A*L + B*O + C*R;
RM(..,2) = D*L + E*O + F*R;
RM(..,3) = G*L + H*O + I*R;

/*
Using:
  di - vector of incidence
  dn - vector of surface normal
  ds - vector of spectral reflection
Then:
  ds = 2(dn . di)dn - di
Where . stands for dot product.
*/

// Compute dot product between normal to mirror and incident vector
MM = RM(..,1)*a(..,1) + RM(..,2)*a(..,2) + RM(..,3)*a(..,3);

// Compute vector of spectral reflection
SR = array(double, dims, 3);
SR(..,1) = 2 * MM * RM(..,1) - a(..,1);
SR(..,2) = 2 * MM * RM(..,2) - a(..,2);
SR(..,3) = 2 * MM * RM(..,3) - a(..,3);

// Multiply spectral reflection unit vector by magnitude, then subtract from
// mirror to yield point location.
px = mx + mag * SR(..,1);
py = my + mag * SR(..,2);
pz = mz + mag * SR(..,3);
}
