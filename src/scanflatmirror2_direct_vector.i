write, "$Id$";

/*
   Modified 2008-12-05 David Nagle:
      I have gone through and added a lot of documentation to explain (as best
      I can) what is being done and why. No functionality has been altered.
      I've only added documentation.
*/

func scanflatmirror2_direct_vector(yaw, pitch, roll, gx, gy, gz, dx, dy, dz, cyaw, lasang, mirang, curang, mag)
{
/* DOCUMENT scanflatmirror2_direct_vector(yaw, pitch, roll, gx, gy, gz, dx, dy,
   dz, cyaw, lasang, mirang, curang, mag)

   This function computes a vector (M) of xyz points projected in 3D space from
   the origin...which in this case is the center of rotation of planar mirror
   rotated about the y-axis.  The mirror will face the negative y-axis with a
   pitch angle of -22.5 degrees. An incident vector intersects this mirror 45
   degs.  from vertical. The direction of this vector is positive going giving
   [0 mag 0] as our incident vector.

   In the 'incident vector' above, 'mag' is the distance from the mirror to the
   ground point.
 
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

   Return array is as follows (all values are in centimeters)
   m(,1) = mirror east
   m(,2) = mirror north
   m(,3) = mirror elevation
   m(,4) = ground point east
   m(,5) = ground point north
   m(,6) = ground point elevation
   ---------------------------------------------------------------
   SAB			NASA			8/11/2000
   ---------------------------------------------------------------
*/

// Factor for converting degrees to radians
rad = pi/180;

// Convert the yaw, pitch, roll into radians. We name the variables z, x, y
// because these are the rotations about those axes.
z   = yaw*rad;
x   = pitch*rad;
y   = roll*rad;

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

S1  = sin(x)*sin(y); // Common terms, computed here to reduce computations
C1  = cos(z)*cos(y); // later
SC1 = sin(z)*cos(y);

A  =  C1 - sin(z)*S1;             // Variables A-I make up the 
B  = -sin(z)*cos(x);              // aircraft rotations about 
C  =  cos(z)*sin(y) + SC1*sin(x); // Yaw, Pitch, and Roll
D  =  SC1 + cos(z)*S1;
E  =  cos(z)*cos(x);
F  =  sin(z)*sin(y) - C1*sin(x);
G  = -cos(x)*sin(y);
H  =  sin(x);
I  =  cos(x)*cos(y);

/*
Let R be the above matrix consisting of A through I. In yorick:
   M = [[A,B,C],[D,E,F],[G,H,I]]

Let D be the delta distance vector from the GPS antenna to the mirror exit. In yorick:
   D = [dx,dy,dz]

Let G be the GPS antenna coordinates. In yorick:
   G = [gx,gy,gz]

In order to calculate the mirror position, we apply our rotation matrix to our
displacement vector to convert it into real-world coordinates, then add it to
the gps position. In Yorick:
   mir = M(,+,) * D(+) + G(-,)

The next sequence of code should be equivalent to the above, but is broken up into steps instead.

TODO: Replace the next chunk of code with the above code. This should not be
done unless the replacement is thoroughly tested to be absolutely, positively
certain that they are equivalent.
*/

m1  = A*dx + B*dy + C*dz + gx;		// Calc. freespace mirror
m2  = D*dx + E*dy + F*dz + gy;		// position
m3  = G*dx + H*dy + I*dz + gz;
mir = [m1,m2,m3];

// NOTE: mir contains the east/north/elev values stored in meast/mnorth/melev

// Convert additional angular values into radians.
la   = lasang*rad; // mounting angle of laser about x-axis
ma   = mirang*rad; // mounting angle of mirror about x-axis
ca   = curang*rad; // current angle of mirror rotating about y-axis
pa   = cyaw*rad;   // yaw angle (z) about laser/mirror chassis

// Create shortcuts for sin/cos of each of the above
cla  = cos(la);
sla  = sin(la);
cpa  = cos(pa);
spa  = sin(pa);
cca  = cos(ca);
sca  = sin(ca);
cma  = cos(ma);
sma  = sin(ma);

/*
Here we compensate for rotation of the laser beam (the vector between the
mirror and the ground point).

Let x be the rotation about the x axis (refered to as la in the yorick code).
Let z be the rotation about the z axis (refered to as pa in the yorick code).
Our y axis is defined as the laser vector itself; thus, there is no rotation
about the y axis.

Let Rx be the rotation matrix about the x axis and Rz be the rotation matrix
about the z axis. Then Rx and Rz are:

        / 1 0   0  \        / cz -sz 0 \
   Rx = | 0 cx -sx |   Rz = | sz  cz 0 |
        \ 0 sx  cx /        \ 0   0  1 /

The composite rotation matrix R is thus:

                 / (cz)      (sz)    (0)  \
   R = Rx * Rz = | (-cx*sz) (cx*cz)  (sz) |
                 \ (sx*sz)  (-sx*cz) (cx) /

Our laser vector is defined solely by a magnitude in the y direction. This
magitude is represented in yorick as the variable 'mag'. If we call our laser
distance vector D, then:

       /  0  \
   D = | mag |
       \  0  /

Now, the above rotation matrix R is to transform from the laser beam's
inertial reference to the plane intertial reference. We then have to transform
from the plane's intertial reference to the real world's inertial reference.
Thus, we need the matrix defined by yorick variables A through I further up
above.

Let Rlp be the rotation matrix to transform from the laser to the plane. Let
Rpg be the rotation matrix to transform from the plane to the real world (gps).
Then to transform D into a real-world displacement vector, we need to do the
following:

                   / A B C \   / (cz)      (sz)    (0)  \   /  0  \
   Rpg * Rlp * D = | D E F | * | (-cx*sz) (cx*cz)  (sz) | * | mag | 
                   \ G H I /   \ (sx*sz)  (-sx*cz) (cx) /   \  0  /

                   / A B C \   / (sz * mag)       \
                 = | D E F | * | (cx * cz * mag)  |
                   \ G H I /   \ (-sx * cz * mag) /

It appears that the vector 'a' defined below is the second row of the above
matrix, multiplied by the magnitude vector in the 'y' direction.

The maginitude vector is [0,mag,0]. We omit the first and third rows because
they'll always be zero.

The magnitude vector is a coordinate in "mirror space". This converts it to a
coordinate in plane space. -- ?
*/

// mag is the magnitude of the vector in the y direction
a1 = ((-A*spa+B*cpa)*cla+C*sla)*mag;	// Move incident vector with
a2 = ((-D*spa+E*cpa)*cla+F*sla)*mag;	// aircraft attitude and then
a3 = ((-G*spa+H*cpa)*cla+I*sla)*mag; 	// rotate about z-axis, then
a  = [a1,a2,a3];			// x-axis

/*
Rotation angles for the mirror
ma - angle about x (constant mounting angle)
ca - angle about y (varies with mirror oscillation)
pa - angle about z (constant mounting angle))
*/

// Following needs to be documented yet

J  =  cpa*cca-spa*sma*sca;		// These matrix components
K  =  -spa*cma;				// comprise the 3 rotations
L  =  cpa*sca+spa*sma*cca;		// needed for a planar mirror
M  =  spa*cca+cpa*sma*sca;
N  =  cpa*cma;
O  =  spa*sca-cpa*sma*cca;
P  =  -cma*sca;
Q  =  sma;
R  =  cma*cca;

/*

A B C    J K L  
D E F    M N O
G H I    P Q R

Following is just matrix multiplication between the above matrices?

*/

r11  = A*J + B*M + C*P;			// X-axis attitude after all
r12  = D*J + E*M + F*P;			// rotations
r13  = G*J + H*M + I*P;
R1   = [r11,r12,r13];

r21  = A*K + B*N + C*Q;			// Y-axis attitude after all
r22  = D*K + E*N + F*Q;			// rotations
r23  = G*K + H*N + I*Q;
R2   = [r21,r22,r23];

// Following needs to be documented yet
					
rm1  = R1(,2)*R2(,3) - R1(,3)*R2(,2);	// Compute cross product of R1
rm2  = R1(,3)*R2(,1) - R1(,1)*R2(,3);       // and R2 to find normal (RM)        
rm3  = R1(,1)*R2(,2) - R1(,2)*R2(,1);
RM   = [rm1,rm2,rm3];
					// Compute inner product
MM   = RM(,1)*a(,1) + RM(,2)*a(,2) + RM(,3)*a(,3);

mx   = a(,1) - 2*MM*RM(,1) + mir(,1);	// Compute reflected vector
my   = a(,2) - 2*MM*RM(,2) + mir(,2);   // x,y,z position
mz   = a(,3) - 2*MM*RM(,3) + mir(,3);
M    = [mir(,1), mir(,2), mir(,3), mx,my,mz];

return M;  
}
