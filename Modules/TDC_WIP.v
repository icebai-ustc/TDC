module TDC(
  FPGA_CLK1_50
  );

//inputs and clock wires
input FPGA_CLK1_50; // A DE0-Nano-SOC's on-board 50 MHz clock
wire clk0; //200MHZ clock
wire clk1; //51MHz clock
wire clk2; //51MHZ shifted from clk1 by 78ps increments

//this block controls a single-bit phase shift memory
//used to choose positive or negative DPLL shift
//on rising edge of clk0
wire updn;
RAM_reset MySign (
    .clock(clk0),
    .reset(updn)
);

//this block instantiates dynamic phase lock loop
//and associated finite state machine for controlling
//when the PLL has been shifted in phase
reg cntsel=5'b00001;
reg change_phase = 0; //boolean, to be controlled later
wire dpll_done; //also boolean, to be controlled later

DPLL MyDPLL (
    .refclk(FPGA_CLK1_50),
    .scanclk(FPGA_CLK1_50),
    .clk0(clk0),
    .clk1(clk1),
    .clk2(clk2),
    .cntsel_in(cntsel),
    .updn_in(updn),
    .change_phase(change_phase),
    .dpll_done(dpll_done)
);

//now let's setup the carry chain
localparam N=16;
reg [N-1:0] a=16'h0000;
reg [N-1:0] b=16'hFFFF;
wire [N-1:0] s; //sum out
wire signal_in; //signal being measured

//TDC instance calls
CarryChain #(N) MyCarry (
    .a(a),
    .b(b),
    .cin(signal_in),
    .sout(s),
    .clk(clk2) //measuring on edge of phase shifted clock
);


//and let's instantiate memory for the carry chain regs
localparam T = 8; //number of times we readout the chain
reg carry_wren=1; //write enable, to be controlled later
reg [$clog2(T)-1:0] carry_addr;

RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(N),
  .N_RESPONSE_WORDS(T),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=TDC")
  ) MyResponse (
  .clock(clk1), //why is this being measured on clk1?
  .response(s),
  .resp_addr(carry_addr),
  .write(carry_wren)
);


//now we have to setup the dynamical system being measured
//as well as control when the DPLL is phase shifted
//and finally include memory readout logic
