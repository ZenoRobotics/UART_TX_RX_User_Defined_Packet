module avr_interface #(
    parameter CLK_RATE = 50000000,
    parameter SERIAL_BAUD_RATE = 115200 //57600 // 
  )(
    input clk,
    input rst,
    
    // cclk, or configuration clock is used when the FPGA is begin configured.
    // The AVR will hold cclk high when it has finished initializing.
    // It is important not to drive the lines connecting to the AVR
    // until cclk is high for a short period of time to avoid contention.
    input cclk,
	 output cclk_rdy,
    
    // AVR SPI Signals
    output spi_miso,
    input spi_mosi,
    input spi_sck,
    input spi_ss,
    output [3:0] spi_channel,
    
    // AVR Serial Signals
    output tx,
    input  rx,
    
    // ADC Interface Signals
    input [3:0] channel,
    output new_sample,
    output [9:0] sample,
    output [3:0] sample_channel,
    
    // Serial TX User Interface
    input  [15:0] tx_word,
    input         new_tx_dv,
	 input         write_tx_word,
	 input   [3:0] tx_word_cnt,
	 input   [3:0] tx_resp_type,
    output        tx_busy,
    input         tx_block,	 
    
    // Serial Rx User Interface
	 input         read_rx_word,
    output [15:0] rx_word,
    output        new_rx_words,
	 output  [3:0] rx_word_cnt,
	 output  [3:0] opcode
  );
  
  wire ready;
  wire n_rdy = !ready;
  wire spi_done;
  wire [7:0] spi_dout;
  
  wire re_trans_cmd;
  wire re_tx_response;
  wire w_tx;
  wire spi_miso_m;
  
  reg byte_ct_d, byte_ct_q;
  reg [9:0] sample_d, sample_q;
  reg new_sample_d, new_sample_q;
  reg [3:0] sample_channel_d, sample_channel_q;
  reg [3:0] block_d, block_q;
  reg busy_d, busy_q;
  
  assign cclk_rdy = ready;
  
  // cclk_detector is used to detect when cclk is high signaling when
  // the AVR is ready
  cclk_detector #(.CLK_RATE(CLK_RATE)) cclk_detector (
    .clk(clk),
    .rst(rst),
    .cclk(cclk),
    .ready(ready)
  );
  
  /*
  spi_slave spi_slave (
    .clk(clk),
    .rst(n_rdy),
    .ss(spi_ss),
    .mosi(spi_mosi),
    .miso(spi_miso_m),
    .sck(spi_sck),
    .done(spi_done),
    .din(8'hff),
    .dout(spi_dout)
  );
  */
  
  // CLK_PER_BIT is the number of cycles each 'bit' lasts for
  // rtoi converts a 'real' number to an 'integer'
  parameter CLK_PER_BIT = $rtoi($ceil(CLK_RATE/SERIAL_BAUD_RATE));
  rx_data_decoder #(.CLKS_PER_BIT(CLK_PER_BIT)) rx_data_decoder_inst (
     .i_Clock(clk),
	  .i_Reset(rst),
     .i_Rx_Serial(rx),
	  .i_Rd_Rx_Word(read_rx_word),
     .o_Rx_Data_Rdy(new_rx_words),
     .o_Rx_Word(rx_word),
	  .o_Rx_Word_Cnt(rx_word_cnt),
	  .o_Opcode(opcode),
	  .o_Send_Re_Tx_Hdr(re_tx_cmd),
	  .o_Re_Tx_Response(re_tx_response)
     );
	  
  tx_data_encoder #(.CLKS_PER_BIT(CLK_PER_BIT)) tx_data_encoder_inst (
     .i_Clock(clk),
	  .i_Reset(rst),
     .o_Tx_Serial(w_tx),
	  .i_Wr_Tx_Word(write_tx_word),
     .i_Tx_Word(tx_word),
	  .i_Tx_Word_Cnt(tx_word_cnt),
	  .i_Resp_Type(tx_resp_type),
	  .o_Tx_Busy(tx_busy),
	  .i_Send_Re_Tx_Hdr(re_trans_cmd),
	  .i_Re_Tx_Response(re_tx_response)
     );

  
  
  // Output declarations
  assign new_sample = new_sample_q;
  assign sample = sample_q;
  assign sample_channel = sample_channel_q;
  
  // these signals connect to the AVR and should be Z when the AVR isn't ready
  assign spi_channel = ready ? channel : 4'bZZZZ;
  assign spi_miso = ready && !spi_ss ? spi_miso_m : 1'bZ;
  //assign tx = ready ? w_tx : 1'bZ; 
  assign tx = w_tx; 
  
  always @(*) begin
    byte_ct_d = byte_ct_q;
    sample_d = sample_q;
    new_sample_d = 1'b0;
    sample_channel_d = sample_channel_q;

    busy_d = busy_q;
    block_d = {block_q[2:0], tx_block};

    if (block_q[3] ^ block_q[2])
      busy_d = 1'b0;

    if (!tx_busy && new_tx_dv)
      busy_d = 1'b1;
    
    if (spi_ss) begin // device is not selected
      byte_ct_d = 1'b0;
    end
    
    if (spi_done) begin // sent/received data from SPI
      if (byte_ct_q == 1'b0) begin
        sample_d[7:0] = spi_dout; // first byte is the 8 LSB of the sample
        byte_ct_d = 1'b1;
      end else begin
        sample_d[9:8] = spi_dout[1:0]; // second byte is the channel 2 MSB of the sample
        sample_channel_d = spi_dout[7:4]; // and the channel that was sampled
        byte_ct_d = 1'b1; // slave-select must be brought high before the next transfer
        new_sample_d = 1'b1;
      end
    end
  end
  
  always @(posedge clk) begin
    if (n_rdy) begin
      byte_ct_q <= 1'b0;
      sample_q <= 10'b0;
      new_sample_q <= 1'b0;
    end else begin
      byte_ct_q <= byte_ct_d;
      sample_q <= sample_d;
      new_sample_q <= new_sample_d;
    end
    
    block_q <= block_d;
    busy_q <= busy_d;
    sample_channel_q <= sample_channel_d;
  end
  
endmodule