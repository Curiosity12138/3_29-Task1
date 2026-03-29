//不考虑冲突、支持20条loongarch指令的流水线寄存器

//流水线之间的控制信号命名规则
//从A级传向B的控制信号，最终在C级作用。
//则从A级传到AB之间的流水线寄存器，输入信号为 A_to_C_control
//从AB之间的流水线寄存器传到B级，输出信号为 A_B_to_C_control (若有B=C，则省略为A_B_control)

//各个控制信号命名的前缀代表所在区域
//无区域前缀的控制信号往往为最终直接作用的控制信号

// 目前待定
// reg [31:0] imem[0:63];
// reg [31:0] dmem[0:63];
// dout = imem[addr[7:2]];
// assign DM_Read_data = dmem[addr[5:0]];
// dmem[addr[5:0]] <= Write_data;


module CPU_top(
    input clk,
    input rst//同步复位
  );

  ////IF级
  //IF级的信号
  wire [31:2] Current_PC;
  reg [31:2] Next_PC;
  wire [31:0] IF_Instr;//指令
  wire [1:0] NPC_Opt;//选择信号
  wire [31:2] IF_PC_1;
  wire [31:0] ALU_result;
  wire [31:2] PC_jump;
  wire IF_ID_En;
  wire IF_ID_flush;

  //Current_PC获得
  PC PC(.clk(clk),.rst(rst),.Next_PC(Next_PC),.Current_PC(Current_PC));

  //进行Next_PC的选择
  always@*
  begin
    case(NPC_Opt)
      0:
        Next_PC=IF_PC_1;
      1:
        Next_PC=ALU_result[29:0];
      2:
        Next_PC=PC_jump;
    endcase
  end

  //IF_PC_1计算
  assign IF_PC_1=Current_PC+1;


  //指令取指
  IM IM(.addr(Current_PC),.dout(IF_Instr));//实例化



  ////ID级
  //ID级的信号
  wire [31:0] ID_Instr;
  wire [31:2] ID_PC_1;
  wire [31:2] ID_PC;
  wire [31:0] sign_I16;
  wire [31:0] sign_I26;
  wire [31:0] sign_I12;
  wire [31:0] sign_UI5;
  wire [31:0] extend0_I20;
  wire [31:0] Off;
  wire PC_off_opt;
  wire [4:0] Register_Write_addr;
  reg [31:0] Register_Write_data;
  wire [31:0] WB_Mux_Data;
  wire [31:0] WB_PC_1_extend;
  wire [2:0] Register_Write_Data_Opt;
  wire [4:0] RK_RD;
  wire Register_Read_Opt;
  wire If_Equal;
  wire Register_Write_En;
  wire [31:0] RJ_data;
  wire [31:0] RK_RD_data;
  wire ID_EX_En;
  wire ID_EX_flush;



  //指令译码
  wire [31:26] Opcode_I4=ID_Instr[31:26];
  wire [31:24] Opcode_I3=ID_Instr[31:24];
  wire [31:22] Opcode_I2=ID_Instr[31:22];
  wire [31:18] Opcode_I1=ID_Instr[31:18];
  wire [31:20] Opcode_4R=ID_Instr[31:20];
  wire [31:15] Opcode_3R=ID_Instr[31:15];
  wire [31:10] Opcode_2R=ID_Instr[31:10];
  wire [31:15] Opcode_I2_sp=ID_Instr[31:15];//slli.w,srli.w,srai.w所用
  wire [31:25] Opcode_1R=ID_Instr[31:25];//lu12i.w所用


  wire [19:15] RA=ID_Instr[19:15];
  wire [14:10] RK=ID_Instr[14:10];
  wire [9:5] RJ=ID_Instr[9:5];
  wire [4:0] RD=ID_Instr[4:0];

  wire [17:10] I8=ID_Instr[17:10];
  wire [21:10] I12=ID_Instr[21:10];
  wire [23:10] I14=ID_Instr[23:10];
  wire [25:10] I16=ID_Instr[25:10];
  wire [20:0] I21={ID_Instr[4:0],ID_Instr[25:10]};
  wire [25:0] I26={ID_Instr[9:0],ID_Instr[25:10]};
  wire [14:10] UI5=ID_Instr[14:10];//slli.w,srli.w,srai.w所用
  wire [24:5] I20=ID_Instr[24:5];//用于lu12i.w


  //译码操作
  wire OP_addw=(Opcode_3R==17'h20);
  wire OP_subw=(Opcode_3R==17'h22);
  wire OP_addiw=(Opcode_I2==10'hA);
  wire OP_ldw=(Opcode_I2==10'hA2);
  wire OP_stw=(Opcode_I2==10'hA6);
  wire OP_beq=(Opcode_I4==6'h16);
  wire OP_bne=(Opcode_I4==6'h17);
  wire OP_b=(Opcode_I4==6'h14);
  wire OP_bl=(Opcode_I4==6'h15);
  wire OP_jirl=(Opcode_I4==6'h13);
  wire OP_slt=(Opcode_3R==17'h24);
  wire OP_sltu=(Opcode_3R==17'h25);
  wire OP_slliw=(Opcode_I2_sp==17'h81);
  wire OP_srliw=(Opcode_I2_sp==17'h89);
  wire OP_sraiw=(Opcode_I2_sp==17'h91);
  wire OP_lu12iw=(Opcode_1R==7'hA);
  wire OP_and=(Opcode_3R==17'h29);
  wire OP_or=(Opcode_3R==17'h2A);
  wire OP_nor=(Opcode_3R==17'h28);
  wire OP_xor=(Opcode_3R==17'h2B);



  //实例化IF_ID_reg
  IF_ID_reg IF_ID_reg(.clk(clk),.rst(rst),.En(IF_ID_En),.flush(IF_ID_flush),.IF_PC_1(IF_PC_1),.Current_PC(Current_PC),
                      .IF_Instr(IF_Instr),.ID_PC_1(ID_PC_1),.ID_Instr(ID_Instr),.ID_PC(ID_PC));


  //PC_jump计算
  assign sign_I26={{6{I26[25]}},I26};
  assign sign_I16={{16{I16[25]}},I16};
  assign sign_UI5 = {27'b0, UI5};
  assign Off=PC_off_opt?sign_I16:sign_I26;
  assign PC_jump=ID_PC+Off;

  //Register_Write_data计算
  always@*
  begin
    case(Register_Write_Data_Opt)
      0:
        Register_Write_data=0;
      1:
        Register_Write_data=1;
      2:
        Register_Write_data=WB_Mux_Data;
      3:
        Register_Write_data=WB_PC_1_extend;
    endcase
  end

  //RK_RD计算
  assign RK_RD=Register_Read_Opt?RD:RK;

  //sign_I12计算
  assign sign_I12={{20{I12[21]}},I12};

  //extend0_I20计算
  assign extend0_I20={I20,12'b0};

  //实例化寄存器
  Register Register(.clk(clk),.rst(rst),.Write_En(Register_Write_En),.Read_rk_rd(RK_RD),
                    .Read_rj(RJ),.Write_addr(Register_Write_addr),.Write_data(Register_Write_data),
                    .Read_rk_rd_data(RK_RD_data),.Read_rj_data(RJ_data));

  //If_Equal生成
  assign If_Equal=(RJ_data==RK_RD_data);





  ////由译码生成控制信号
  wire [2:0] ALU_B_Op;
  wire [3:0] ALUop;
  //声明控制信号
  wire EX_OP_jirl;
  wire EX_OP_slt;
  wire EX_OP_sltu;
  wire EX_Register_Write_Data_to0;
  wire EX_Register_Write_Data_to3;
  wire [2:0] EX_ALU_B_toX;
  wire [3:0] EX_ALUop;
  wire EX_DM_Write_to1;
  wire MEM_DM_Write_to1;
  wire [1:0] WB_Register_Write_Data_toX;
  wire EX_Register_Write_addr_to1;
  wire WB_Register_Write_addr_to1;
  wire EX_Register_Write_to1;
  wire WB_Register_Write_to1;
  wire EX_WB_Op_to1;
  wire WB_WB_Op_to1;


  //NPC_Op控制
  //NPC_to2在ID生成，EX_OP_jirl由OP_jirl传到EX级
  wire NPC_to2=OP_bl|OP_b|(OP_beq&If_Equal)|(OP_bne&~If_Equal);
  assign NPC_Opt=EX_OP_jirl?2'd1:(NPC_to2?2'd2:2'd0);

  //flush控制信号
  assign IF_ID_flush=NPC_to2|EX_OP_jirl;
  assign ID_EX_flush=EX_OP_jirl;

  //Register_Write_Data_Opt信号
  wire slt_En,sltu_En;
  wire EX_Register_Write_Data_to1=((EX_OP_slt&slt_En)|(EX_OP_sltu&sltu_En));
  wire ID_Register_Write_Data_to0=(OP_slt|OP_sltu);
  wire ID_Register_Write_Data_to3=(OP_bl|OP_jirl);

  reg [1:0] EX_Register_Write_Data_toX;//在EX级生成控制信号，再传播
  always@*
  begin
    if(EX_Register_Write_Data_to1)
      EX_Register_Write_Data_toX=1;
    else if(EX_Register_Write_Data_to0)
      EX_Register_Write_Data_toX=0;
    else if(EX_Register_Write_Data_to3)
      EX_Register_Write_Data_toX=3;
    else
      EX_Register_Write_Data_toX=2;
  end
  assign Register_Write_Data_Opt=WB_Register_Write_Data_toX;//在WB级使用


  //PC_off_opt信号
  assign PC_off_opt=(OP_beq|OP_bne);


  //Register_Write_addr_Opt信号
  wire Register_Write_addr_Opt;
  wire ID_Register_Write_addr_to1;
  assign ID_Register_Write_addr_to1=OP_bl;//在ID级产生
  assign Register_Write_addr_Opt=WB_Register_Write_addr_to1;//在WB级使用


  //Register_Read_Opt信号
  assign Register_Read_Opt=OP_stw|OP_bne|OP_beq;


  //Register_Write_En信号
  wire ID_Register_Write_to1=(OP_addw|OP_subw|OP_addiw|OP_ldw|OP_jirl|OP_bl|
                              OP_slt|OP_sltu|OP_slliw|OP_srliw|OP_sraiw|OP_lu12iw|
                              OP_and|OP_or|OP_nor|OP_xor);//在ID级产生
  assign Register_Write_En=WB_Register_Write_to1;//在WB级使用


  //ALU_B_Op
  reg [2:0] ID_ALU_B_toX;//在ID级产生
  always@*
  begin
    if(OP_lu12iw)
      ID_ALU_B_toX=1;
    else if(OP_addiw|OP_ldw|OP_stw)
      ID_ALU_B_toX=2;
    else if(OP_beq|OP_bne|OP_jirl)
      ID_ALU_B_toX=3;
    else if(OP_slliw|OP_srliw|OP_sraiw)
      ID_ALU_B_toX=4;
    else
      ID_ALU_B_toX=0;
  end
  assign ALU_B_Op=EX_ALU_B_toX;//在EX级使用


  //DM_Write_En
  wire DM_Write_En;
  wire ID_DM_Write_to1=OP_stw;//在ID级产生
  assign DM_Write_En=MEM_DM_Write_to1;//在MEM级使用


  //WB_Op
  wire WB_Op;
  wire ID_WB_Op_to1=OP_ldw;//在ID级产生
  assign WB_Op=WB_WB_Op_to1;//在WB级使用


  //slt_En,sltu_En已经在EX级发挥作用了


  //ALUOp
  // ALU 操作码定义（新增）
  localparam [3:0] ALU_ADD = 4'd0;
  localparam [3:0] ALU_SUB = 4'd1;
  localparam [3:0] ALU_SLL = 4'd2;//逻辑/算术左移
  localparam [3:0] ALU_SRL = 4'd3;//逻辑右移 >> 补0
  localparam [3:0] ALU_SRA = 4'd4;//算术右移 >>> 补符号
  localparam [3:0] ALU_AND = 4'd5;
  localparam [3:0] ALU_OR  = 4'd6;
  localparam [3:0] ALU_NOR = 4'd7;
  localparam [3:0] ALU_XOR = 4'd8;
  localparam [3:0] ALU_jirl= 4'd9;//jirl特殊处理
  localparam [3:0] ALU_I   =4'd10 ;//lu12i处理(直接输出B_Op)

  //+,-,<<,>>,and,orr,nor,xor
  wire [3:0] ID_ALUop;
  assign ID_ALUop =(OP_subw|OP_slt|OP_sltu)?ALU_SUB:
         OP_and   ? ALU_AND :
         OP_nor   ? ALU_NOR :
         OP_or    ? ALU_OR  :
         OP_xor   ? ALU_XOR :
         OP_slliw ? ALU_SLL :
         OP_srliw ? ALU_SRL :
         OP_sraiw ? ALU_SRA :
         OP_jirl  ? ALU_jirl:
         OP_lu12iw? ALU_I   :
         ALU_ADD;

  assign ALUop=EX_ALUop;


  //ID_EX_reg需要输入的控制信号组合
  wire [11:0] ID_to_EX_control={OP_jirl,OP_slt,OP_sltu,ID_Register_Write_Data_to0,
                                ID_Register_Write_Data_to3,ID_ALU_B_toX,ID_ALUop};
  wire ID_to_MEM_control=ID_DM_Write_to1;
  wire [2:0] ID_to_WB_control={ID_Register_Write_addr_to1,
                               ID_Register_Write_to1,ID_WB_Op_to1};



  ////EX级
  //信号
  wire [31:2] EX_PC_1;
  wire [31:0] RJ_Op;
  wire [31:0] RK_Op;
  wire [31:0] EX_RD_data;
  wire [31:0] EX_I20;
  wire [31:0] EX_I12;
  wire [31:0] EX_I16;
  wire [31:0] EX_UI5;
  reg [31:0] B_Op;
  wire [4:0] EX_RD;
  wire EX_MEM_En;
  wire EX_MEM_flush;

  //控制信号
  wire [11:0] ID_EX_control;
  assign {EX_OP_jirl,EX_OP_slt,EX_OP_sltu,EX_Register_Write_Data_to0,
          EX_Register_Write_Data_to3,EX_ALU_B_toX,EX_ALUop}=ID_EX_control;
  wire ID_EX_to_MEM_control;
  assign EX_DM_Write_to1=ID_EX_to_MEM_control;
  wire [2:0] ID_EX_to_WB_control;
  assign {EX_Register_Write_addr_to1,
          EX_Register_Write_to1,EX_WB_Op_to1}=ID_EX_to_WB_control;


  //实例化ID_EX_reg
  ID_EX_reg ID_EX_reg(.clk(clk),.rst(rst),.En(ID_EX_En),.flush(ID_EX_flush),.ID_PC_1(ID_PC_1),.RJ_data(RJ_data),
                      .RK_RD_data(RK_RD_data),.sign_I12(sign_I12),.extend0_I20(extend0_I20),
                      .sign_I16(sign_I16),.sign_UI5(sign_UI5),.RD(RD),
                      .ID_to_EX_control(ID_to_EX_control),
                      .ID_to_MEM_control(ID_to_MEM_control),
                      .ID_to_WB_control(ID_to_WB_control),
                      .EX_PC_1(EX_PC_1),.RJ_Op(RJ_Op),.RK_Op(RK_Op),
                      .EX_I12(EX_I12),.EX_I20(EX_I20),.EX_I16(EX_I16),.EX_UI5(EX_UI5),.EX_RD(EX_RD),
                      .ID_EX_control(ID_EX_control),
                      .ID_EX_to_MEM_control(ID_EX_to_MEM_control),
                      .ID_EX_to_WB_control(ID_EX_to_WB_control)
                     );

  assign EX_RD_data=RK_Op;

  //B_Op计算
  always@*
  begin
    case(ALU_B_Op)
      0:
        B_Op=RK_Op;
      1:
        B_Op=EX_I20;
      2:
        B_Op=EX_I12;
      3:
        B_Op=EX_I16;
      4:
        B_Op=EX_UI5;
    endcase
  end

  //ALU模块实例化
  ALU ALU(.A(RJ_Op),.B(B_Op),.ALUop(ALUop),.ALU_result(ALU_result),.slt_En(slt_En),.sltu_En(sltu_En));


  ////MEM级
  //信号
  wire [31:2] MEM_PC_1;
  wire [31:0] MEM_RD_data;
  wire [31:0] DM_addr;
  wire [31:0] MEM_ALU_Result;
  wire [4:0] MEM_RD;
  wire [31:0] MEM_DM_data;
  wire MEM_WB_En;
  wire MEM_WB_flush;

  assign MEM_ALU_Result=DM_addr;


  //控制信号赋值
  wire EX_to_MEM_control;
  assign EX_to_MEM_control=ID_EX_to_MEM_control;
  wire [4:0] EX_to_WB_control;
  assign EX_to_WB_control={ID_EX_to_WB_control,EX_Register_Write_Data_toX};

  wire EX_MEM_control;
  wire [4:0] EX_MEM_to_WB_control;


  //实例化EX_MEM_reg
  EX_MEM_reg EX_MEM_reg(.clk(clk),.rst(rst),.En(EX_MEM_En),.flush(EX_MEM_flush),.EX_PC_1(EX_PC_1),.EX_RD_data(EX_RD_data),
                        .ALU_result(ALU_result),.EX_RD(EX_RD),
                        .EX_to_MEM_control(EX_to_MEM_control),
                        .EX_to_WB_control(EX_to_WB_control),
                        .MEM_PC_1(MEM_PC_1),.MEM_RD_data(MEM_RD_data),
                        .DM_addr(DM_addr),.MEM_RD(MEM_RD),
                        .EX_MEM_control(EX_MEM_control),
                        .EX_MEM_to_WB_control(EX_MEM_to_WB_control)
                       );

  //实例化DM
  DM DM(.clk(clk),.rst(rst),.addr(DM_addr),.Write_data(MEM_RD_data),.DM_Write_En(DM_Write_En),.DM_Read_data(MEM_DM_data));

  //控制信号赋值
  assign MEM_DM_Write_to1=EX_MEM_control;


  ////WB级
  //信号
  wire [31:0] WB_ALU_Result;
  wire [31:0] WB_DM_data;
  wire [31:2] WB_PC_1;
  wire [4:0] WB_RD;


  //控制信号
  wire [4:0] MEM_to_WB_control;
  assign MEM_to_WB_control=EX_MEM_to_WB_control;

  wire [4:0] MEM_WB_control;


  //实例化MEM_WB_reg
  MEM_WB_reg MEM_WB_reg(.clk(clk),.rst(rst),.En(MEM_WB_En),.flush(MEM_WB_flush),.MEM_PC_1(MEM_PC_1),.MEM_ALU_Result(MEM_ALU_Result),
                        .MEM_DM_data(MEM_DM_data),.MEM_RD(MEM_RD),
                        .MEM_to_WB_control(MEM_to_WB_control),
                        .WB_PC_1(WB_PC_1),.WB_ALU_Result(WB_ALU_Result),
                        .WB_DM_data(WB_DM_data),.WB_RD(WB_RD),
                        .MEM_WB_control(MEM_WB_control)
                       );



  //控制信号赋值
  assign {WB_Register_Write_Data_toX,WB_Register_Write_addr_to1,
          WB_Register_Write_to1,WB_WB_Op_to1}=MEM_WB_control;


  assign WB_PC_1_extend={WB_PC_1,2'b00};
  assign WB_Mux_Data=WB_Op?WB_DM_data:WB_ALU_Result;

  assign Register_Write_addr=Register_Write_addr_Opt?1:WB_RD;









  //一些信号未用到，先赋值
  assign IF_ID_En=1,ID_EX_En=1,EX_MEM_En=1,MEM_WB_En=1,EX_MEM_flush=0,MEM_WB_flush=0;


endmodule





////流水级模块
//注意控制信号的补充
//flush将写信号清空
module IF_ID_reg(
    input clk,
    input rst,
    input En,
    input flush,
    input [31:2] IF_PC_1,
    input [31:2] Current_PC,
    input [31:0] IF_Instr,
    output reg [31:2] ID_PC_1,
    output reg [31:0] ID_Instr,
    output reg [31:2] ID_PC
  );
  always @(posedge clk)
  begin
    if(rst)
      {ID_PC_1,ID_Instr,ID_PC}<=0;
    else if(En)
      if(flush)
        {ID_PC_1,ID_Instr,ID_PC}<=0;
      else
        {ID_PC_1,ID_Instr,ID_PC}<={IF_PC_1,IF_Instr,Current_PC};
  end

endmodule


module ID_EX_reg(
    input clk,
    input rst,
    input En,
    input flush,
    input [31:2] ID_PC_1,
    input [31:0] RJ_data,
    input [31:0] RK_RD_data,
    input [31:0] sign_I12,
    input [31:0] extend0_I20,
    input [31:0] sign_I16,
    input [31:0] sign_UI5,
    input [4:0] RD,
    input [11:0] ID_to_EX_control,
    input ID_to_MEM_control,
    input [2:0] ID_to_WB_control,
    output reg [31:2] EX_PC_1,
    output reg [31:0] RJ_Op,
    output reg [31:0] RK_Op,
    output reg [31:0] EX_I12,
    output reg [31:0] EX_I20,
    output reg [31:0] EX_I16,
    output reg [31:0] EX_UI5,
    output reg [4:0] EX_RD,
    output reg [11:0] ID_EX_control,
    output reg ID_EX_to_MEM_control,
    output reg [2:0] ID_EX_to_WB_control
  );

  always@(posedge clk)
  begin
    if(rst)
      {EX_PC_1,RJ_Op,RK_Op,EX_I12,EX_I20,EX_I16,EX_UI5,EX_RD,ID_EX_control,
       ID_EX_to_MEM_control,ID_EX_to_WB_control}<=0;
    else if(En)
      if(flush)
        {EX_PC_1,RJ_Op,RK_Op,EX_I12,EX_I20,EX_I16,EX_UI5,EX_RD,ID_EX_control,
         ID_EX_to_MEM_control,ID_EX_to_WB_control}<=0;
      else
        {EX_PC_1,RJ_Op,RK_Op,EX_I12,EX_I20,EX_I16,EX_UI5,EX_RD,ID_EX_control,
            ID_EX_to_MEM_control,ID_EX_to_WB_control}<=
        {ID_PC_1,RJ_data,RK_RD_data,sign_I12,extend0_I20,sign_I16,sign_UI5,RD,
         ID_to_EX_control,ID_to_MEM_control,ID_to_WB_control};
  end

endmodule

module EX_MEM_reg(
    input clk,
    input rst,
    input En,
    input flush,
    input [31:2] EX_PC_1,
    input [31:0] EX_RD_data,
    input [31:0] ALU_result,
    input [4:0] EX_RD,
    input EX_to_MEM_control,
    input [4:0] EX_to_WB_control,
    output reg [31:2] MEM_PC_1,
    output reg [31:0] MEM_RD_data,
    output reg [31:0] DM_addr,
    output reg [4:0] MEM_RD,
    output reg EX_MEM_control,
    output reg [4:0] EX_MEM_to_WB_control
  );
  always@(posedge clk)
  begin
    if(rst)
      {MEM_PC_1,MEM_RD_data,DM_addr,MEM_RD,EX_MEM_control,EX_MEM_to_WB_control}<=0;
    else if(En)
      if(flush)
        {MEM_PC_1,MEM_RD_data,DM_addr,MEM_RD,EX_MEM_control,EX_MEM_to_WB_control}<=0;
      else
        {MEM_PC_1,MEM_RD_data,DM_addr,MEM_RD,EX_MEM_control,EX_MEM_to_WB_control}
        <={EX_PC_1,EX_RD_data,ALU_result,EX_RD,EX_to_MEM_control,EX_to_WB_control};
  end

endmodule

module MEM_WB_reg(
    input clk,
    input rst,
    input En,
    input flush,
    input [31:2] MEM_PC_1,
    input [31:0] MEM_ALU_Result,
    input [31:0] MEM_DM_data,
    input [4:0] MEM_RD,
    input [4:0] MEM_to_WB_control,
    output reg [31:2] WB_PC_1,
    output reg [31:0] WB_ALU_Result,
    output reg [31:0] WB_DM_data,
    output reg [4:0] WB_RD,
    output reg [4:0] MEM_WB_control
  );

  always@(posedge clk)
  begin
    if(rst)
      {WB_PC_1,WB_ALU_Result,WB_DM_data,WB_RD,MEM_WB_control}<=0;
    else if(En)
      if(flush)
        {WB_PC_1,WB_ALU_Result,WB_DM_data,WB_RD,MEM_WB_control}<=0;
      else
        {WB_PC_1,WB_ALU_Result,WB_DM_data,WB_RD,MEM_WB_control}<=
        {MEM_PC_1,MEM_ALU_Result,MEM_DM_data,MEM_RD,MEM_to_WB_control};
  end

endmodule




//PC模块
module PC(
    input clk,
    input rst,
    input [31:2] Next_PC,
    output reg [31:2] Current_PC
  );

  always @(posedge clk)
  begin
    if(rst)
      Current_PC<=30'h07000000;//0x1C000000>>2
    else
      Current_PC<=Next_PC;
  end

endmodule




//指令存储器
module IM(
    input [31:2] addr,
    output reg [31:0] dout
  );

  reg [31:0] imem[0:63];

  always@*
  begin
    dout =imem[addr[7:2]];//目前只取低6位
  end

endmodule



//寄存器
module Register(
    input clk,
    input rst,
    input Write_En,
    input [4:0] Read_rk_rd,
    input [4:0] Read_rj,
    input [31:0] Write_data,
    input [4:0] Write_addr,
    output [31:0] Read_rk_rd_data,
    output [31:0] Read_rj_data
  );

  //寄存器堆
  reg [31:0] Regs[31:0];
  integer i;

  assign Read_rk_rd_data=(Read_rk_rd==5'd0)?32'b0:Regs[Read_rk_rd];
  assign Read_rj_data=(Read_rj== 5'd0)?32'b0:Regs[Read_rj];


  always@(posedge clk)
  begin
    if(rst)
    begin
      for(i=0;i<32;i=i+1)
        Regs[i]<=32'b0;
    end
    else if(Write_En && Write_addr!=0)
    begin
      Regs[Write_addr]<=Write_data;
    end
  end

endmodule

//ALU模块
module ALU(
    input [31:0] A,
    input [31:0] B,
    input [3:0] ALUop,
    output reg [31:0] ALU_result,
    output slt_En,
    output sltu_En
  );


  //Negative符号位
  wire N = ALU_result[31];
  wire Z = (ALU_result==32'b0);
  // V (Overflow溢出): 只有在 A, B 符号相反，且结果符号与 A 相反时才会溢出
  wire V = (A[31] != B[31]) && (ALU_result[31] != A[31]);
  // C (Carry out无符号借位): 用 33 位加法来实现减法以获得准确的 C
  wire [32:0] full_sub = {1'b0, A} + {1'b0, ~B} + 33'b1;
  wire C = full_sub[32];

  // 3. 最终比较结果
  assign slt_En= N ^ V;      // 有符号比较 A < B
  assign sltu_En=~C;         // 无符号比较 A < B



  always@*
  begin
    case(ALUop)
      0:
        ALU_result=A+B;
      1:
        ALU_result=A-B;
      2:
        ALU_result=A<<B[4:0];
      3:
        ALU_result=A>>B[4:0];
      4:
        ALU_result=$signed(A) >>> B[4:0];
      5:
        ALU_result=A&B;
      6:
        ALU_result=A|B;
      7:
        ALU_result=~(A|B);
      8:
        ALU_result=A^B;
      9:
        ALU_result=(A>>2)+B;//jirl特殊处理
      10:
        ALU_result=B;//lu12i.w特殊处理
    endcase
  end

endmodule



//数据存储器
module DM(
    input clk,
    input rst,
    input [31:0] addr,
    input [31:0] Write_data,
    input DM_Write_En,
    output [31:0] DM_Read_data
  );

  reg [31:0] dmem[0:63];
  integer i;
  assign DM_Read_data=dmem[addr[5:0]];

  always@(posedge clk)
  begin
    if(rst)
    begin
      for(i=0;i<64;i=i+1)
        dmem[i]<=32'b0;
    end
    else if(DM_Write_En)
      dmem[addr[5:0]]<=Write_data;
  end

endmodule
