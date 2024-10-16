`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/29 19:04:54
// Design Name: 
// Module Name: decoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module inst_decoder(
    input[31:0]     inst,           // 输入为IF_ID_IR
    input           clk,
    output          wen,            // 寄存器写使能
    output[4:0]     waddr,          // 寄存器写地址
    output[4:0]     raddr1,         // 寄存器读地址1
    output[4:0]     raddr2,         // 寄存器读地址2
    output          alu_en,         // alu使能
    output[4:0]     alu_card,       // alu操作码
    output          jmp,            // 是否跳转！！！！
    output          bbt,            // 是否bbt，用于帮助地址计算部件确定合适的方式来计算地址
    output          data_sram_en,   // 数据寄存器使能
    output[3:0]     data_sram_wen,  // 数据寄存器写使能
    output          movz_en,        // movz使能
    output          sll_en,         // sll使能
    output          cmp_en,          // cmp使能
    output          invalid          // invalid，用于对付nop
    );
    
    // 按照每一条指令声明一个线路变量用于判断指令
    wire ADD;
    wire SUB;
    wire AND;
    wire OR;
    wire XOR;
    wire MOVZ;  //新增
    wire SLL;   //新增
    wire SW;
    wire LW;
    wire J;
    wire CMP;   //新增
    wire BBT;   //新增
    
    wire [5:0] OPcode;
    assign OPcode = inst[31:26];
    
    // 判断指令，依据[31:26]和[10:0]完成判断
    // alu类
    assign ADD = (OPcode == 6'b000000) & ( inst[10:0] == 11'b00000100000);
    assign SUB = (OPcode == 6'b000000) & ( inst[10:0] == 11'b00000100010);
    assign AND = (OPcode == 6'b000000) & ( inst[10:0] == 11'b00000100100);
    assign OR  = (OPcode == 6'b000000) & ( inst[10:0] == 11'b00000100101);
    assign XOR = (OPcode == 6'b000000) & ( inst[10:0] == 11'b00000100110);
    
    // 访存类
    assign SW = (OPcode == 6'b101011);
    assign LW = (OPcode == 6'b100011);
    assign J  = (OPcode == 6'b000010);
    
    assign MOVZ = (OPcode == 6'b000000) & ( inst[10:0] == 11'b00000001010);
    assign SLL  = (inst[31:21] == 11'b00000000000) & ( inst[5:0] == 6'b000000);
    assign CMP  = (OPcode == 6'b111110) & ( inst[10:0] == 11'b00000000000);
    assign BBT  = (OPcode == 6'b111111);
    
    // 对外接线
    assign wen = (ADD | SUB | AND | OR | XOR       | LW        | SLL | CMP) & (waddr != 5'b0);
    assign waddr = ({5{LW}}& inst[20:16]) | ({5{ADD}} & inst[15:11]) | ({5{SUB}} & inst[15:11]) | ({5{AND}} & inst[15:11]) | ({5{OR}} & inst[15:11]) | ({5{XOR}} & inst[15:11]) | ({5{MOVZ}} & inst[15:11])| ({5{SLL}} & inst[15:11])| ({5{CMP}} & inst[15:11]);
    assign raddr1 = inst[25:21];
    assign raddr2 = inst[20:16];
    assign alu_en = ADD | SUB | AND | OR | XOR;
    assign alu_card = ({5{ADD }} & 5'b00001) | ({5{SUB}} & 5'b00011) | ({5{OR}} & 5'b01011) | ({5{AND}} & 5'b01100) | ({5{XOR}} & 5'b01110);
    assign jmp = J | BBT;
    assign bbt = BBT;
    assign data_sram_en = LW | SW;
    assign data_sram_wen = {4{SW}};
    assign movz_en = MOVZ;
    assign sll_en = SLL;
    assign cmp_en = CMP;
    assign invalid = ~ADD & ~SUB & ~AND & ~OR & ~XOR & ~SW & ~LW & ~J & ~MOVZ & ~SLL & ~CMP & ~BBT;
    
endmodule



//////////////////////////////////////////////////////////////////////////////////////////

//`define FETCH 3'b000
//`define FETCH_WAIT 3'b001  // 新增的等待状态
//`define DECODE 3'b010
//`define EXECUTE 3'b011
//`define MEM_ACCESS 3'b100
//`define WRITEBACK  3'b101