module cognitive_map (
    input         i_Clk,
    input         i_Rst,
	 // Serial TX User Interface
    output [15:0] o_Tx_Word,
    output        o_New_Tx_DV,         
	 output        o_Write_Tx_Word,
	 output  [3:0] o_Tx_Word_Cnt, 
	 output  [3:0] o_Tx_Resp_Type,     
    // Serial Rx User Interface
	 output        o_Read_Rx_Word,         
    input  [15:0] i_Rx_Word,
    input         i_New_Rx_Words,     
	 input   [3:0] i_Rx_Word_Cnt, 
	 input   [3:0] i_Opcode, 
	 output        pc_found,   // place cell found at/near x,y_coord
    output        bvc_found	  // boundary vector cell found at/near x,y_coord
  );
 
 reg  [15:0] r_xCoord, r_yCoord = 0;
 reg   [7:0] r_heading = 0; // in degrees
 reg   [3:0] r_opcode  = 0;
 reg   [3:0] r_tx_write_word_cnt = 0;
 reg   [3:0] r_get_set_word_cnt  = 0;
 reg  [15:0] r_tx_word = 0;
 reg   [3:0] r_tx_word_cnt = 0;
 reg   [3:0] r_rx_word_cnt = 0;
 reg         r_write_tx_word  = 0;
 reg         r_read_rx_word   = 0;
 reg         r_comm_loop_enable  = 0;
 reg         r_comm_loop_done    = 0;
 
 
 // Main State Machine states
 // opcodes
 reg   [2:0] s_SM_MAIN_CNTRL = 0;
 
 // s_SM_MAIN_CNTRL
 parameter s_IDLE                   = 3'b000;
 parameter s_DELAY                  = 3'b001;
 parameter s_GET_SET_DATA           = 3'b010;
 parameter s_EXECUTE_OPCODE         = 3'b011;
 parameter s_WRITE_OUT_RESULT_DATA  = 3'b100;
 
 // opcodes
 reg   [3:0] op_Comm_Test_Loop  = 4'h0;  // loop rx data to tx
 
 assign o_Write_Tx_Word = r_write_tx_word;
 assign o_Tx_Word       = r_tx_word;
 assign o_Tx_Word_Cnt   = r_tx_word_cnt;
 assign o_Tx_Resp_Type  = r_opcode;  // use opcode for now
 assign o_Read_Rx_Word  = r_read_rx_word;
 
 // Main Controller SM
 always@(posedge i_Clk)
   begin
	  if (i_Rst) 
	    begin
		   s_SM_MAIN_CNTRL     <=  s_IDLE;
			r_opcode            <=  4'h0;
			r_rx_word_cnt       <=  4'h0;
			r_get_set_word_cnt  <=  4'h0;
			r_comm_loop_enable  <=  1'b0;
			r_comm_loop_done    <=  1'b0;
			r_tx_write_word_cnt <=  4'h0;
			r_tx_word           <= 16'h0;
         r_write_tx_word     <=  1'b0;
			r_read_rx_word      <=  1'b0;
		 end
	  else
	    case(s_SM_MAIN_CNTRL)
		   s_IDLE :
			  begin
			    r_get_set_word_cnt   <=  4'h0;
				 r_comm_loop_enable   <=  1'b0;
				 r_comm_loop_done     <=  1'b0;
				 r_tx_write_word_cnt  <=  4'h0;
				 r_tx_word_cnt        <=  4'h0;
				 r_tx_word            <= 16'h0;
             r_write_tx_word      <=  1'b0;
				 
			    if (i_New_Rx_Words)
			      begin
				     s_SM_MAIN_CNTRL    <= s_DELAY;
				     r_opcode           <= i_Opcode;
					  r_rx_word_cnt      <= i_Rx_Word_Cnt;
					  r_read_rx_word     <= 1'b1;
				   end
					
			    else
			      begin
				     s_SM_MAIN_CNTRL    <= s_IDLE;
			        r_opcode           <= 4'h0;
			        r_rx_word_cnt      <= 4'h0;
					  r_read_rx_word     <= 1'b0;
			      end
			  end
				 
			s_DELAY :
			  s_SM_MAIN_CNTRL    <= s_GET_SET_DATA;
			  
			s_GET_SET_DATA :
			  begin
				 r_get_set_word_cnt <= r_get_set_word_cnt + 4'h1;
				 case(r_opcode)
					op_Comm_Test_Loop : 
					  begin
					    if (r_get_set_word_cnt == 4'h0)
							begin
							  r_xCoord        <= i_Rx_Word;
							  r_read_rx_word  <= 1'b1;
							  s_SM_MAIN_CNTRL <= s_GET_SET_DATA;
							end
							  
						 else if (r_get_set_word_cnt == 4'h1)
							begin
							  r_yCoord        <= i_Rx_Word;
							  r_read_rx_word  <= 1'b1;
							  s_SM_MAIN_CNTRL <= s_GET_SET_DATA;
							end
							  
						 else  // r_get_set_word_cnt == 4'h2
							begin
							  r_heading       <= i_Rx_Word[7:0];
							  r_read_rx_word  <= 1'b0;
							  s_SM_MAIN_CNTRL <= s_EXECUTE_OPCODE;
							end
							
					  end
						 
					default :
					  s_SM_MAIN_CNTRL    <= s_IDLE;
						 
			    endcase
		
			  end
				 
			// enable appropriate processing modules based on opcode	 
			s_EXECUTE_OPCODE :
			  // any execution blocks finished?
			  begin
			    if (r_comm_loop_done) 
				   begin  
					  s_SM_MAIN_CNTRL    <= s_WRITE_OUT_RESULT_DATA;
					  // set all enables to zero
					end
				 else
				   begin
			        case(r_opcode)
			          op_Comm_Test_Loop : 
				         begin
					        //r_comm_loop_enable <= 1'b1;
							  r_comm_loop_done    <=  1'b1;
				           s_SM_MAIN_CNTRL    <= s_EXECUTE_OPCODE;
					      end
					
			          default :
				         s_SM_MAIN_CNTRL    <= s_IDLE;
					  endcase	 
			      end
				end
			  
			s_WRITE_OUT_RESULT_DATA :
			  begin
				 r_tx_write_word_cnt <= r_tx_write_word_cnt + 4'h1;
				 case(r_opcode)
					op_Comm_Test_Loop : 
					  begin
					    if (r_tx_write_word_cnt == 4'h0)
							begin
							  r_tx_word_cnt   <= 4'h3; // 
							  r_tx_word       <= r_xCoord;
							  r_write_tx_word <= 1'b1;
							  s_SM_MAIN_CNTRL <= s_WRITE_OUT_RESULT_DATA;
							end
							  
						 else if (r_tx_write_word_cnt == 4'h1)
							begin
							  r_tx_word       <= r_yCoord;
							  r_write_tx_word <= 1'b1;
							  s_SM_MAIN_CNTRL <= s_WRITE_OUT_RESULT_DATA;
							end
							  
						 else if (r_tx_write_word_cnt == 4'h2)
							begin
							  r_tx_word       <= {8'h00,r_heading};
							  r_write_tx_word <= 1'b1;
							  s_SM_MAIN_CNTRL <= s_WRITE_OUT_RESULT_DATA;
							end
						 else
						   begin
							  r_write_tx_word <= 1'b0;
							  s_SM_MAIN_CNTRL <= s_IDLE;
							end
							
					  end
						 
					default :
					  s_SM_MAIN_CNTRL    <= s_IDLE;
						 
			    endcase
		
			  end
			  
			default :
			  s_SM_MAIN_CNTRL   <= s_IDLE;
			  
		 endcase
	end
 
 
 endmodule
 