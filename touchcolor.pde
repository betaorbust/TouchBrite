#include <TouchScreen.h>
// TouchColor
// This should 


// ---- Pin setup on the ShiftBrite ----
int datapin  = 13;  // DI
int latchpin = 12;  // LI
int enablepin = 11; // EI
int clockpin = 10;  // CI

// ---- Limits on the touch sensor range --
// These should reflect whatever sensor you're using. 
// The one I was doing dev work with was... not perfect.
int lims[4]={140,870,180,880}; 
int scale[2]={lims[1]-lims[0], lims[3]-lims[2]}; // Just some scale precalcs. Nothing to worry about.
 
// ---- Inits for the color commands ----
long rgb[3];
unsigned long SB_CommandPacket;
int SB_CommandMode;
int SB_BlueCommand;
int SB_RedCommand;
int SB_GreenCommand;

// ---- Touchscreen init stuff -----
int coords[2];
TouchScreen ts(3, 1, 0, 2); // Make a new touch screen object

// ---- Delay constants ----
int LoopDelay = 10; // How much to delay the main loop
int LatchDelay = 3; // How much to delay the latching. Longer for longer chains.


// ---- SETUP ----
void setup() {
  // Set up pin modes for the ShiftBrite
  pinMode(datapin, OUTPUT);
  pinMode(latchpin, OUTPUT);
  pinMode(enablepin, OUTPUT);
  pinMode(clockpin, OUTPUT);
  // Drop everything to low
  digitalWrite(latchpin, LOW);
  digitalWrite(enablepin, LOW);
  
  Serial.begin(38400); // Was debugging with serial so I left this in.
  
  SB_CommandMode = B01; // Write to current control registers
  SB_RedCommand = 127; // Full current
  SB_GreenCommand = 127; // Full current
  SB_BlueCommand = 127; // Full current
  SB_SendPacket();
}


// ---- Main Loop ----
void loop() {
  
  
  ts.read(coords); // Get touchscreen coordinates
  
  if(coords[0]<lims[1] && coords[1]<lims[3]){ // Thresholding for touch activity
    
    // Detect out of range values and trim them.
    if(coords[0]>lims[1]){coords[0]=lims[1];}
    if(coords[1]>lims[3]){coords[1]=lims[3];}
    if(coords[0]<lims[0]){coords[0]=lims[0];}
    if(coords[1]<lims[2]){coords[1]=lims[2];}
    
    // Scale the coords to match 1023 resolution
    coords[0]=int(1023.0*(coords[0]-lims[0])/scale[0]);
    coords[1]=int(1023.0*(coords[1]-lims[2])/scale[1]);

    float floatcoords[2]={float(coords[0]),float(coords[1])}; //cheap type conversion.
    
    long rgbval = HSV_to_RGB(6*floatcoords[0]/1023,1,floatcoords[1]/1023); // Get RGB from coords via HV
    //long rgbval = HSV_to_RGB(6*floatcoords[0]/1023,floatcoords[1]/1023,.1); // Get RGB from coords via HS
    
    // Shifting out the returns
    rgb[0] = (rgbval & 0x00FF0000) >> 16; // there must be better ways
    rgb[1] = (rgbval & 0x0000FF00) >> 8;
    rgb[2] = rgbval & 0x000000FF;
    
    // Make up the ShiftBrite command package
    SB_CommandMode = B00; // Write to PWM control registers
    SB_RedCommand = rgb[0];
    SB_GreenCommand = rgb[1];
    SB_BlueCommand = rgb[2]; 
    SB_SendPacket();
    
    // Debugging Serial output
    Serial.print(coords[0]);
    Serial.print(",");
    Serial.print(coords[1]);
    Serial.print(",");
    Serial.print(rgb[0]);
    Serial.print(",");
    Serial.print(rgb[1]);
    Serial.print(",");
    Serial.println(rgb[2]);
  }
    
  // Loop delay
   delay(1000);
}



// ---- Sending a color command down the line ----
void SB_SendPacket() {
  // Make up the command packet
  SB_CommandPacket = SB_CommandMode & B11;
  SB_CommandPacket = (SB_CommandPacket << 10)  | (SB_BlueCommand & 1023);
  SB_CommandPacket = (SB_CommandPacket << 10)  | (SB_RedCommand & 1023);
  SB_CommandPacket = (SB_CommandPacket << 10)  | (SB_GreenCommand & 1023);
  
  // Shift out the command packet 
  shiftOut(datapin, clockpin, MSBFIRST, SB_CommandPacket >> 24);
  shiftOut(datapin, clockpin, MSBFIRST, SB_CommandPacket >> 16);
  shiftOut(datapin, clockpin, MSBFIRST, SB_CommandPacket >> 8);
  shiftOut(datapin, clockpin, MSBFIRST, SB_CommandPacket);
  
  // Latch the result
  delay(LatchDelay); // adjustment may be necessary depending on chain length
  digitalWrite(latchpin,HIGH); // latch data into registers
  delay(LatchDelay); // adjustment may be necessary depending on chain length
  digitalWrite(latchpin,LOW);
}



// ---- Converting HSV to 256 based RGB color
long HSV_to_RGB( float h, float s, float v ) {
  // Inits
  int i;
  float m, n, f;

  // Return black for out of range S or V
  if ((s<0.0) || (s>1.0) || (v<0.0) || (v>1.0)) {
    return 0L;
  }
  
  // Return values of white for out of range H
  if ((h < 0.0) || (h > 6.0)) {
    return long( v * 255 ) + long( v * 255 ) * 256 + long( v * 255 ) * 65536;
  }
  
  // Calculate RBG from HSV
  i = floor(h);
  f = h - i;
  if ( !(i&1) ) {
    f = 1 - f; // if i is even
  }
  m = v * (1 - s);
  n = v * (1 - s * f);
  switch (i) {
  case 6:
  case 0: // RETURN_RGB(v, n, m)
    return long(v * 255 ) * 65536 + long( n * 255 ) * 256 + long( m * 255);
  case 1: // RETURN_RGB(n, v, m) 
    return long(n * 255 ) * 65536 + long( v * 255 ) * 256 + long( m * 255);
  case 2:  // RETURN_RGB(m, v, n)
    return long(m * 255 ) * 65536 + long( v * 255 ) * 256 + long( n * 255);
  case 3:  // RETURN_RGB(m, n, v)
    return long(m * 255 ) * 65536 + long( n * 255 ) * 256 + long( v * 255);
  case 4:  // RETURN_RGB(n, m, v)
    return long(n * 255 ) * 65536 + long( m * 255 ) * 256 + long( v * 255);
  case 5:  // RETURN_RGB(v, m, n)
    return long(v * 255 ) * 65536 + long( m * 255 ) * 256 + long( n * 255);
  }
} 
