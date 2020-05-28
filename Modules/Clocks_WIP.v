module DPLL (
  clk,
  phase_change_sign,
  state
  );

//parameters 
parameter N_clocks=3;

//inouts
inout clk;

//input
input phase_change_sign;

//output
output state;

//local parameters
localparam up=1'b1, dn=1'b0;

//local regs

//local wires

//dynamic PLL logic

input FPGA_CLK1_50; // The DE0-Nano-SOC's on-board 50 MHz clock pin that I've chosen
wire clk0; //200MHZ clock; set through PLL megafunction, similar to below
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
reg node=0;
reg wren;
reg [4-1:0] state;
localparam LOCKING=4'b0000, ASSERT_CNT=4'b0001, ASSERT_EN=4'b0010,
                  CHANGING_PHASE=4'b0100, DONE=4'b1000,
                  WAIT_1=4'b0110, WAIT_2=4'b1100;

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
