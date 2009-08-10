func scanflatmirror1_direct_vector(yaw,pitch,roll,gx,gy,gz,dx,dy,dz,lasang,mirang,curang,mag)
{
/*---------------------------------------------------------------
  This function computes a vector (M) of xyz points projected
  in 3D space from the origin...which in this case is the
  center of rotation of planar mirror rotated about the y-axis.  
  The mirror will face the negative y-axis with a pitch angle of 
  -22.5 degrees. An incident vector intersects this mirror 45 degs.
  from vertical. The direction of this vector is positive going
  giving [0 mag 0] as our incident vector.
 
  yaw    - yaw angle (z) of aircraft
  pitch  - pitch angle (x) of aircraft
  roll   - roll angle (y) of aircraft
  gx     - GPS antenna x position
  gy     - GPS antenna y position
  gz     - GPS antenna z position
  dx     - delta x distance from GPS antenna to mirror exit
  dy     - delta y distance from GPS antenna to mirror exit
  dz     - delta z distance from GPS antenna to mirror exit
  lasang - mounting angle of laser about x-axis
  mirang - mounting angle of mirror about x-axis
  curang - current angle of mirror rotating about y-axis
  mag    - magnitude of vector in 'y' direction
 ---------------------------------------------------------------
  SAB			NASA			3/29/2000
 ---------------------------------------------------------------
*/

rad = pi/180;

z   = yaw*rad;				// Convert to radians
x   = pitch*rad;
y   = roll*rad;

S1  = sin(x)*sin(y);
C1  = cos(z)*cos(y);
SC1 = sin(z)*cos(y);

A  =  C1 - sin(z)*S1;			// Variables A-I make up the 
B  = -sin(z)*cos(x);			// aircraft rotations about 
C  =  cos(z)*sin(y) + SC1*sin(x);	// Yaw, Pitch, and Roll
D  =  SC1 + cos(z)*S1;
E  =  cos(z)*cos(x);
F  =  sin(z)*sin(y) - C1*sin(x);
G  = -cos(x)*sin(y);
H  =  sin(x);
I  =  cos(x)*cos(y);

m1  = A*dx + B*dy + C*dz + gx;		// Calc. freespace mirror
m2  = D*dx + E*dy + F*dz + gy;		// position
m3  = G*dx + H*dy + I*dz + gz;
mir = [m1,m2,m3];

la   = lasang*rad;			// Convert to radians
mi   = mirang*rad;
cu   = curang*rad;

c    = cos(la);
s    = sin(la);

a1   = (B*c+C*s)*mag;			// Move incident vector with
a2   = (E*c+F*s)*mag;			// aircraft attitude and then
a3   = (H*c+I*s)*mag; 			// rotate about x-axis
a    = [a1,a2,a3];

J    =  cos(cu);			// These matrix components
K    =  0;				// comprise the 2 rotations
L    =  sin(cu);			// needed for a planar mirror
M    =  sin(mi)*sin(cu);
N    =  cos(mi);
O    = -sin(mi)*cos(cu);
P    = -cos(mi)*sin(cu);
Q    =  sin(mi);
R    =  cos(mi)*cos(cu);

r11  = A*J + B*M + C*P;			// X-axis attitude after all
r12  = D*J + E*M + F*P;			// rotations
r13  = G*J + H*M + I*P;
R1   = [r11,r12,r13];

r21  = A*K + B*N + C*Q;			// Y-axis attitude after all
r22  = D*K + E*N + F*Q;			// rotations
r23  = G*K + H*N + I*Q;
R2   = [r21,r22,r23];
					
rm1  = R1(,2)*R2(,3) - R1(,3)*R2(,2);	// Compute cross product of R1
rm2  = R1(,3)*R2(,1) - R1(,1)*R2(,3);       // and R2 to find normal (RM)        
rm3  = R1(,1)*R2(,2) - R1(,2)*R2(,1);
RM   = [rm1,rm2,rm3];
					// Compute inner product
MM   = RM(,1)*a(,1) + RM(,2)*a(,2) + RM(,3)*a(,3);

mx   = a(,1) - 2*MM*RM(,1) + mir(,1);	// Compute reflected vector
my   = a(,2) - 2*MM*RM(,2) + mir(,2);   // x,y,z position
mz   = a(,3) - 2*MM*RM(,3) + mir(,3);
M    = [mx,my,mz];

return M;  
}
