module DPLL(
  FPGA_CLK1_50;
  );

input FPGA_CLK1_50;
output clk0;

inout updn;

PLL_Dynamic PLL (
  .refclk(FPGA_CLK1_50),
	.rst(0),
  .phase_en(phase_en),
  .scanclk(FPGA_CLK1_50),
  .updn(updn),
  .cntsel(cntsel),
  .phase_done(phase_done),
	.outclk_0(clk0),
	.outclk_1(clk1),
  .outclk_2(clk2),
  .locked(locked)
);

endmodule


module TDC(
  FPGA_CLK1_50
  );

//dynamic PLL logic

input FPGA_CLK1_50; // A DE0-Nano-SOC's on-board 50 MHz clock
wire clk0; //200MHZ clock
wire clk1; //51MHz clock
wire clk2; //51MHZ shifted from clk1 by 78ps increments
reg phase_en; //must be high at least 2 scanclk cycles
reg updn=up; //shift phase
localparam up=1'b1, dn=1'b0;
reg [5-1:0] cntsel=5'b00001; //reg for using
//wire [5-1:0] cntsel;//=5'b00000; //increment by 78ps
wire phase_done;
wire locked; //Lock the fractional PLL to the reference clock before you perform dynamic phase shifts
reg [4-1:0] last_state;
wire sign_shift;
reg stored_sign_shift;
RAM_reset Select_Sign (
    .clock(clk0),
    .reset(sign_shift)
);
always @(posedge clk0) begin
  if (~sign_shift) stored_sign_shift<=up; //default 0 for positive
  else stored_sign_shift<=dn;
end
reg [3-1:0] addr=0; //7 possible phase shifts
reg node=1;
reg wren;
//FSM for changing phase
always @(posedge clk1) begin
  if (change_phase) begin
    state<=LOCKING;
  end
  else
    case(state)
      WAIT_1: begin
        state<=WAIT_2;
      end
      WAIT_2: begin
        state<=next_state;
      end
      LOCKING: begin
        if (locked) begin
          state<=ASSERT_CNT; //if PLL has locked, set cntsel high
        end
        else begin
          state<=LOCKING; //else wait
        end
      end
      ASSERT_CNT: begin
        cntsel<=5'b00001;
        updn<=stored_sign_shift;
        next_state<=ASSERT_EN;
        state<=WAIT_1;
      end
      ASSERT_EN: begin
        phase_en<=1;
        next_state<=CHANGING_PHASE;
        state<=WAIT_1;
      end
      CHANGING_PHASE: begin
        if (!phase_done) begin
          phase_en<=0;
          state<=DONE;
        end
        else begin
          state<=CHANGING_PHASE;
          //state<=WAIT_1; //being safe; could state<=CHANGING_PHASE
          //next_state<=CHANGING_PHASE;
        end
      end
      DONE: begin
        state<=DONE;
      end
    endcase
end

/*always @(negedge clk2 or posedge clk1) begin
  if (next_exp==MEASURE & ~sign_shift) begin
    wren<=1;
  end
  if (exp==MEASURE & sign_shift)
end*/
always @(clk2) begin

end

reg change_phase;
//control logic for experiment
//let's increment phase shift and measure over time
always @(posedge clk1) begin
  case(exp)
    RESET_PHASE: begin
      //wren<=0;
      if (addr==3'b111) begin
        exp<=EXP_DONE;
      end
      else begin
        change_phase<=1;
        exp<=WAIT_PHASE;
        addr<=addr+1;
      end
    end
    WAIT_PHASE: begin
      change_phase<=0;
      if (state==DONE) begin
        node<=1;
        exp<=MEASURE;
      end
      else begin
        exp<=WAIT_PHASE;
      end
    end
    MEASURE: begin
      node<=0;
      exp<=RESET_PHASE;
    end
  endcase
end

//always @(negedge clk2) begin
  //if (exp==MEASURE) wren<=1;
  //else wren<=0;
//end

//dynamics for experiment
//always @(posedge clk1) begin
  //if (exp!=EXP_DONE & last_state==CHANGING_PHASE) begin
    //node<=0;
  //end
  //else node<=0;
//end

PLL_Dynamic PLL (
  .refclk(FPGA_CLK1_50),
	.rst(0),
  .phase_en(phase_en),
  .scanclk(FPGA_CLK1_50),
  .updn(updn),
  .cntsel(cntsel),
  .phase_done(phase_done),
	.outclk_0(clk0),
	.outclk_1(clk1),
  .outclk_2(clk2),
  .locked(locked)
);


reg [4-1:0] state;
localparam LOCKING=4'b0000, ASSERT_CNT=4'b0001, ASSERT_EN=4'b0010,
                  CHANGING_PHASE=4'b0100, DONE=4'b1000,
                  WAIT_1=4'b0110, WAIT_2=4'b1100;
reg [3-1:0] exp;
localparam RESET_PHASE=3'b001, WAIT_PHASE=3'b010, MEASURE=3'b100, EXP_DONE=3'b000;

//carrychain logic
localparam N=16;
reg [N-1:0] a=16'h0000;
reg [N-1:0] b=16'hFFFF;
wire [N-1:0] s; //sum out

//instance calls
//TDC instance
wire node_wire;
assign node_wire=node;
CarryChain #(N) MyCarry (
    .a(a),
    .b(b),
    .cin(node_wire),
    .sout(s),
    .clk(clk2)
);
//memory for checking node increments
RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(1),
  .N_RESPONSE_WORDS(8),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=Node")
  ) R (
  .clock(clk1),
  .response(node),
  .resp_addr(addr),
  .write(wren)
);
//memory for storing TDC
RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(N),
  .N_RESPONSE_WORDS(8),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=TDC")
  ) RR (
  .clock(clk1),
  .response(s),
  .resp_addr(addr),
  .write(wren)
);

endmodule




module TDC_dont_touch(
  FPGA_CLK1_50
  );

//dynamic PLL logic

input FPGA_CLK1_50; // A DE0-Nano-SOC's on-board 50 MHz clock
wire clk0; //200MHZ clock
wire clk1; //51MHz clock
wire clk2; //51MHZ shifted from clk1 by 78ps increments
reg phase_en; //must be high at least 2 scanclk cycles
reg updn=1'b1; //shift up in phase
wire [5-1:0] cntsel;//=5'b00000; //increment by 78ps
wire phase_done;
wire locked; //Lock the fractional PLL to the reference clock before you perform dynamic phase shifts

wire reset_input;
RAM_reset Reset_Memory (
    .clock(clk0),
    .reset(reset_input)
);
reg mem_reset;
reg [3-1:0] addr=0;
reg node;
//wire node=clk2 /*synthesis keep*/;
always @(posedge clk1) begin
  node<=~node;
  mem_reset<=~reset_input;
  if (mem_reset) state<=IDLE;
  else
    case(state)
      IDLE: begin
        if (locked) begin
          state<=CHANGING_PHASE; //if PLL has locked, change phase
          phase_en<=1; //and let phase_en go high
        end
        else state<=IDLE; //else wait
      end
      CHANGING_PHASE: begin
        if (!phase_done) begin //asynchronous to scanclk on falling edge. if 0,
          phase_en<=0; //deassert enable
          state<=MEASURING; //and measure
        end
        else begin
          state<=CHANGING_PHASE; //else wait
          phase_en<=1; //and let enable stay high
        end
      end
      MEASURING: begin
        if (phase_done & wren) state<=DONE;
        else state<=MEASURING; //extra time for the phase_done to go back high
      end
      DONE: state<=DONE; //stay done
    endcase
end

reg wren=0;
always @(state) begin
  if (state==IDLE) begin
    wren<=0;
  end
  if (state==MEASURING) begin
    //addr<=addr+1;
    wren<=1;
  end
  if (state==DONE) begin
    wren<=0;
  end
end

RAM_delay #(5) MyDelay (
  .clock(clk0),
  .delay(cntsel)
  );

PLL_Dynamic PLL (
  //inputs
  .refclk(FPGA_CLK1_50),
	.rst(0),
//Transition from low to high enables dynamic phase shifting, one phase shift
//per transition from low to high.
  .phase_en(phase_en),
//Free running clock from the core in combination with phase_en to enable
//and disable dynamic phase shifting.
  .scanclk(FPGA_CLK1_50),
//Selects dynamic phase shift direction; 1= positive phase shift; 0 = negative
//phase shift. The PLL registers the signal on the rising edge of scanclk.
  .updn(updn),
//Logical Counter Select. Five bits decoded to select one of the C counters
//for phase adjustment. The PLL registers the signal on the rising edge of
//scanclk.
  .cntsel(cntsel),
  //outputs
//When asserted, this port informs the core-logic that the phase adjustment is
//complete and the PLL is ready to act on a possible next adjustment pulse.
//Asserts based on internal PLL timing. Deasserts on the rising edge of
//scanclk.
  .phase_done(phase_done),
	.outclk_0(clk0),
	.outclk_1(clk1),
  .outclk_2(clk2),
  .locked(locked)
);

//want to control dynamic phase shifting with finite state machine
//first, ensure locked is true
//then, let phase_en go high for two scanclk cycles
//this will increment phase shift by 78ps*cntsel
//once phase_done is low, let phase_en go low
//summary:
/*1. Set the updn and cntsel ports.
2. Assert the phase_en port for at least two scanclk cycles. Each phase_en pulse enables one phase shift.
3. Deassert the phase_en port after phase_done goes low.
*/

/*perform experiment by locking, changing phase, &reading out to mem
*/

reg [4-1:0] state;
localparam IDLE=4'b0001, CHANGING_PHASE=4'b0010, MEASURING=4'b0100, DONE=4'b1000;


//carrychain logic
localparam N=16;
reg [N-1:0] a=16'h0000;
reg [N-1:0] b=16'hFFFF;
wire [N-1:0] s; //sum out

//instance calls
//TDC instance
CarryChain #(N) MyCarry (
    .a(a),
    .b(b),
    .cin(node),
    .sout(s),
    .clk(clk2)
);
//memory for checking node increments
RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(3),
  .N_RESPONSE_WORDS(8),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=Node")
  ) R (
  .clock(clk1),
  .response(node),
  .resp_addr(addr),
  .write(wren)
);
//memory for storing TDC
RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(N),
  .N_RESPONSE_WORDS(8),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=TDC")
  ) RR (
  .clock(clk1),
  .response(s),
  .resp_addr(addr),
  .write(wren)
);

endmodule




module TDC_single_shift(
  FPGA_CLK1_50
  );

input FPGA_CLK1_50;          // A DE0-Nano-SOC's on-board 50 MHz clock
wire [1:0] pll_out;

PLL2 PLL (
  .refclk(FPGA_CLK1_50),
	.rst(0),
	.outclk_0(pll_out[0]),
	.outclk_1(pll_out[1])
);

//PLL1 is offset from PLL2 by 250ps
//we want a bit to go high at posedge PLL1
//and then measure it using a TDC on PLL2

//carrychain logic
localparam N=16;
reg [N-1:0] a=16'h0000;
reg [N-1:0] b=16'hFFFF;
wire [N-1:0] s; //sum out
//control logic
reg done=0;
reg [2:0] node;
//just incrementing a bit
always @(posedge pll_out[0]) begin
  if (!done) begin
    node<=node+1;
    if (node==7) done<=1;
  end
end
//instance calls
//TDC instance
CarryChain #(N) MyCarry (
    .a(a),
    .b(b),
    .cin(node),
    .sout(s),
    .clk(pll_out[1])
);
//memory for checking node increments
RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(3),
  .N_RESPONSE_WORDS(8),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=Node")
  ) R (
  .clock(pll_out[0]),
  .response(node),
  .resp_addr(node),
  .write(~done)
);
//memory for storing TDC
RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(N),
  .N_RESPONSE_WORDS(8),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=TDC")
  ) RR (
  .clock(pll_out[0]),
  .response(s),
  .resp_addr(node),
  .write(~done)
);
endmodule


//module for carry chain using primitives
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


//TDC using single carry-bit; test case
module TDC_bit(
  FPGA_CLK1_50
);
input FPGA_CLK1_50;          // A DE0-Nano-SOC's on-board 50 MHz clock
wire [1:0] pll_out;

PLL2 PLL0 (
  .refclk(FPGA_CLK1_50),
	.rst(0),
	.outclk_0(pll_out[0]),
	.outclk_1(pll_out[1])
);

//PLL1 is offset from PLL2 by 250ps
//we want a bit to go high at posedge PLL1
//and then measure it using a TDC on PLL2

reg a=0;
reg b=1;
reg [2:0] node=0;
reg done=0;

wire s;
wire cout0;
wire cin;
wire cout;

always @(posedge pll_out[0]) begin
	if (!done) begin
		node<=node+1;
		if (node==7) done<=1;
	end
end

//code for a single TDC
RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(3),
  .N_RESPONSE_WORDS(8),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=R")
  ) R (
  .clock(pll_out),
  .response(s_to_mem),
  .resp_addr(node),
  .write(~done)
);

primitive_carry_in mycarry_in (
	.datac(node),
	.cout(cout0),
);

primitive_carry mycarry (
	.a(a),
	.b(b),
	.cin(cout0),
	.cout(cout),
	.s(s)
);

wire s_to_mem;

primitive_ff myff(
	.s(s),
	.clk(pll_out[1]),
	.q(s_to_mem)
);

///////////////////////2nd bit
RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(3),
  .N_RESPONSE_WORDS(8),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=R")
  ) R1 (
  .clock(pll_out),
  .response(s_to_mem2),
  .resp_addr(node),
  .write(~done)
);

wire cout2;
wire s2;
primitive_carry mycarry2 (
	.a(a),
	.b(b),
	.cin(cout),
	.cout(cout2),
	.s(s2)
);

wire s_to_mem2;

primitive_ff myff2(
	.s(s2),
	.clk(pll_out[1]),
	.q(s_to_mem2)
);

endmodule

//primitives modules

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




module TDC_r(
  FPGA_CLK1_50
);
input FPGA_CLK1_50;          // A DE0-Nano-SOC's on-board 50 MHz clock
wire pll_out;

PLL PLL0 (
  .refclk(FPGA_CLK1_50),
	.rst(0),
	.outclk_0(pll_out)
);

parameter N=3;
parameter T=16;
parameter N_CHALLENGES=16;
parameter N_SYNTH=1;
parameter N_CHALLENGE_BITS_PER_WORD=N;
parameter N_RESPONSE_WORDS=N_CHALLENGES;
parameter N_RESPONSE_BITS_PER_WORD=N;
localparam resp_addr_width = $clog2(N_RESPONSE_WORDS);
localparam chal_addr_width = $clog2(N_CHALLENGES);
localparam chal_addr_starting_value = 0;
reg [chal_addr_width-1:0] chal_addr = chal_addr_starting_value;

wire [N_CHALLENGE_BITS_PER_WORD-1:0] challenge;

localparam resp_addr_starting_value = 0;
reg [N_RESPONSE_BITS_PER_WORD-1:0] response;
reg [resp_addr_width-1:0] resp_addr = resp_addr_starting_value;


RAM_reset Reset_Memory (
    .clock(pll_out),
    .reset(reset_input)
);

RAM_challenge #(
  .N(N_CHALLENGE_BITS_PER_WORD),
  .N_CHALLENGES(N_CHALLENGES)
  ) Challenge_Memory (
  .clock(pll_out),
  .challenge(challenge),
  .chal_addr(chal_addr)
);

RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(N_RESPONSE_BITS_PER_WORD),
  .N_RESPONSE_WORDS(N_RESPONSE_WORDS),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=RESP")
  ) Response_Memory (
  .clock(pll_out),
  .response(response),
  .resp_addr(resp_addr),
  .write(~done)
);

RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(T),
  .N_RESPONSE_WORDS(N_RESPONSE_WORDS),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=N1")
  ) rcarry1 (
  .clock(pll_out),
  .response(sumresponse1),
  .resp_addr(resp_addr),
  .write(~done)
);

RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(T),
  .N_RESPONSE_WORDS(N_RESPONSE_WORDS),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=N2")
  ) rcarry2 (
  .clock(pll_out),
  .response(sumresponse2),
  .resp_addr(resp_addr),
  .write(~done)
);

RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(T),
  .N_RESPONSE_WORDS(N_RESPONSE_WORDS),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=N3")
  ) rcarry3 (
  .clock(pll_out),
  .response(sumresponse3),
  .resp_addr(resp_addr),
  .write(~done)
);

wire [2:0] delay;
reg enable=1;
reg done = 0;
wire reset_input; //goes in memory
reg mem_reset; //takes memory value
parameter MEASURE_TIME=1;
parameter WAIT_TIME=3;
localparam EXPERIMENT_TIME = (MEASURE_TIME+WAIT_TIME+1)*N_CHALLENGES;
localparam EXPE_WIDTH = $clog2(EXPERIMENT_TIME);
reg [EXPE_WIDTH-1:0] experiment_time;

always @(posedge pll_out) begin
  mem_reset<=~reset_input;
  if (mem_reset) begin
    experiment_time <= 0;
		chal_addr <= -1;
    resp_addr <= 0;
		enable <= 1;
    done<=0;
  end else if (experiment_time != N_CHALLENGES*(WAIT_TIME+MEASURE_TIME)-1) begin
	  if (experiment_time%(WAIT_TIME+MEASURE_TIME) == 0) begin
	    chal_addr <= chal_addr + 1;
    end else if (experiment_time%(WAIT_TIME+MEASURE_TIME)< WAIT_TIME-1) begin
      enable<=1;
	  end else if (experiment_time%(WAIT_TIME+MEASURE_TIME) == WAIT_TIME-1) begin
		  enable <= 0;
	  end else begin
      resp_addr<=resp_addr+1;
      enable<=0;
    end
		experiment_time <= experiment_time + 1;
	end else begin
	  done <= 1;
	end
end

wire enable_delayed;
//CopyLine #(1) DLR (enable, enable_delayed);
AdjustableDelayLine DLR (
  .in(enable),
  .out(enable_delayed),
  .multiwire(delay)
);

wire [N-1:0] node /*synthesis keep*/;
wire [N-1:0] node_internal /*synthesis keep*/;

assign node_internal[0] = ~node[2];
assign node[0] = enable ? challenge[0] : node_internal[0];

assign node_internal[1] = ~node[0];
assign node[1] = enable ? challenge[1] : node_internal[1];

assign node_internal[2] = ~node[1];
assign node[2] = enable ? challenge[2] : node_internal[2];

reg [T-1:0] sum1 /*synthesis preserve*/;
reg [T-1:0] sum2 /*synthesis preserve*/;
reg [T-1:0] sum3 /*synthesis preserve*/;
wire [T-1:0] a = 16'h0 /*synthesis keep*/;
wire [T-1:0] b = 16'hFFFF /*synthesis keep*/;
wire [T-1:0] s1;// /*synthesis keep*/;
wire [T-1:0] s2;// /*synthesis keep*/;
wire [T-1:0] s3;// /*synthesis keep*/;
wire [T-1:0] cin1;
wire [T-1:0] cin2;
wire [T-1:0] cin3;
assign cin1[0] = node[0];
assign cin2[0] = node[1];
assign cin3[0] = node[2];
wire cout1, cout2, cout3;
reg [T-1:0] sumresponse1, sumresponse2, sumresponse3;

CARRY_ONE #(T) Carry1 (
    .a(a),
    .b(b),
    .s(s1),
    .cin(cin1),
    .cout(cout1)
    );
CARRY_ONE #(T) Carry2 (
    .a(a),
    .b(b),
    .s(s2),
    .cin(cin2),
    .cout(cout2)
    );
CARRY_ONE #(T) Carry3 (
    .a(a),
    .b(b),
    .s(s3),
    .cin(cin3),
    .cout(cout3)
    );

RAM_delay Delay (
  .clock(pll_out),
  .delay(delay)
);

reg [N-1:0] regresponse;
always @(negedge enable_delayed) begin
  sum1<=s1;
  sum2<=s2;
  sum3<=s3;
  regresponse<=node;
end

always @(negedge pll_out) begin
  response <= regresponse;
  sumresponse1<=sum1;
  sumresponse2<=sum2;
  sumresponse3<=sum3;
end

endmodule


/*memory modules*/
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


//delay line module
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
