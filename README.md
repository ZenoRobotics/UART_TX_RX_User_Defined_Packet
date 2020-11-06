# UART_TX_RX_User_Defined_Packet

The verilog files found under the RatbotBrain/src directory can be used with any FPGA that has the required resources.
This design uses the Mojo Development platform. The Mojo has a Xilinx Spartan-6 xc6slx9-2tqg144 FPGA. The Spartan-6
is only available for synthesizing, place & route and bit file creation via the no longer supported Xilinx ISE design tool.
Thus, we used the Xilinx ISE 14.7 Webpack.

The RatbotBrain code, as is, simply interfaces to a serial interface, such as found on an Arduino board. The idea is to 
transfer data between the Arduono and the FPGA in user defined packet format. Check the "FPGA Design Diagram.pdf" in this repository
for additional information. 

More details to come ...
