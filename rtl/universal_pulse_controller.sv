// universal_pulse_controller.sv
// COPYRIGHT (c) 2026 Jonathan Reed 
// CODE LICENSE: AGPL-3.0
`timescale 1ns/1ps

module universal_pulse_controller # (
    parameter int DATA_WIDTH = 64
)(
    input  logic                     clk,           
    input  logic                     rst_n,         
    input  logic                     trigger,       
    
    input  logic [DATA_WIDTH-1:0]    cfg_start_freq,  
    input  logic signed [DATA_WIDTH-1:0] cfg_chirp_step, // SIGNED for true direction universality
    input  logic [31:0]              cfg_target_steps,
    
    output logic [DATA_WIDTH-1:0]    out_freq,  
    output logic                     sweep_done  
);

    logic [DATA_WIDTH-1:0] freq_reg;
    logic [31:0]           step_counter;
    
    enum logic [1:0] {IDLE, SWEEP, DONE} state;

    assign out_freq   = (state == SWEEP) ? freq_reg : {DATA_WIDTH{1'b0}};
    assign sweep_done = (state == DONE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            freq_reg     <= '0;
            step_counter <= '0;
        end else begin
            case (state)
                IDLE: begin
                    freq_reg     <= cfg_start_freq;
                    step_counter <= '0;
                    if (trigger) begin
                        state <= SWEEP;
                    end
                end
                
                SWEEP: begin
                    if (step_counter >= cfg_target_steps - 1) begin
                        state <= DONE;
                    end else begin
                        step_counter <= step_counter + 1;
                        freq_reg     <= freq_reg + cfg_chirp_step; 
                    end
                end
                
                DONE: begin
                    if (!trigger) begin
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
