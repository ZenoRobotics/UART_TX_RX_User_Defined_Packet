module mojo_top(
    // 50MHz clock input
    input  clk,
	 // Input from reset button (active low)
    input  rst_n,
    // cclk input from AVR, high when AVR is ready
    input  cclk,
    // Outputs to the 8 onboard LEDs
    output [7:0] led,
    // AVR SPI connections
    output spi_miso,
    input  spi_ss,
    input  spi_mosi,
    input  spi_sck,
    // AVR ADC channel select
    output [3:0] spi_channel,
    // Serial connections
    input  avr_tx, // AVR Tx => FPGA Rx
    output avr_rx, // AVR Rx => FPGA Tx
    input  avr_rx_busy // AVR Rx buffer full
  );
 
  wire rst = ~rst_n; // make reset active high
  /*
  reg [23:0] counter = 24'h0;
  always @(posedge clk) begin
     counter <= counter + 24'h1;
  end
  
  assign led = {counter[23],counter[22],counter[21],counter[20],
                counter[19],counter[18],counter[17],counter[16]};
 */
  assign led = 8'b00000000;
  
  wire cclk_rdy;
  wire [15:0] tx_word;
  wire w_new_tx_dv;
  wire tx_busy;
  wire [15:0] w_rx_word;
  wire w_new_rx_words;
  wire w_rd_rx_word;
  wire [3:0] w_rx_word_cnt;
  wire [3:0] w_opcode;
  wire w_write_tx_word;
  wire [3:0] w_tx_word_cnt;
  wire [3:0] w_resp_type;
  
  wire pcFound;
  wire bvcFound;
 
  avr_interface avr_interface_inst (
    .clk(clk),
    .rst(rst),
    .cclk(cclk),
	 .cclk_rdy(cclk_rdy),
    .spi_miso(spi_miso),
    .spi_mosi(spi_mosi),
    .spi_sck(spi_sck),
    .spi_ss(spi_ss),
    .spi_channel(spi_channel),
    .tx(avr_rx),     // FPGA tx goes to AVR rx
    .rx(avr_tx),
    .channel(4'd15), // invalid channel disables the ADC
    .new_sample(),
    .sample(),
    .sample_channel(),
	 // Serial TX User Interface
    .tx_word(tx_word),              // input  [15:0] 
    .new_tx_dv(w_new_tx_dv),        // input         
	 .write_tx_word(w_write_tx_word),// input
	 .tx_word_cnt(w_tx_word_cnt),    // input   [3:0] 
	 .tx_resp_type(w_resp_type),     // input   [3:0] 
    .tx_busy(tx_busy),              // output        
    .tx_block(1'b0), //avr_rx_busy),//	input          
    
    // Serial Rx User Interface
	 .read_rx_word(w_rd_rx_word),   // input         
    .rx_word(w_rx_word),           // output [15:0] 
    .new_rx_words(w_new_rx_words), // output        
	 .rx_word_cnt(w_rx_word_cnt),   // output  [3:0] 
	 .opcode(w_opcode)              // output        
  );
  
  cognitive_map cognitive_map_inst (
    .i_Clk(clk),
    .i_Rst(rst),
	 // Serial TX User Interface
    .o_Tx_Word(tx_word),             // output  [15:0] 
    .o_New_Tx_DV(new_tx_data),       // output         
	 .o_Write_Tx_Word(w_write_tx_word),   // output
	 .o_Tx_Word_Cnt(w_tx_word_cnt),   // output   [3:0] 
	 .o_Tx_Resp_Type(w_resp_type),    // output   [3:0]          
    
    // Serial Rx User Interface
	 .o_Read_Rx_Word(w_rd_rx_word),   // output         
    .i_Rx_Word(w_rx_word),           // input [15:0] 
    .i_New_Rx_Words(w_new_rx_words), // input        
	 .i_Rx_Word_Cnt(w_rx_word_cnt),   // input  [3:0] 
	 .i_Opcode(w_opcode),             // input  [3:0]     
	 .pc_found(pcFound),   // place cell found at/near x,y_coord
    .bvc_found(bvcFound)  // boundary vector cell found at/near x,y_coord
  );
  
endmodule