/*
  Software serial multple serial test

 Receives from the hardware serial, sends to software serial.
 Receives from software serial, sends to hardware serial.

 The circuit:
 * RX is digital pin 10 (connect to TX of other device)
 * TX is digital pin 11 (connect to RX of other device)

 Note:
 Not all pins on the Mega and Mega 2560 support change interrupts,
 so only the following can be used for RX:
 10, 11, 12, 13, 50, 51, 52, 53, 62, 63, 64, 65, 66, 67, 68, 69

 */
 
#include <SoftwareSerial.h>

#define TX_FRAME_HEADER 0xA5
#define RX_FRAME_HEADER 0x96 
#define RE_TX_CMD_HDR   0xCE
#define RE_TX_RESP_HDR  0xEE

#define MEGA2560 1

#ifndef MEGA2560
SoftwareSerial SerialToFPGA(8, 9); // RX, TX  //Serial interface to FPGA
#endif


byte tx_buffer[] = {TX_FRAME_HEADER,0x30,0x34,0x12,0x67,0x45,0x32,0x00,0x99};
byte rx_buffer[] = {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
//byte tx_buffer[] = {0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30};
byte parity = 0x00;
byte rx_parity = 0x00;
byte inByte = 0x00;
int bytesSent = 0;

void setup() {
  // Open serial communications and wait for port to open:
  Serial.begin(115200);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }


  Serial.println("Arduino-FPGA UART Loop Test.");

  
  // set the data rate for the SoftwareSerial port
  #ifdef MEGA2560
  Serial1.begin(115200);
  #else
  SerialToFPGA.begin(115200);
  #endif

  #ifdef MEGA2560
  while (!Serial1) {
    ; // wait for serial port to connect. Needed for native USB port only
  }
  #else
  while (!SerialToFPGA) {
    ; // wait for serial port to connect. Needed for native USB port only
  }
  #endif
  
  //SerialToFPGA.write(tx_buffer,sizeof(tx_buffer));
  
  //if (SerialToFPGA.available()) {
    //int bytesSent = SerialToFPGA.write(tx_buffer,sizeof(tx_buffer));//Serial.write(SerialToFPGA.read());
    //Serial.print("Wrote Data to FPGA. Number of Bytes Sent = ");
    //Serial.println(bytesSent);
  //}

  
  //for(int i = 0; i < 8; i=i+1) 
  //  SerialToFPGA.write(tx_buffer[i]);
   
  parity = calcParity(tx_buffer,(sizeof(tx_buffer)-1));
  tx_buffer[(sizeof(tx_buffer)-1)] = parity;

  Serial.print("Calculated Parity = ");
  for(int i=7; i>=0; i--)
      Serial.print((parity>>i)& 0x01);
  Serial.println();
}

void loop() { // run over and over
  /*
  while (SerialToFPGA.available()) {
    int in = (byte)SerialToFPGA.read();
    byte inByte = (byte) in & 0xff;
    for(int i=7; i>=0; i--)
      Serial.print((inByte>>i)& 0x01);
    //Serial.write(SerialToFPGA.read());
    //Serial.println("SerialToFPGA.available()");
    Serial.println();
    if(inByte == RX_FRAME_HEADER)
      Serial.println("RX_FRAME_HEADER Received!");
  }
  */

  int totalMatches = 0;
  int totalParityErrors  = 0;
  int totalResendCmds = 0;
  int totalResendResp = 0;
  int requestResend = 0;
  
  for(int j=0;j<1000;j++) {
    int i = 0;
    int numSame = 0;
    int byteMismatch = 0;
    bytesSent = 0;
    zeroOutRxBuffer();

    if (requestResend == 0)
      //Tx Packet: Opcode & Data
      #ifdef MEGA2560
      bytesSent = Serial1.write(tx_buffer,sizeof(tx_buffer));
      #else
      bytesSent = SerialToFPGA.write(tx_buffer,sizeof(tx_buffer));
      #endif
      
    else {
      #ifdef MEGA2560
      Serial1.write(RE_TX_RESP_HDR);
      #else
      SerialToFPGA.write(RE_TX_RESP_HDR);
      #endif
      
      requestResend = 0;
      totalResendResp++;
      Serial.println("Sending RE_TX_RESP_HDR Byte to FPGA.");
    }
    //Serial.print("Wrote Data to FPGA. Number of Bytes Sent = ");
    //Serial.println(bytesSent);

    #ifdef MEGA2560
    while (Serial1.available()) {
    #else
    while (SerialToFPGA.available()) {
    #endif

      #ifdef MEGA2560
      int in = (byte)Serial1.read();
      #else
      int in = (byte)SerialToFPGA.read();
      #endif
      inByte = (byte) in & 0xff;
      rx_buffer[i] = inByte;
      if(inByte == RX_FRAME_HEADER) {
        Serial.println("RX_FRAME_HEADER Received!");
        i = 1;
        numSame++;
      }
      else if(inByte == RE_TX_CMD_HDR) {
        Serial.println("TX Error Detected by FPGA:  RE_TX_CMD_HDR");
        i++;
        numSame++;
        totalResendCmds++;
      }
      else { 
        if(inByte == tx_buffer[i]) {
          i++;
          numSame++;
        }
        else
          byteMismatch = 1;
      }
      
    }
    
    rx_parity = calcParity(rx_buffer,(sizeof(rx_buffer)-1));
    
    if (byteMismatch == 1) {
      Serial.println("Packet Mismatch Detected");
      totalMatches++;
    }
    if (rx_parity != inByte) {
      Serial.println("Parity Error Detected");
      totalParityErrors++;
      requestResend = 1;
    }
    
    //SerialToFPGA.write(10);
    delay(500);
   
  }

  Serial.print("Total Packet Mismatch Detected = ");
  Serial.println(totalMatches);
  Serial.print("Total Parity RX Errors = ");
  Serial.println(totalParityErrors);
  Serial.print("Total Number of Resend Response Sent = ");
  Serial.println(totalResendResp);
  Serial.print("Total Number of Resend Cmds Received = ");
  Serial.println(totalResendCmds);
  
  

  while(1) {};
  

  //delay(1000);
  //int bytesSent = SerialToFPGA.write(tx_buffer,sizeof(tx_buffer));//Serial.write(SerialToFPGA.read());
}

byte calcParity(byte buff[],int numBytes) {
  byte parity = 0x00;
  byte parityBit = 0x00;

  for(int i=2; i<numBytes; i++) {
    parityBit = (buff[i]>>7)^((buff[i]>>6)&0x01)^((buff[i]>>5)&0x01)^((buff[i]>>4)&0x01)^
                ((buff[i]>>3)&0x01)^((buff[i]>>2)&0x01)^((buff[i]>>1)&0x01)^(buff[i]&0x01);
    parity = parity | parityBit<<(i-2);
  }

  return parity;
}

void zeroOutRxBuffer() {
  int numBytes = sizeof(rx_buffer);

  for(int i=0; i<numBytes; i++)
    rx_buffer[i] = 0x00;
}
/*

void sendIntToFPGA(int num) {
  int numBytesWritten = 0;

  SerialToFPGA.write(num & 255);
  SerialToFPGA.write(((num>>8) & 255);
}
*/
