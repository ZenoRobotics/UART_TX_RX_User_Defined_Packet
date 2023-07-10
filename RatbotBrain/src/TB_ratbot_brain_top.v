`timescale 1ns / 10ps
//*  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *
//*  *                 Verilog Source Code                                *  *
//*  *                                                                    *  *
//*  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *
//*  Title              :     Testbench For mojo_top - Ratbot brain inspired 
//*                     :     navigation system
//*  Filename and Ext   :     TB_ratbot_brain_top.v
//*  Submodules         :     N/A
//*  Company            :     PhD Dissertation Project
//*  Engineer           :     Peter J. Zeno 
//*  Created            :     December 14, 2016
//*  Mod History        :
//* *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  * 
`define a   assign                                       
`define r   always @ (posedge sys_clk)                       
`define ra  always @ (posedge sys_clk or posedge RST)                                   
`define GSR_SIGNAL  test.GSR 
`define SIMULATION 1 
 

module TB_ratbot_brain_top ;

  // parameters
  //
  //   note: the desired clock is 50MHz, so the period is 
  //
  //            T = 1/f = 20 ns
  //
  //         and the timescale is 1 ns, so the period is:
  //
  parameter  HALF_SYS_CLK_PERIOD   = 10;  
  parameter  CLK_RATE              = 50000000;
  parameter  SERIAL_BAUD_RATE      = 115200;
  parameter  CLK_PER_BIT = $rtoi($ceil(CLK_RATE/SERIAL_BAUD_RATE));
  parameter  NS_PER_BIT  = 8680; //$rtoi($ceil(CLK_PER_BIT/(2*HALF_SYS_CLK_PERIOD)));
    
      
  // Nets and Regs
  // input pin signals
  reg          sys_clk;
  wire         RST;
  reg          RSTn;  
  
  
  // testbench regs and wires
  reg          r_rx = 1'b1;
  wire         r_tx;
  reg    [7:0] r_rx_data_byte = 8'h00;
  integer      loop_cnt  = 0;
  reg    [3:0] r_rx_word_cnt = 4'h0;
  reg          send_byte = 1'b0;
  reg          avr_tx_rdy = 1'b1;
  integer      i = 0;
  
  // packet info
  parameter FRAME_HDR  = 8'b10100101; // hA5
  
  //Input File Handle
  integer      f_rx_in; //AVR_TX_FILE	
  
  //file read status
  integer      statusI = 0;
  
  // for unisim prims?
  reg          GSR;
//  glbl            glbl();
  

  // top module instatiation
  mojo_top  mojo_top_inst     
  (   
    // 50MHz clock input
    .clk(sys_clk),  
    // Input from reset button (active low)
    .rst_n(RSTn),
    // cclk input from AVR, high when AVR is ready
    .cclk(1'b1),
    // Outputs to the 8 onboard LEDs
    .led(),
    // AVR SPI connections
    .spi_miso(),
    .spi_ss(1'b0),
    .spi_mosi(1'b0),
    .spi_sck(1'b0),
    // AVR ADC channel select
    .spi_channel(),
    // Serial connections
    .avr_tx(r_rx),    // AVR Tx => FPGA Rx  // input
    .avr_rx(r_tx),    // AVR Rx => FPGA Tx  // output
    .avr_rx_busy()    // AVR Rx buffer full // output
  );	
	
 
 
  /////////////////////////////////////////////////////////////////
  // clock generators and system resets
  //
  //   note: a 50% duty cycle is desired so the clock
  //         period is divided by 2
  /////////////////////////////////////////////////////////////////
  initial begin  
	 
     sys_clk   =   1'b0;
	  #50;  
     RSTn      =   1'b0;
     #50;             
     RSTn      =   1'b1;
     #10;
    //$stop;
  end
  
  always
    #(HALF_SYS_CLK_PERIOD) sys_clk = ~sys_clk ;
	 
	 
  assign   RST = ~RSTn;
  ///////////////////////////////////////////////////////////////// 
  /////////////////////////////////////////////////////////////////
  
  //***********************************
  //*********  Simulation  ************
  //***********************************

  initial  begin
    send_byte = 1'b0;
    // open AVR tx file (FPGA rx)
    f_rx_in  = $fopen("AVR_TX_FILE.txt","r");
    @(posedge sys_clk);
	 
    wait (RST == 1'b1);
    wait (RST == 1'b0);
	 
    #200;     // is dumped
	 
	 //----------------------------------------------------
	 // Read in AVR Rx Data
	 //----------------------------------------------------
	 //
	 //Read Frame Header Byte
	 statusI = $fscanf(f_rx_in,"%h\n",r_rx_data_byte);
	 @(negedge sys_clk);
	 send_byte = 1'b1; //send byte
	 @(negedge sys_clk);
	 @(negedge sys_clk);
	 send_byte = 1'b0; //turn off initiator
	 wait(avr_tx_rdy == 1'b1);
	 @(posedge sys_clk);
	 
	 //Read Word Count (upper nibble) and Opcode (lower nibble)
	 statusI = $fscanf(f_rx_in,"%h\n",r_rx_data_byte);
	 r_rx_word_cnt = r_rx_data_byte[7:4];
	 @(negedge sys_clk);
	 send_byte = 1'b1; //send byte
	 @(negedge sys_clk);
	 @(negedge sys_clk);
	 send_byte = 1'b0; //turn off initiator
	 wait(avr_tx_rdy == 1'b1);
	 @(posedge sys_clk);
    
	 // loop_cnt
	 //Send rest of data
	 for (loop_cnt=1; loop_cnt <= ((r_rx_word_cnt*2)+1); loop_cnt= loop_cnt+1)
	   begin
		  statusI = $fscanf(f_rx_in,"%h\n",r_rx_data_byte);
	     @(negedge sys_clk);
	     send_byte = 1'b1; //send byte
	     @(negedge sys_clk);
	     @(negedge sys_clk);
	     send_byte = 1'b0; //turn off initiator
	     wait(avr_tx_rdy == 1'b1);
	     @(posedge sys_clk);
	   end
    
    @(posedge sys_clk);
    
		 
       
	 
	 
    //**************************
    //@(posedge sys_clk);
    #5000;
    $fclose(f_rx_in);
    $stop;
  end  
  
  //----------------------------------------------------
  // Send AVR Tx Byte When Ready
  //-----------------------------------------------------
  //
  always@(posedge send_byte)
    begin
	   if (RST) 
		  begin
		    r_rx  =   1'b1;
			 avr_tx_rdy = 1'b1;
		    i     =   0;
		  end
		else if (send_byte)
		  begin
		    avr_tx_rdy = 1'b0;
		    // send start bit for 1 bit time
			 r_rx = 1'b0;
			 #8680; //(NS_PER_BIT);
			 // send byte
		    for (i=0; i <= 7; i= i+1)
			   begin
              r_rx = r_rx_data_byte[i];
				  #8680;//(NS_PER_BIT);
				end
			 //send end bit for 1 bit time
			 r_rx = 1'b1;
			 i = 0;
			 #8680; //(NS_PER_BIT);
			 avr_tx_rdy = 1'b1;
		  end
		 else
		   begin
		    r_rx  =   1'b1;
		    i     =   0;
			 avr_tx_rdy = 1'b1;
		  end
	 end
 
endmodule  // TB_ratbot_brain_top.v

