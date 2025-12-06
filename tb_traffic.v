// tb_traffic.v - Testbench for traffic_light with pedestrian button
`timescale 1ns/1ps

module tb_traffic;
    reg clk;
    reg rst_n;
    reg ped_button;
    wire [2:0] ns;
    wire [2:0] ew;
    wire ped_walk;

    // instantiate DUT
    traffic_light dut (
        .clk(clk),
        .rst_n(rst_n),
        .ped_button(ped_button),
        .ns(ns),
        .ew(ew),
        .ped_walk(ped_walk)
    );

    // clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // waveform dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_traffic);
        $dumpvars(0, dut);
    end

    // stimulus
    initial begin
        // reset
        ped_button = 0;
        rst_n = 0;
        #20;
        rst_n = 1;

        // wait a bit, then press ped button briefly (simulate a push)
        #180;        // at time 200ns total
        ped_button = 1;
        #20;
        ped_button = 0;

        // run long enough to see the request served in a future NS_GREEN
        #3000;

        $display("Simulation finished");
        $finish;
    end

endmodule
