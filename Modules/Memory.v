module RAM_reset (
  clock,
  reset
  );

input clock;
output reset;

  altsyncram	#(
  	.operation_mode("SINGLE_PORT"),
  	.width_a(1),
  	.widthad_a(1),
  	.numwords_a(1),
  	.clock_enable_input_a("BYPASS"),
  	.lpm_hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=RESET"),
  	.lpm_type("altsyncram"),
  	.outdata_reg_a("CLOCK0"),
  	.power_up_uninitialized("FALSE"),
  	.read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
  	.width_byteena_a(1)
  ) reset_bit (
  	.address_a (1'b0),
  	.clock0 (clock),
  	.q_a (reset),
    .wren_a (0),
  	.address_b (1'b1),
  	.addressstall_a (1'b0),
  	.addressstall_b (1'b0),
  	.byteena_a (1'b1),
  	.byteena_b (1'b1)
  );
endmodule

//challenge RAM module
module RAM_challenge (
  clock,
  challenge,
  chal_addr
  );

parameter N=256;
parameter N_CHALLENGES = 8;
localparam CHAL_ADDR_WIDTH = $clog2(N_CHALLENGES);

input clock;
output [N-1:0] challenge;
input [CHAL_ADDR_WIDTH-1:0] chal_addr;

  altsyncram	#(
  	.operation_mode("SINGLE_PORT"),
  	.width_a(N),
  	.widthad_a(CHAL_ADDR_WIDTH),
  	.numwords_a(N_CHALLENGES),
  	.clock_enable_input_a("BYPASS"),
    .clock_enable_output_a("BYPASS"),
    .intended_device_family("Cyclone V"),
  	.lpm_hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=CHAL"),
  	.lpm_type("altsyncram"),
  	.outdata_reg_a("CLOCK0"),
  	.power_up_uninitialized("FALSE"),
  	.read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
  	.width_byteena_a(1)
  ) challenges (
  	.address_a (chal_addr),
  	.clock0 (clock),
  	.q_a (challenge),
  	.address_b (1'b1),
  	.addressstall_a (1'b0),
  	.addressstall_b (1'b0),
  	.byteena_a (1'b1),
  	.byteena_b (1'b1)
  );
endmodule

//response RAM module
module RAM_response (
  clock,
  response,
  resp_addr,
  write
  );

parameter N_RESPONSE_BITS_PER_WORD = 2;
parameter N_RESPONSE_WORDS = 8;
parameter hint = "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=RESP";
localparam RESP_ADDR_WIDTH = $clog2(N_RESPONSE_WORDS);

input clock;
input [N_RESPONSE_BITS_PER_WORD-1:0] response;
input [RESP_ADDR_WIDTH-1:0] resp_addr;
input write;

  altsyncram	#(
  	.operation_mode("SINGLE_PORT"),
  	.width_a(N_RESPONSE_BITS_PER_WORD),
  	.widthad_a(RESP_ADDR_WIDTH),
  	.numwords_a(N_RESPONSE_WORDS),
  	.clock_enable_input_a("BYPASS"),
  	.lpm_hint(hint),
  	.lpm_type("altsyncram"),
  	.outdata_reg_a("CLOCK0"),
  	.power_up_uninitialized("TRUE"),
  	.read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
  	.width_byteena_a(1),
    .ram_block_type("auto")
  ) responses (
  	.address_a (resp_addr),
  	.clock0 (clock),
  	.data_a (response),
  	.wren_a (write),
  	.address_b (1'b1),
  	.addressstall_a (1'b0),
  	.addressstall_b (1'b0),
  	.byteena_a (1'b1),
  	.byteena_b (1'b1),
  	.clock1 (1'b1)
  );
endmodule

module RAM_delay (
  clock,
  delay
  );

parameter N_delays=3;
input clock;
output [N_delays-1:0] delay;

  altsyncram	#(
  	.operation_mode("SINGLE_PORT"),
  	.width_a(N_delays),
  	.widthad_a(1),
  	.numwords_a(1),
  	.clock_enable_input_a("BYPASS"),
  	.lpm_hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=DELAY"),
  	.lpm_type("altsyncram"),
  	.outdata_reg_a("CLOCK0"),
  	.power_up_uninitialized("FALSE"),
  	.read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
  	.width_byteena_a(1)
  ) reset_bit (
  	.address_a (1'b0),
  	.clock0 (clock),
  	.q_a (delay),
    .wren_a (0),
  	.address_b (1'b1),
  	.addressstall_a (1'b0),
  	.addressstall_b (1'b0),
  	.byteena_a (1'b1),
  	.byteena_b (1'b1)
  );
endmodule
