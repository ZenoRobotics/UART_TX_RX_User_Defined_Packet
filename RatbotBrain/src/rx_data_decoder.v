//*  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *
//*  *                 Verilog Source Code                                *  *
//*  *                                                                    *  *
//*  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *
//*  Filename and Ext   :     rx_data_decoder.v
//*  Submodules         :     uart_rx.v
//*  Company            :     PhD Dissertation Project
//*  Engineer           :     Peter J. Zeno 
//*  Created            :     December 14, 2016
//*  Mod History        :
//* *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  * 
module rx_data_decoder 
  #(parameter CLKS_PER_BIT = 434) // 115200 baud
  (
   input         i_Clock,
	input         i_Reset,
   input         i_Rx_Serial,
	input         i_Rd_Rx_Word,
   output        o_Rx_Data_Rdy,         // word valid signal
   output [15:0] o_Rx_Word,
	output  [3:0] o_Rx_Word_Cnt,
	output  [3:0] o_Opcode,
	output        o_Send_Re_Tx_Hdr,      // Have Arduino re-transmit packet by FPGA transmitting repeat packet
	output        o_Re_Tx_Response
   );

wire       w_new_rx_data;
wire [7:0] w_rx_data_byte;

reg        r_rx_data_rdy = 1'b0;
reg [15:0] r_Rx_Data_Buffer[3:0];
reg [15:0] r_rx_word = 0;
reg  [3:0] r_Num_Words_Rd   = 4'h0;
reg  [3:0] r_Num_Words_To_Be_Rd = 4'h0;
reg  [3:0] r_Word_Cnt       = 4'h0;
reg  [3:0] r_Num_Words_Sent = 4'h0;      // Just data words. Not counting instruction byte
reg  [2:0] s_SM_Rx_Frame_Decode = 3'b000;
reg  [1:0] s_SM_Buffer_Read = 2'b00;
reg  [3:0] r_rx_word_cnt    = 4'h0;
reg  [3:0] r_opcode         = 4'h0;
reg        r_send_re_tx_hdr = 1'b0;
reg        r_re_tx_resp     = 1'b0;
reg  [7:0] r_parity_byte_rx = 8'h00;
reg  [7:0] r_parity_byte    = 8'h00;
reg  [4:0] r_data_byte_cnt  = 5'h0;
        

parameter RX_FRAME_HDR     = 8'hA5; // hA5
parameter RE_TX_CMD_HDR    = 8'hCE;
parameter RE_TX_RESP_HDR   = 8'hEE;

// s_SM_Rx_Frame_Decode states
parameter s_IDLE            = 3'b000;
parameter s_GET_INSTR       = 3'b001;
parameter s_GET_LSByte      = 3'b010;
parameter s_GET_MSByte      = 3'b011;
parameter s_CHECK_WORD_CNT  = 3'b100;
parameter s_GET_PARITY_BYTE = 3'b101;
parameter s_PARITY_CHECK    = 3'b110;
parameter s_CLEANUP         = 3'b111;

// s_SM_Buffer_Read states
parameter s_BR_IDLE     = 2'b00;
parameter s_READ_STATE  = 2'b01;


assign o_Rx_Word        = r_rx_word; 
assign o_Rx_Data_Rdy    = r_rx_data_rdy;
assign o_Rx_Word_Cnt    = r_rx_word_cnt;
assign o_Opcode         = r_opcode;
assign o_Send_Re_Tx_Hdr = r_send_re_tx_hdr;
assign o_Re_Tx_Response = r_re_tx_resp;

uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) UART_RX_INST (
     .i_Clock(i_Clock),
     .i_Rx_Serial(i_Rx_Serial),
     .o_Rx_DV(w_new_rx_data),
     .o_Rx_Byte(w_rx_data_byte)
     );
	  
// RX Data Decoder/Data Buffer State Machine 
// Purpose: Buffer incoming rx data.
// Note: Currently no error checking implemented
always @(posedge i_Clock) 
  begin
    if (i_Reset)
	   begin
		  r_Word_Cnt       <= 4'h0;
		  r_Num_Words_Sent <= 4'h0;
		  r_send_re_tx_hdr <= 1'b0;
        r_re_tx_resp     <= 1'b0;
		  r_parity_byte_rx <= 8'h0;
		  r_parity_byte    <= 8'h0;
		  r_data_byte_cnt  <= 5'h0;
		  s_SM_Rx_Frame_Decode <= s_IDLE;
		end
		
	 else
    case (s_SM_Rx_Frame_Decode)
	   s_IDLE :
		  begin
		    r_Word_Cnt       <= 4'h0;
			 r_Num_Words_Sent <= 4'h0;
			 r_parity_byte_rx <= 8'h0;
		    r_parity_byte    <= 8'h0;
			 r_data_byte_cnt  <= 5'h0;
			 //r_rx_word_cnt <= 4'h0;
          //r_opcode <= 4'h0;
          if (w_new_rx_data && (w_rx_data_byte == RX_FRAME_HDR)) 
			   begin
				  s_SM_Rx_Frame_Decode <= s_GET_INSTR;
				  r_send_re_tx_hdr <= 1'b0;
              r_re_tx_resp     <= 1'b0;
				end

			 else if (w_new_rx_data && (w_rx_data_byte == RE_TX_RESP_HDR))
			   begin
				  s_SM_Rx_Frame_Decode <= s_IDLE;
			     r_send_re_tx_hdr <= 1'b0;
              r_re_tx_resp     <= 1'b1;
				end
				
			 else if (w_new_rx_data)
			   begin
			     s_SM_Rx_Frame_Decode <= s_IDLE;
			     r_send_re_tx_hdr <= 1'b1;
              r_re_tx_resp     <= 1'b0;
				end
				
			 else
			   begin
			     s_SM_Rx_Frame_Decode <= s_IDLE;
				  r_send_re_tx_hdr <= 1'b0;
              r_re_tx_resp     <= 1'b0;
				end
		  end
		  
		s_GET_INSTR :
		  begin
		    if (w_new_rx_data) 
			   begin
				  r_Num_Words_Sent <= w_rx_data_byte[7:4];
				  s_SM_Rx_Frame_Decode <= s_GET_LSByte;
				  r_rx_word_cnt <= w_rx_data_byte[7:4];
              r_opcode <= w_rx_data_byte[3:0];
				end
			 else
			   s_SM_Rx_Frame_Decode <= s_GET_INSTR;
		  end
		  
		s_GET_LSByte :
		  begin
		    if (w_new_rx_data) 
			   begin
				  r_Rx_Data_Buffer[r_Word_Cnt] <= {8'h00,w_rx_data_byte};
				  s_SM_Rx_Frame_Decode <= s_GET_MSByte;
				  r_data_byte_cnt  <= r_data_byte_cnt + 5'h1;
				  r_parity_byte[r_data_byte_cnt] <= ^w_rx_data_byte;
				end
			 else
			   s_SM_Rx_Frame_Decode <= s_GET_LSByte;
		  end
		  
		s_GET_MSByte :
		  begin
		    if (w_new_rx_data) 
			   begin
				  r_Rx_Data_Buffer[r_Word_Cnt] <=  {w_rx_data_byte,8'h00} | r_Rx_Data_Buffer[r_Word_Cnt];
				  r_Word_Cnt <= r_Word_Cnt + 4'h1;
				  r_data_byte_cnt  <= r_data_byte_cnt + 5'h1;
				  r_parity_byte[r_data_byte_cnt] <= ^w_rx_data_byte;
				  s_SM_Rx_Frame_Decode <= s_CHECK_WORD_CNT;
				end
			 else
			   s_SM_Rx_Frame_Decode <= s_GET_MSByte;
		  end
		  
		s_CHECK_WORD_CNT : 
		  begin
		    if (r_Word_Cnt == r_Num_Words_Sent)
		      s_SM_Rx_Frame_Decode <= s_GET_PARITY_BYTE;
		    else
		      s_SM_Rx_Frame_Decode <= s_GET_LSByte;
			end
		
		s_GET_PARITY_BYTE :
		  begin
		    if (w_new_rx_data) 
			   begin
				  r_parity_byte_rx     <= w_rx_data_byte;
				  s_SM_Rx_Frame_Decode <= s_PARITY_CHECK;
				end
			 else
			   s_SM_Rx_Frame_Decode <= s_GET_PARITY_BYTE;
		  end
		
		s_PARITY_CHECK :
		  begin
		    if(r_parity_byte == r_parity_byte_rx)
			   s_SM_Rx_Frame_Decode <= s_CLEANUP;
				
			 else
			   begin
				  s_SM_Rx_Frame_Decode <= s_IDLE;
				  r_send_re_tx_hdr     <= 1'b1;
				end
		  end
		
		// Stay here 1 clock
      s_CLEANUP :
		  s_SM_Rx_Frame_Decode <= s_IDLE;
		  
		default :
        s_SM_Rx_Frame_Decode <= s_IDLE;  
			 
	 endcase
	   
  end	  
  
  // Let cognitive_map module read out data from rx word buffer
  always @(posedge i_Clock) 
  begin
    if (i_Reset)
	   begin
		  s_SM_Buffer_Read <= s_BR_IDLE;
		  r_Num_Words_To_Be_Rd <= 4'h0;
		  r_rx_data_rdy <= 1'b0;
		  r_rx_word <= 16'h0000;
		end
		
	 else
    case (s_SM_Buffer_Read)
	   s_BR_IDLE :
		  begin
		    r_Num_Words_Rd <= 4'h0;
		    if (s_SM_Rx_Frame_Decode == s_CLEANUP)
			   begin
		        s_SM_Buffer_Read <= s_READ_STATE;
				  r_Num_Words_To_Be_Rd <= r_Num_Words_Sent; 
				  r_rx_data_rdy <= 1'b1;
				  r_rx_word <= r_Rx_Data_Buffer[0];
				end
		    else 
			   begin
			     s_SM_Buffer_Read <= s_BR_IDLE;
				  r_Num_Words_To_Be_Rd <= 4'h0;
				  r_rx_data_rdy <= 1'b0;
				  r_rx_word <= 16'h0000;
				end
		  end
		  
      s_READ_STATE :		  
		  begin
		    if (i_Rd_Rx_Word)
			   begin
				  r_rx_data_rdy <= 1'b0;
				  r_Num_Words_Rd <= r_Num_Words_Rd + 4'h1;
				  if (r_Num_Words_Rd == r_Num_Words_To_Be_Rd) 
						s_SM_Buffer_Read <= s_BR_IDLE;
	
				  else
				    begin
					   r_rx_word <= r_Rx_Data_Buffer[r_Num_Words_Rd];
						s_SM_Buffer_Read <= s_READ_STATE;
					 end
				end
			 else
			   s_SM_Buffer_Read <= s_READ_STATE;
		  end
		  
		default :  
        s_SM_Buffer_Read <= s_BR_IDLE;
		  
	 endcase
	 
  end
	  
endmodule  //rx_data_module