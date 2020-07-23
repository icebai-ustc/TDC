`include "CarryChains.v"
`include "Memory.v"
`include "Clocks.v"
`include "DelayLines.v"

module TDC(
  input FPGA_CLK1_50,
  input [1:0]	KEY,
  inout [6:0] GPIO
);
assign GPIO[0]=KEY[0];
assign GPIO[1]=KEY[1];
assign GPIO[2]=FPGA_CLK1_50;
assign GPIO[3]=clk0;
assign GPIO[4]=clk1;
assign GPIO[5]=clk2;

wire signal_in;

button Pulse (
  .clk(clk0),
  .in(level),
  .out(signal_in)
);

wire dpll_done /*synthesis keep*/;

reg phase_en /*synthesis preserve*/;
wire phase_done;
wire locked;
wire clk0;//200MHZ clock
wire clk1;//50MHz clock
wire clk2;//50MHZ shifted from clk1 by 89ps increments
wire scanclk /*synthesis keep*/;
assign scanclk = FPGA_CLK1_50;

PLL_Dynamic_2 PLL (
  .refclk(FPGA_CLK1_50),
  .phase_en(phase_en),
  .scanclk(scanclk),
  .updn(1'b1),
  .cntsel(5'b00010),
  .outclk_0(clk0),
  .outclk_1(clk1),
  .outclk_2(clk2),
  .locked(locked),
  .phase_done(phase_done)
);

localparam LOCKING = 1, ASSERT = 2, CHANGING_PHASE = 3, DONE = 4, WAIT_1 = 5, WAIT_2 =6, WAIT_PHASE=7;
reg [2:0] state;
always @(posedge scanclk) begin
  if (change_phase) begin
    state<=LOCKING;
  end
  else
    case(state)
      LOCKING: begin
        if (locked) begin
          state<=ASSERT; //if PLL has locked, set cntsel high
        end
        else begin
          state<=LOCKING; //else wait
        end
      end
      ASSERT: begin
        phase_en<=1;
        state<=WAIT_1;
      end
      WAIT_1: begin
        state<=WAIT_2;
      end
      WAIT_2: begin
        state<=CHANGING_PHASE;
      end
      CHANGING_PHASE: begin
        if (!phase_done) begin
          phase_en<=0;
          state<=WAIT_PHASE;
        end
        else begin
          state<=CHANGING_PHASE;
        end
      end
      WAIT_PHASE: begin
        if (phase_done) begin
          state<=DONE;
        end
        else begin
          state<=WAIT_PHASE;
        end
      end
      DONE: begin
        state<=DONE;
      end
      default: state = DONE;
    endcase
end

assign dpll_done = (state == DONE);

localparam N=256; //number of carries
localparam T=512; //number of phase changes
wire [N-1:0] sout; //reg out wire from carrychain
wire [N-1:0] a = {N{1'b0}} /*synthesis keep*/;
wire [N-1:0] b = {N{1'b1}} /*synthesis keep*/;

CarryChain #(N) MyCarry (
    .a(a),
    .b(b),
    .cin(signal_in),
    .sout(sout),
    .clk(clk2), //measuring on edge of phase shifted clock,
    .ena(reg_enable),
    .clr(reg_clr)
);

//wire memclk = (~clk2)|(estate==AFTER_PULSE);
reg [$clog2(T):0] resp_addr;
 RAM_response #(
  .N_RESPONSE_BITS_PER_WORD(N),
  .N_RESPONSE_WORDS(T),
  .hint("ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=TDC")
  ) MyResponse (
  .clock(clk1), //why is this being measured on clk1? should be on clk later than clk2 for regs to settle?
  .response(sout),
  .resp_addr(resp_addr),
  .write(mem_enable)
);

wire reg_enable = (estate == SEND_TDC_PULSE);//|(estate==CLR_REG); //or clr reg since enable highest priority
wire reg_clr = estate == CLR_REG;
wire mem_enable = estate == TO_MEM;
wire change_phase = estate == INCREMENT_PHASE; //only send pulse to change phase when ready to
wire level = estate == SEND_TDC_PULSE;
//now write logic to increment phase, read from TDC, and cycle thru phases
reg [3:0] estate;
wire start_exp;
button Pulse1 (
  .clk(clk1),
  .in(~KEY[0]),
  .out(start_exp)
);
localparam INIT=1, WAIT=2, INCREMENT_PHASE=3, SEND_TDC_PULSE=4, TO_MEM=5, CLR_REG=6;
always @(posedge clk1) begin
    case(estate)
      INIT: begin
        if (start_exp) begin
          estate<=INCREMENT_PHASE;
        end else begin
          estate<=INIT;
        end
      end
      INCREMENT_PHASE: begin
        estate<=WAIT;
      end
      WAIT: begin
        if (dpll_done && resp_addr<(T-1)) begin
          resp_addr<=resp_addr+1;
          estate<=SEND_TDC_PULSE;
        end
        else begin
          estate<=WAIT;
        end
      end
      SEND_TDC_PULSE: begin
        estate<=TO_MEM;
      end
      TO_MEM: begin
        estate<=CLR_REG;
      end
      CLR_REG: begin
        estate<=INCREMENT_PHASE;
      end
      default: estate=INIT;
    endcase
end
endmodule
