// universal_pulse_testbench.sv
`timescale 1ns/1ps

module universal_pulse_testbench();
    localparam int DW = 64;
    
    logic                      clk = 0;
    logic                      rst_n = 0;
    logic                      trigger = 0;
    logic [DW-1:0]             out_freq;
    logic                      sweep_done;

    logic [DW-1:0]             cfg_start_freq;
    logic signed [DW-1:0]      cfg_chirp_step;
    logic [31:0]               cfg_target_steps;

    universal_pulse_controller #(.DATA_WIDTH(DW)) dut (.*);

    // 10-attosecond resolution clock definition
    always #0.005 clk = ~clk; 

    // Cycle counting variables to bypass $realtime accumulative drift
    longint cycles_elapsed;
    real calculated_duration_fs;
    real diff;

    task run_profile(
        input logic [DW-1:0]        start_f,
        input logic signed [DW-1:0] step_f,
        input logic [31:0]          steps,
        input real                  expected_fs
    );
        begin
            // Step 1: Initialize System State on a clean clock edge
            @(posedge clk);
            rst_n = 0; trigger = 0;
            cfg_start_freq   = start_f;
            cfg_chirp_step   = step_f;
            cfg_target_steps = steps;
            cycles_elapsed   = 0;
            
            // Step 2: Hold reset for 2 full clock cycles
            repeat(2) @(posedge clk);
            rst_n = 1;
            
            // Step 3: Assert trigger synchronously with the clock
            @(posedge clk);
            trigger = 1;
            
            // Step 4: Count execution cycles strictly on every active edge
            while (!sweep_done) begin
                @(posedge clk);
                if (!sweep_done) begin
                    cycles_elapsed = cycles_elapsed + 1;
                end
            end
            
            // Step 5: Deassert trigger and compute values
            trigger = 0;
            calculated_duration_fs = real'(cycles_elapsed) * 0.01; // 1 cycle = 10as = 0.01fs
            
            diff = calculated_duration_fs - expected_fs;
            if (diff < 0) diff = -diff;
            
            $display("--- UNIVERSAL WAVEFORM PROFILE VERIFICATION ---");
            $display("Target Profile Duration: %0.2f fs", expected_fs);
            $display("Measured Cycle Duration: %0.2f fs (Cycles counted: %0d)", calculated_duration_fs, cycles_elapsed);
            
            if (diff < 0.000001)
                $display("STATUS: PASSED - PHASE DETERMINISTIC MATCH ACHIEVED\n");
            else
                $display("STATUS: FAILED - EDGE ACCUMULATION DRIFT DETECTED (Diff: %0.6f fs)\n", diff);
                
            repeat(5) @(posedge clk); // Pipeline flushing delay
        end
    endtask

    initial begin
        // Let simulation settle
        #10;
        
        // Profile 1: Downward Chirp (The original Nitrogen configuration baseline)
        run_profile(64'd70_700_000_000_000, -64'd47_300, 32'd176_894, 1768.94);

        // Profile 2: Upward Chirp (Alternative layout testing true parameterization)
        run_profile(64'd100_000_000_000_000, 64'd20_000, 32'd50_000, 500.00);

        $finish;
    end
endmodule