module uart_cogn_map_interface (
    input clk,
    input rst,
	 // uart interface
    output [7:0] tx_data,
    output reg new_tx_data,
    input tx_busy,
    input [15:0] rx_word,
    input new_rx_word,
	 // cognitive map interface
	 output reg [23:0] x_coord,
	 output reg [23:0] y_coord,
	 output reg data_out_valid,
	 input  pc_found,   // place cell found at/near x,y_coord
    input  bvc_found	  // boundary vector cell found at/near x,y_coord
  );
 
  localparam STATE_SIZE = 3;
  localparam IDLE = 0,
    PRINT_MESSAGE = 1,
	 PRINT_MESSAGE_DELAY1 = 2,
	 PRINT_MESSAGE_DELAY2 = 3;
 
  localparam MESSAGE_LEN = 14;
  localparam DELAY_COUNT = 100;
 
  reg [STATE_SIZE-1:0] state_d, state_q = 0;
 
  reg [3:0] addr_d, addr_q = 0;
  reg [7:0] delay_cnt_d = 0;
  
  wire [7:0] tx_data_w;
 
  message_rom message_rom (
  .clk(clk),
  .addr(addr_q),
  .data(tx_data_w)
  );
 
  always @(*) begin
    state_d = state_q; // default values
    addr_d = addr_q;   // needed to prevent latches
    new_tx_data = 1'b0;
 
    case (state_q)
      IDLE: begin
		  addr_d = 4'd0;
        if (new_rx_word && rx_word[7:0] == "h")
          state_d = PRINT_MESSAGE;
      end
      PRINT_MESSAGE: begin
		  delay_cnt_d = 8'h00;
		  if (!tx_busy) begin
          new_tx_data = 1'b0;
          addr_d = addr_q;
          state_d = PRINT_MESSAGE_DELAY1;
        end
      end
		PRINT_MESSAGE_DELAY1: begin
		  if (!tx_busy) begin
		    new_tx_data = 1'b0;
          addr_d = addr_q;
          state_d = PRINT_MESSAGE_DELAY2;
        end
      end
		PRINT_MESSAGE_DELAY2: begin
        if (!tx_busy) begin 
          new_tx_data = 1'b1;
          addr_d = addr_q + 1'b1;
			 state_d = PRINT_MESSAGE;
          if (addr_q == MESSAGE_LEN-1)
            state_d = IDLE;
        end
      end
      default: state_d = IDLE;
    endcase
  end
 
  always @(posedge clk) begin
    if (rst) begin
      state_q <= IDLE;
    end else begin
      state_q <= state_d;
    end
 
    addr_q <= addr_d;
	 
  end
  
  assign tx_data = tx_data_w;
 
endmodule