# UART_TX_RX_User_Defined_Packet

The verilog files found under the RatbotBrain/src directory can be used with any FPGA that has the required resources.
This design uses the Mojo Development platform. The Mojo has a Xilinx Spartan-6 xc6slx9-2tqg144 FPGA. The Spartan-6
is only available for synthesizing, place & route and bit file creation via the no longer supported Xilinx ISE design tool.
Thus, we used the Xilinx ISE 14.7 Webpack.

The RatbotBrain code, as is, simply interfaces to a serial interface, such as found on an Arduino board. The idea is to 
transfer data between the Arduino and the FPGA in user defined packet format. Check the "FPGA Design Diagram.pdf" in this repository
for additional information. This code as is stands can be used for any application where you wish to send data back and forth for processing
between an FPGA and a serial source processor.

The Arduino C/C++ code has been uploaded (SoftwareSerialUnoToFPGA) and should work for wrap around testing, if I remember correctly. I need to go back and clean it up and add comments!!

More details to come ...
