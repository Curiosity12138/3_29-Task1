module regfile(
    input  wire        clk,
    input  wire [4:0]  raddr1,
    output reg  [31:0] rdata1,
    input  wire [4:0]  raddr2,
    output reg  [31:0] rdata2,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata
);

reg [31:0] rf [31:0];

// 读端口1
always @(*) begin
    if(raddr1 == 5'd0)
        rdata1 = 32'd0;
    else
        rdata1 = rf[raddr1];
end

// 读端口2
always @(*) begin
    if(raddr2 == 5'd0)
        rdata2 = 32'd0;
    else
        rdata2 = rf[raddr2];
end

// 写端口
always @(posedge clk) begin
    if(we && waddr != 5'd0) begin
        rf[waddr] <= wdata;
    end
end

endmodule