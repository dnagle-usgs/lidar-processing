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

//=================================================
// For N111x. Calibrated using 3/14/2006
// Ocean Springs, Ms. runway passes.
//=================================================
ms4000_cir_bias_n111x = CAMERA_MOUNTING_BIAS();
ms4000_cir_bias_n111x.name    = "n111x ms4000 cir";
// Measurements taken by Richard Mitchell 2008-11-13:
// 31 cm from the top of the camera UP to the midpoint of the IMU
// 18 cm from the middle of the camera BACK to the middle of the mirror
// 17 cm from the middle of the camera LEFT to the midpoint of the IMU
// The camera body is ~16cm tall, with the lens on the opposite end of the
// measurements
ms4000_cir_bias_n111x.x = -0.180;
ms4000_cir_bias_n111x.y =  0.170;
ms4000_cir_bias_n111x.z =  0.310;
// Experimentally derived
ms4000_cir_bias_n111x.pitch   =  1.655;
ms4000_cir_bias_n111x.roll    = -0.296;
ms4000_cir_bias_n111x.heading =  0.0;

//=================================================
// For N48rf calibrated using 4/11/2006 KSPG
//=================================================
ms4000_cir_bias_n48rf = CAMERA_MOUNTING_BIAS();
ms4000_cir_bias_n48rf.name = "n48rf ms4000 cir";
ms4000_cir_bias_n48rf.pitch  = -0.10 + 0.03 + 0.5 -0.5;
ms4000_cir_bias_n48rf.roll   = 0.50 - .28 + 0.03 + 0.75 - 0.14 -0.7;
ms4000_cir_bias_n48rf.heading= 0.375 - 0.156 + 0.1;

//=================================================
// N5308F with Span/CPT: measurements from camera to IMU
//=================================================
ms4000_cir_bias_n5308f = CAMERA_MOUNTING_BIAS();
ms4000_cir_bias_n5308f.name    = "n5308f ms4000 cir";
ms4000_cir_bias_n5308f.x = -0.050;   // toward cockpit
ms4000_cir_bias_n5308f.y =  0.120;   // toward right wing
ms4000_cir_bias_n5308f.z =  0.760;   // Up

//=================================================
// RGB on n111x, offsets calculated from CIR
//=================================================
ge2040c_rgb_bias_n5308f = CAMERA_MOUNTING_BIAS();
ge2040c_rgb_bias_n5308f.name = "n5308f ge2040c rgb";
ge2040c_rgb_bias_n5308f.x = 0.000;
ge2040c_rgb_bias_n5308f.y = 0.220;
ge2040c_rgb_bias_n5308f.z = 0.760;

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
// MS4000 info (CIR)
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

///////////////////////////////////////////
// Prosilica GE2040C info
///////////////////////////////////////////
// http://www.1stvision.com/cameras/sensor_specs/KAI-4021LongSpec.pdf
ge2040c_specs = CAMERA_SPECS();
ge2040c_specs.name = "ge2040c";
ge2040c_specs.focal_length = 0.018;
ge2040c_specs.ccd_x = 0.01667;
ge2040c_specs.ccd_y = 0.01605;
ge2040c_specs.ccd_xy = 7.4e-6;
ge2040c_specs.trigger_delay = 0.;
ge2040c_specs.sensor_width = 2048;
ge2040c_specs.sensor_height = 2048;
ge2040c_specs.pix_x = 7.4e-6; // 7.4 micron
ge2040c_specs.pix_y = 7.4e-6; // 7.4 micron

// Defaults for CIR imagery
camera_specs = ms4000_specs;
camera_mounting_bias = ms4000_cir_bias_n111x;
