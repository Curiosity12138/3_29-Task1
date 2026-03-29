`ifndef __DEFINES_V__
`define __DEFINES_V__

// 5条指令 opcode
`define OP_ADD     6'b000000
`define OP_ADDI    6'b000010
`define OP_LD      6'b000100
`define OP_ST      6'b000101
`define OP_BNE     6'b000110

// add.w 的 funct
`define FUNC_ADD_W 6'b000001

`endif

module pc(
    input         clk,
    input         rst_n,
    input  [31:0] npc,
    output reg [31:0] pc
);
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        pc <= 32'd0;
    else
        pc <= npc;
end
endmodule

module inst_rom(
    input  [31:0] addr,
    output [31:0] inst
);

reg [31:0] rom [0:127];
assign inst = rom[addr[6:2]];

initial begin
    rom[0] = 32'h20010005;  // addi $1,$0,5
    rom[1] = 32'h20020003;  // addi $2,$0,3
    rom[2] = 32'h00221801;  // add  $3,$1,$2
    rom[3] = 32'hAC030000;  // st   $3,0($0)
    rom[4] = 32'h8C040000;  // ld   $4,0($0)
    rom[5] = 32'h00000000;  // nop
    rom[6] = 32'h00000000;  // nop
    rom[7] = 32'h00000000;  // nop
    rom[8] = 32'h1422FFFF;  // bne  $1,$2,-1 
end
endmodule

module regfile(
    input         clk,
    input         we,
    input  [4:0]  waddr,
    input  [31:0] wdata,
    input  [4:0]  raddr1,
    input  [4:0]  raddr2,
    output [31:0] rdata1,
    output [31:0] rdata2
);

reg [31:0] regfile [0:31];
integer i; 

assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : regfile[raddr1];
assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : regfile[raddr2];

always @(posedge clk) begin
    if (we && waddr != 5'b0) begin
        regfile[waddr] <= wdata;
    end
end

initial begin
    for (i = 0; i < 32; i = i + 1) begin 
        regfile[i] = 32'b0;
    end
end

endmodule

module alu(
    input  [31:0] a,
    input  [31:0] b,
    input         bne_en,
    output [31:0] res,
    output        zero
);

assign res = bne_en ? 32'd0 : (a + b);
assign zero = (a == b) ? 1'b1 : 1'b0;

endmodule

module data_ram(
    input         clk,
    input         we,
    input  [31:0] addr,
    input  [31:0] wdata,
    output [31:0] rdata
);

reg [31:0] ram [0:127];
integer i; 

assign rdata = ram[addr[6:2]];

always @(posedge clk) begin
    if (we) begin
        ram[addr[6:2]] <= wdata;
    end
end

initial begin
    for (i = 0; i < 128; i = i + 1) begin  
        ram[i] = 32'b0;
    end
end

endmodule

module ctrl(
    input         rst_n,
    input  [5:0]  op,
    input  [5:0]  funct,

    output reg    reg_we,
    output reg    mem_we,
    output reg    mem2reg,
    output reg    alu_src,
    output reg    reg_dst,
    output reg    bne
);

always @(*) begin
    if(!rst_n) begin
        reg_we   = 1'b0;
        mem_we   = 1'b0;
        mem2reg  = 1'b0;
        alu_src  = 1'b0;
        reg_dst  = 1'b0;
        bne      = 1'b0;
    end else begin
        reg_we   = 1'b0;
        mem_we   = 1'b0;
        mem2reg  = 1'b0;
        alu_src  = 1'b0;
        reg_dst  = 1'b0;
        bne      = 1'b0;

        case(op)
            `OP_ADD: begin
                if(funct == `FUNC_ADD_W) begin
                    reg_we   = 1'b1;
                    mem2reg  = 1'b0;
                    alu_src  = 1'b0;
                    reg_dst  = 1'b1;
                end
            end

            `OP_ADDI: begin
                reg_we=1; 
                mem2reg=0; 
                alu_src=1; 
                reg_dst=0; 
                end

            `OP_LD:   begin 
                reg_we=1; 
                mem2reg=1; 
                alu_src=1; 
                reg_dst=0; 
                end

            `OP_ST:   begin 
                mem_we=1; 
                alu_src=1; 
                end

            `OP_BNE:  begin 
                bne=1; 
                alu_src=0; 
                end
                
        endcase
    end
end

endmodule

module cpu_top(
    input clk,
    input rst_n
);

wire [31:0] pc;
wire [31:0] npc;
wire [31:0] pc4;
wire [31:0] inst;

wire [31:0] rdata1;
wire [31:0] rdata2;
wire [31:0] imm_ext;
wire [31:0] alu_b;
wire [31:0] alu_res;
wire        alu_zero;

wire [31:0] dm_rdata;
wire [31:0] wdata;
wire [4:0]  waddr;

wire reg_we;
wire mem_we;
wire mem2reg;
wire alu_src;
wire reg_dst;
wire bne_en;

ctrl u_ctrl(
    .rst_n  (rst_n),
    .op     (inst[31:26]),
    .funct  (inst[5:0]),
    .reg_we (reg_we),
    .mem_we (mem_we),
    .mem2reg(mem2reg),
    .alu_src(alu_src),
    .reg_dst(reg_dst),
    .bne    (bne_en)
);

pc u_pc(
    .clk(clk),
    .rst_n(rst_n),
    .npc(npc),
    .pc(pc)
);

inst_rom u_ir(
    .addr(pc),
    .inst(inst)
);

assign waddr = reg_dst ? inst[15:11] : inst[20:16];
assign wdata = mem2reg ? dm_rdata : alu_res;

regfile u_rf(
    .clk(clk),
    .we(reg_we),
    .waddr(waddr),
    .wdata(wdata),
    .raddr1(inst[25:21]),
    .raddr2(inst[20:16]),
    .rdata1(rdata1),
    .rdata2(rdata2)
);

assign imm_ext = {{16{inst[15]}}, inst[15:0]};
assign alu_b   = alu_src ? imm_ext : rdata2;

alu u_alu(
    .a(rdata1),
    .b(alu_b),
    .bne_en(bne_en),
    .res(alu_res),
    .zero(alu_zero)
);

data_ram u_dr(
    .clk(clk),
    .we(mem_we),
    .addr(alu_res),
    .wdata(rdata2),
    .rdata(dm_rdata)
);

assign pc4 = pc + 32'd4;
wire [31:0] bne_addr = pc4 + (imm_ext << 2);
assign npc = (bne_en & !alu_zero) ? bne_addr : pc4;

endmodule