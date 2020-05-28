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
