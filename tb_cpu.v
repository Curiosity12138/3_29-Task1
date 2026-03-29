`timescale 1ns / 1ps

module tb_cpu;
reg clk;
reg rst_n;

cpu_top u_cpu(
    .clk(clk),
    .rst_n(rst_n)
);

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

initial begin
    rst_n = 0;
    #20;
    rst_n = 1;
    #200;
    $stop;
end

endmodule