module cognitive_map (
    input clk,
    input rst,
	 // uart_cogn_map_interface
	 input  [23:0] x_coord,
	 input  [23:0] y_coord,
	 input  data_valid,
	 output pc_found,   // place cell found at/near x,y_coord
    output bvc_found	  // boundary vector cell found at/near x,y_coord
  );
 
 endmodule