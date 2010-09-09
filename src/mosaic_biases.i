/*
   Biases, offsets, calibration settings, and specifications for the cameras
   and equipment used for various forms of imagery. These settings are used by
   mosaic_tools.i.
*/

// Camera mounting bias values.
struct CAMERA_MOUNTING_BIAS {
   string name;   // Aircraft id (N-Number).
   float pitch;   // +nose up
   float roll;    // +cw (roll to the right)
   float heading; // +cw (right turn)
   float x;       // Offset from Camera to IMU along the fuselage toward the nose
   float y;       // Offset across the fueslage, positive toward the right wing
   float z;       // Offset +up
}

cir_mounting_bias_n111x = CAMERA_MOUNTING_BIAS();
cir_mounting_bias_n5308f = CAMERA_MOUNTING_BIAS();
cir_mounting_bias_n48rf = CAMERA_MOUNTING_BIAS();

//=================================================
// For N111x. Calibrated using 3/14/2006
// Ocean Springs, Ms. runway passes.
//=================================================
cir_mounting_bias_n111x.name    = "n111x";
cir_mounting_bias_n111x.pitch   =  1.655;
cir_mounting_bias_n111x.roll    = -0.296;
cir_mounting_bias_n111x.heading =  0.0;
// Measurements taken by Richard Mitchell 2008-11-13:
// 31 cm from the top of the camera UP to the midpoint of the IMU
// 18 cm from the middle of the camera BACK to the middle of the mirror
// 17 cm from the middle of the camera LEFT to the midpoint of the IMU
// The camera body is ~16cm tall, with the lens on the opposite end of the
// measurements
cir_mounting_bias_n111x.x = -0.180;
cir_mounting_bias_n111x.y =  0.170;
cir_mounting_bias_n111x.z =  0.310;
//=================================================
// N5308F with Span/CPT: measurements from IMU to camera
//=================================================
cir_mounting_bias_n5308f.name    = "n5308f";
cir_mounting_bias_n5308f.pitch   =  0.000;
cir_mounting_bias_n5308f.roll    =  0.000;
cir_mounting_bias_n5308f.heading =  0.0;

cir_mounting_bias_n5308f.x = -0.120;   // toward right wing
cir_mounting_bias_n5308f.y =  0.050;   // toward cockpit
cir_mounting_bias_n5308f.z = -0.760;   // Up


//=================================================
// For N48rf calibrated using 4/11/2006 KSPG
//=================================================
cir_mounting_bias_n48rf.name = "n48rf";
cir_mounting_bias_n48rf.pitch  = -0.10 + 0.03 + 0.5 -0.5;    // Now, set the bias values.
cir_mounting_bias_n48rf.roll   = 0.50 - .28 + 0.03 + 0.75 - 0.14 -0.7;
cir_mounting_bias_n48rf.heading= 0.375 - 0.156 + 0.1;


//=================================================
// Camera specifications.
//=================================================
struct CAMERA_SPECS {
  string name;          // Camera name;
  double focal_length;  // focal length in meters
  double ccd_x;         // detector x dim in meters.  Along fuselage.
  double ccd_y;         // detector y dim in meters.  Across the fuselage.;
  double ccd_xy;        // Detector pixel size in meters.
  double trigger_delay; // Time from trigger to photo capture in seconds.
  double sensor_width;  // width of sensor in pixels
  double sensor_height; // height of sensor in pixels
  double pix_x;         // pixel size on sensor in meters
  double pix_y;         // pixel size on sensor in meters
}

///////////////////////////////////////////
// MS4000 info
///////////////////////////////////////////
ms4000_specs = CAMERA_SPECS();
ms4000_specs.name = "ms4000";
ms4000_specs.focal_length = 0.01325;
ms4000_specs.ccd_x = 0.00888;
ms4000_specs.ccd_y = 0.01184;
ms4000_specs.ccd_xy = 7.40e-6 * 1.02;
ms4000_specs.trigger_delay = 0.120;
ms4000_specs.sensor_width = 1600;
ms4000_specs.sensor_height = 1199;
ms4000_specs.pix_x = 7.4e-6; // 7.4 micron
ms4000_specs.pix_y = 7.4e-6; // 7.4 micron


// Defaults for CIR imagery
camera_specs = ms4000_specs;
camera_mounting_bias = cir_mounting_bias_n111x;
