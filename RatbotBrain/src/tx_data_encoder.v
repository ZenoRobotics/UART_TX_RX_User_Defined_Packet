`timescale 1ns / 1ps
//*  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *
//*  *                 Verilog Source Code                                *  *
//*  *                                                                    *  *
//*  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *
//*  Filename and Ext   :     tx_data_encoder.v
//*  Submodules         :     uart_tx.v
//*  Company            :     PhD Dissertation Project
//*  Engineer           :     Peter J. Zeno 
//*  Created            :     December 17, 2016
//*  Mod History        :
//* *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  *  * 
module tx_data_encoder
  #(parameter CLKS_PER_BIT = 434) // 115200 baud
  (
   input         i_Clock,
	input         i_Reset,
   output        o_Tx_Serial,
	input         i_Wr_Tx_Word,
   input  [15:0] i_Tx_Word,
	input   [3:0] i_Tx_Word_Cnt,
	input   [3:0] i_Resp_Type,
	output        o_Tx_Busy,
	input         i_Send_Re_Tx_Hdr,     // Have Arduino re-transmit packet by FPGA transmitting repeat packet
	input         i_Re_Tx_Response
    );

parameter TX_FRAME_HDR        = 8'h96; // h96
parameter RE_TX_CMD_HDR       = 8'hCE;
parameter RE_TX_RESP_HDR      = 8'hEE;

reg  [4:0] r_tx_byte_cnt  = 0;
reg  [4:0] r_tx_byte_cnt2 = 0;
reg  [4:0] r_Num_Bytes_To_Wr  = 0;
reg  [4:0] r_Num_Bytes_To_Uart  = 0;
reg  [7:0] r_Tx_Data_Buffer[9:0];
reg        r_new_tx_data = 0;
reg  [7:0] r_tx_data = 0;
wire       w_tx_done;
reg  [7:0] r_parity_byte    = 8'h00;
reg  [7:0] r_tx_data_byte_temp = 0;

reg  [1:0] s_SM_Buffer_Write    = 0;
reg  [2:0] s_SM_Tx_Frame_Encode = 0;

// s_SM_Buffer_Write states
parameter s_BW_IDLE      = 2'b00;
parameter s_WRITE_STATE  = 2'b01;
parameter s_CREATE_PARITY_BYTE = 2'b10;
parameter s_CLEANUP      = 2'b11;

// s_SM_Tx_Frame_Encode states
parameter s_UART_IDLE        = 3'b000;
parameter s_SEND_UART_BYTE   = 3'b001;
parameter s_WAIT_FOR_TX_DONE = 3'b010;
parameter s_DELAY            = 3'b011;


uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) UART_TX_INST (
     .i_Clock(i_Clock),
     .i_Tx_DV(r_new_tx_data),
     .i_Tx_Byte(r_tx_data),
     .o_Tx_Active(o_Tx_Busy),
     .o_Tx_Serial(o_Tx_Serial),
     .o_Tx_Done(w_tx_done)
     );
	  
	  
// Let cognitive_map module write data into tx word buffer
// when ready.
// Expected from cognitive map:
//   Valid i_Resp_Type, i_Tx_Word_Cnt, i_Wr_Tx_Word and first 
//   data word by posedge of i_Clock. Each 16 bit data word to 
//   be Tx'ed and i_Wr_Tx_Word == 1'b1 at each posedge i_Clock there after.
//
  always @(posedge i_Clock) 
  begin
    if (i_Reset)
	   begin
		  s_SM_Buffer_Write   <= s_BW_IDLE;
		  r_tx_byte_cnt       <= 5'h0;
		  r_Num_Bytes_To_Wr   <= 5'h0;
		  r_parity_byte       <= 8'h00;
		  r_tx_data_byte_temp <= 8'h00;
		  r_Tx_Data_Buffer[0] <= RE_TX_CMD_HDR;
		end
		
	 else
    case (s_SM_Buffer_Write)
	   s_BW_IDLE :
		  begin
		    if (i_Wr_Tx_Word)
			   begin
		        s_SM_Buffer_Write   <= s_WRITE_STATE;
				  r_Tx_Data_Buffer[0] <= TX_FRAME_HDR;
				  r_Tx_Data_Buffer[1] <= {i_Tx_Word_Cnt,i_Resp_Type};
				  r_Tx_Data_Buffer[2] <= i_Tx_Word[7:0];
				  r_Tx_Data_Buffer[3] <= i_Tx_Word[15:8];
				  r_tx_byte_cnt       <= 5'h4;
				  r_Num_Bytes_To_Wr   <= 5'h2 + (i_Tx_Word_Cnt<<1);
				end
				
		    else if (i_Re_Tx_Response)	
            begin
		        s_SM_Buffer_Write   <= s_CLEANUP;
				  r_tx_byte_cnt       <= 5'h4;
				end			 
				
			 else if (i_Send_Re_Tx_Hdr)
			   begin
				  s_SM_Buffer_Write   <= s_BW_IDLE;
				  r_tx_byte_cnt       <= 5'h0;
				  r_Num_Bytes_To_Wr   <= 5'h0;
				  r_Tx_Data_Buffer[0] <= RE_TX_CMD_HDR;
				end
				
		    else 
			   begin
			     s_SM_Buffer_Write   <= s_BW_IDLE;
				  r_tx_byte_cnt       <= 5'h0;
				  r_parity_byte       <= 8'h00;
				  r_tx_data_byte_temp <= 8'h00;
				  //r_Num_Bytes_To_Wr   <= 5'h0;  // save in case of resend needed
				end
		  end
		  
      s_WRITE_STATE :		  
		  begin
		    if (i_Wr_Tx_Word)
			   begin
				  r_tx_byte_cnt <= r_tx_byte_cnt + 5'h2;
				  r_Tx_Data_Buffer[r_tx_byte_cnt]        <= i_Tx_Word[7:0];
				  r_Tx_Data_Buffer[r_tx_byte_cnt + 5'h1] <= i_Tx_Word[15:8];
				  s_SM_Buffer_Write  <= s_WRITE_STATE;
				end
				
			 else if (r_tx_byte_cnt == r_Num_Bytes_To_Wr)
			   begin
				  r_tx_byte_cnt       <= 5'h2;
				  r_tx_data_byte_temp <= r_Tx_Data_Buffer[2];
			     s_SM_Buffer_Write   <= s_CREATE_PARITY_BYTE;
				end
				  
			 else
			   s_SM_Buffer_Write  <= s_WRITE_STATE;
		  end
		  
		s_CREATE_PARITY_BYTE :
		  begin
		    if (r_tx_byte_cnt == r_Num_Bytes_To_Wr)
			   begin
				  r_Tx_Data_Buffer[r_tx_byte_cnt] <= r_parity_byte;
				  r_Num_Bytes_To_Wr  <= r_Num_Bytes_To_Wr + 5'h1;
		        s_SM_Buffer_Write  <= s_CLEANUP;
				end
				
			 else
			   begin
				  r_tx_byte_cnt <= r_tx_byte_cnt + 5'h1;
				  r_tx_data_byte_temp <= r_Tx_Data_Buffer[r_tx_byte_cnt+5'h1];
				  r_parity_byte[r_tx_byte_cnt-5'h2] <= ^r_tx_data_byte_temp;
				  s_SM_Buffer_Write   <= s_CREATE_PARITY_BYTE;
				end
		  end
		  
		s_CLEANUP : // allow for uart feed state machine to sync/start
		  s_SM_Buffer_Write  <= s_BW_IDLE;
		  
		default :  
        s_SM_Buffer_Write  <= s_BW_IDLE;
		  
	 endcase
	 
  end
  
// Send currently buffered data to the uart_tx module
  always @(posedge i_Clock) 
  begin
    if (i_Reset || i_Send_Re_Tx_Hdr)
	   begin
		  r_tx_byte_cnt2 <= 5'h0;
		  r_new_tx_data  <= 1'b0;
        r_tx_data      <= 8'h00;
		  r_Num_Bytes_To_Uart  <= 5'h1; //send out test pattern
		  s_SM_Tx_Frame_Encode <= s_SEND_UART_BYTE; //
		end
		
	 else
    case (s_SM_Tx_Frame_Encode)
	   s_UART_IDLE :
	     begin
		    r_tx_byte_cnt2 <= 5'h0;
		    r_new_tx_data  <= 1'b0;
          r_tx_data      <= 8'h00;
			 if (s_SM_Buffer_Write == s_CLEANUP) 
			   begin
			     r_Num_Bytes_To_Uart  <= r_Num_Bytes_To_Wr;
			     s_SM_Tx_Frame_Encode <= s_SEND_UART_BYTE;
				end
				
			 else 
			   s_SM_Tx_Frame_Encode <= s_UART_IDLE;
		
		  end
		  
		s_SEND_UART_BYTE :
		  begin
		    if (r_tx_byte_cnt2 == r_Num_Bytes_To_Uart)
			   s_SM_Tx_Frame_Encode <= s_UART_IDLE;
			  
			 else
			   begin
		        r_new_tx_data  <= 1'b1;
              r_tx_data      <= r_Tx_Data_Buffer[r_tx_byte_cnt2];
				  r_tx_byte_cnt2 <= r_tx_byte_cnt2 + 5'h1;
				  s_SM_Tx_Frame_Encode <= s_WAIT_FOR_TX_DONE;
				end
		  end
		
      s_WAIT_FOR_TX_DONE :
        begin
		    r_new_tx_data <= 1'b0;
		    if(w_tx_done)
			   s_SM_Tx_Frame_Encode <= s_DELAY;
		    else
			   s_SM_Tx_Frame_Encode <= s_WAIT_FOR_TX_DONE;
        end
		  
		s_DELAY :
		  s_SM_Tx_Frame_Encode <= s_SEND_UART_BYTE;
		  
		default :  
		  s_SM_Tx_Frame_Encode <= s_UART_IDLE;
    endcase
  end
  
endmodule
