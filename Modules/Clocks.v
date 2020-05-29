module DPLL (
  refclk,
  scanclk,
  clk0,
  clk1,
  clk2,
  cntsel_in,
  updn_in,
  change_phase,
  dpll_done
  );

//parameters

//input
input refclk; //reference clock
input scanclk; //scan clock
input updn_in; //0:neg, 1:pos
input [5-1:0] cntsel_in;//5'b00001 for 1/8 shift
input change_phase; //boolean for FSM

//output
output done; //for FSM
output clk0; //200mhz
output clk1; //51mhz
output clk2; //51mhz shifted phase

//local parameters
localparam up=1'b1, dn=1'b0;
localparam LOCKING=4'b0000, ASSERT_CNT=4'b1000, ASSERT_EN=4'b0010,
                  CHANGING_PHASE=4'b0100, DONE=4'b0001,
                  WAIT_1=4'b0110, WAIT_2=4'b1100;
//local regs
reg phase_en; //must be high at least 2 scanclk cycles
reg updn;
reg [5-1:0] cntsel;
reg [4-1:0] state; //for FSM
reg [4-1:0] next_state;

//local wires
wire phase_done; //when changing over
wire locked; //Lock the fractional PLL to the reference clock before you perform dynamic phase shifts
wire dpll_done = state == DONE;
//dynamic PLL instance
PLL_Dynamic PLL (
  .refclk(refclk),
	.rst(0),
  .phase_en(phase_en),
  .scanclk(scanclk),
  .updn(updn),
  .cntsel(cntsel),
  .phase_done(phase_done),
	.outclk_0(clk[0]),
	.outclk_1(clk[1]),
  .outclk_2(clk[2]),
  .locked(locked)
);

//dynamic PLL logic

reg [4-1:0] state;
localparam LOCKING=4'b0000, ASSERT_CNT=4'b1000, ASSERT_EN=4'b0010,
                  CHANGING_PHASE=4'b0100, DONE=4'b0001,
                  WAIT_1=4'b0110, WAIT_2=4'b1100;

//FSM for changing phase
always @(posedge scanclk) begin
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
        cntsel<=cntsel_in;
        updn<=updn_in;
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
        next_state<=DONE;
      end
    endcase
end

endmodule
