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
