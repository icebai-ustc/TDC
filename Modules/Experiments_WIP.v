module TDC_using_DPLL(
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

module TDC_using_repressilator(
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

