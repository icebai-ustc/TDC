module CARRY_CHAIN(
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
