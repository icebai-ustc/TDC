//carry chain using cyclone v primitives
module CarryChain(
  a,
  b,
  cin,
  sout,
  clk

  );
//size of chain
  parameter N=16;
 //carry in
  input cin;
//constant summation inputs
  input [N-1:0] a;//=0000...
  input [N-1:0] b;//=1111...
//clock for registers
  input clk;
//data out from registers
  output [N-1:0] sout;
//internal wire for passing carries
//one bit larger for initial combinatorial cell
//which passes data_in along carry chain
  wire [N:0] c_internal;
//assign first input manually
  primitive_carry_in mycarry_in (
    .datac(cin),
    .cout(c_internal[0]),
  );
//internal wire for sum outs
  wire [N-1:0] s;
//and rest with loop
  genvar i;
  generate
  for (i=1; i<N+1; i=i+1) begin : gen

    primitive_carry mycarry (
    	.a(a[i-1]),
    	.b(b[i-1]),
    	.cin(c_internal[i-1]), //0 feeds in
    	.cout(c_internal[i]),
    	.s(s[i-1])
    );

    primitive_ff myff(
    	.s(s[i-1]),
    	.clk(clk),
    	.q(sout[i-1])
    );

  end
  endgenerate

  endmodule

  module primitive_carry_in(
	datac,
	cout
);

input datac;
output cout;
localparam dt = "off";

cyclonev_lcell_comb #(
  .dont_touch(dt)
  ) mycarryin (
                             .dataa(),
                             .datab(),
                             .datac(datac),
                             .datad(),
                             .datae(),
                             .dataf(),
                             .datag(),
                             .cin(0),
                             .sharein(),
                             .combout(),
                             .sumout(),
                             .cout(cout)
);

/*
localparam [63:0] m;
localparam f0=16'h0F0F;
localparam f1=16'h0F0F;
localparam f2=16'h0;
localparam f3=16'h0;
m[15:0]=f0;
m[31:16]=f1;
m[47:32]=f2;
m[63:48]=f3;
*/


defparam mycarryin.lut_mask=64'h000000000F0F0F0F;


endmodule



module primitive_carry(
	a,
	b,
	cin,
	cout,
	s
);

input a,b,cin;
output s,cout;
localparam dt = "off";

cyclonev_lcell_comb #(
  .dont_touch(dt)
  ) mycarry (
                             .dataa(),
                             .datab(b),
                             .datac(a),
                             .datad(),
                             .datae(),
                             .dataf(),
                             .datag(),
                             .cin(cin),
                             .sharein(),
                             .combout(),
                             .sumout(s),
                             .cout(cout)
);

defparam mycarry.lut_mask=64'hF0F0F0F033333333;
//defparam mycell.sum_lutc_input=cin;
endmodule

module primitive_ff(
	s,
	clk,
	q
);

input s,clk;
output q;

cyclonev_ff myff (
    .d(s),
    .clk(clk),
    .clrn(),
    .aload(),
    .sclr(),
    .sload(),
    .asdata(),
    .ena(),
    .devclrn(),
    .devpor(),
    .q(q)
);

endmodule

module CARRY_CHAIN_LPM(
  a,b,cin,cout,s,clock,clken,aclr
  );

  parameter width = 3;
  parameter pipeline = 0;
  //next are adder specific to force carry chain
  localparam lpm_type = "lpm_add_sub";
  localparam lpm_width = width;
  localparam lpm_direction = "ADD";
  localparam lpm_representation = "UNSIGNED";
  localparam lpm_pipeline = pipeline;
  localparam lpm_hint = "ONE_INPUT_IS_CONSTANT=YES,CIN_USED=YES,MAXIMIZE_SPEED=10";

  input [lpm_width-1:0] a, b;
  input cin;
  output cout;
  output [lpm_width-1:0] s;
  input clock;
  input clken;
  input aclr;

  lpm_add_sub #(
    .lpm_type(lpm_type),
    .lpm_width(lpm_width),
    .lpm_direction(lpm_direction),
    .lpm_representation(lpm_representation),
    .lpm_pipeline(lpm_pipeline),
    .lpm_hint(lpm_hint)

    ) ADD (

    .dataa(a),
    .datab(b),
    .cin(cin),
    .clock(clock),
    .clken(clken),
    .aclr(aclr),
    .result(s),
    .cout(cout)
    //.overflow(0)
    //.add_sub(0)
    );

endmodule


module CARRY_ONE(
  a,b,cin,cout,s
  );

  parameter width = 3;
  //next are adder specific to force carry chain
  localparam lpm_type = "lpm_add_sub";
  localparam lpm_width = width;
  localparam lpm_direction = "ADD";
  localparam lpm_representation = "UNSIGNED";
  localparam lpm_pipeline = 0;
  localparam lpm_hint = "ONE_INPUT_IS_CONSTANT=YES,CIN_USED=YES,MAXIMIZE_SPEED=10";

  input [lpm_width-1:0] a, b;
  input cin;
  output cout;
  output [lpm_width-1:0] s;

  lpm_add_sub #(
    .lpm_type(lpm_type),
    .lpm_width(lpm_width),
    .lpm_direction(lpm_direction),
    .lpm_representation(lpm_representation),
    .lpm_pipeline(lpm_pipeline),
    .lpm_hint(lpm_hint)

    ) ADD (

    .dataa(a),
    .datab(b),
    .cin(cin),
    .result(s),
    .cout(cout)
    );

endmodule
