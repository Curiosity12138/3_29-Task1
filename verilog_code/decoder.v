module decoder_2_4(
    input  wire [1:0] in,
    output reg  [3:0] out
);
always @(*) begin
    case(in)
        2'b00: out = 4'b0001;
        2'b01: out = 4'b0010;
        2'b10: out = 4'b0100;
        2'b11: out = 4'b1000;
    endcase
end
endmodule

module decoder_4_16(
    input  wire [3:0] in,
    output reg  [15:0] out
);
always @(*) begin
    out = 16'b0;
    out[in] = 1'b1;
end
endmodule

module decoder_5_32(
    input  wire [4:0] in,
    output reg  [31:0] out
);
always @(*) begin
    out = 32'b0;
    out[in] = 1'b1;
end
endmodule

module decoder_6_64(
    input  wire [5:0] in,
    output reg  [63:0] out
);
always @(*) begin
    out = 64'b0;
    out[in] = 1'b1;
end
endmodule