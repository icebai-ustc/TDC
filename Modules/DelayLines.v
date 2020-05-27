module DelayLine(
   in,
	 out
);

parameter n = 5;                    // Number of pairs of inverters.
input in;           // Undelayed input signal
output out;          // Delayed output signal
wire [2*n-1:0] delay /*synthesis keep*/;

// Fix first delay to in
assign delay[0] = ~in;

// Generate inverter-based delays
genvar i;
generate for (i=0; i<2*n-1; i=i+1) begin : generate_delays
   assign delay[i+1] = ~delay[i];
end
endgenerate

// If n is 0, i.e. no delays, simply connect in to out, otherwise
// connect to last delay element
generate if (n == 0) begin
   assign out = in;
end else begin
	assign out = delay[2*n-1];
end
endgenerate

endmodule

//delay line module
module CopyLine(
   in,
	 out
);

parameter n = 5;                    // Number of pairs of inverters.
input in;           // Undelayed input signal
output out;          // Delayed output signal
wire [n-1:0] delay /*synthesis keep*/;

// Fix first delay to in
assign delay[0] = in;

// Generate inverter-based delays
genvar i;
generate for (i=0; i<n-1; i=i+1) begin : generate_delays
   assign delay[i+1] = delay[i];
end
endgenerate

// If n is 0, i.e. no delays, simply connect in to out, otherwise
// connect to last delay element
generate if (n == 0) begin
   assign out = in;
end else begin
	assign out = delay[n-1];
end
endgenerate

endmodule



module AdjustableCopyLine(
  multiwire,
  in,
	out
);

localparam n = 3;                    // Number of pairs of inverters.
input 	             in;           // Undelayed input signal
output reg    	          out;          // Delayed output signal

wire [n-1:0] delay /*synthesis keep*/;

assign delay[0] = in;

genvar i;
generate for (i=0; i<n-1; i=i+1) begin : generate_delays
   assign delay[i+1] = delay[i];
end
endgenerate

input [2:0] multiwire;
always @ (*) begin
      case (multiwire)
         3'b000 : out <= delay[0];
         3'b001 : out <= delay[1];
         3'b010 : out <= delay[2];
         3'b011 : out <= delay[3];
         3'b100 : out <= delay[4];
         3'b101 : out <= delay[5];
         3'b110 : out <= delay[6];
         3'b111 : out <= delay[7];
      endcase
end

endmodule

module AdjustableDelayLine(
  multiwire,
  in,
	out
);

localparam n = 16;                    // Number of pairs of inverters.
input 	             in;           // Undelayed input signal
output reg    	          out;          // Delayed output signal

wire [2*n-1:0] delay /*synthesis keep*/;

assign delay[0] = ~in;

genvar i;
generate for (i=0; i<2*n-1; i=i+1) begin : generate_delays
   assign delay[i+1] = ~delay[i];
end
endgenerate

input [2:0] multiwire;
always @ (*) begin
      case (multiwire)
         3'b000 : out <= delay[1];
         3'b001 : out <= delay[3];
         3'b010 : out <= delay[5];
         3'b011 : out <= delay[7];
         3'b100 : out <= delay[9];
         3'b101 : out <= delay[11];
         3'b110 : out <= delay[13];
         3'b111 : out <= delay[15];
      endcase
end

endmodule
