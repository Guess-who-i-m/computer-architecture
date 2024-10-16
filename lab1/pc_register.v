`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/03 16:57:38
// Design Name: 
// Module Name: PC
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



module pc_register(
    input clk,                  // 时钟信号
    input [31:0] jmp_addr,      // 跳转计算得到的地址
    input jmp,                  // jmp指令信号
    input resetn,               //复位信号
    output [31:0] npc,    //当前指令地址
    output [31:0] pc,      // 下一条指令
    output inst_sram_en         // 内存读使能
    );
    
    reg [31:0] pc_reg;
    reg [31:0] npc_reg;
    reg inst_sram_en_reg;
    
    // 疑问1：如何安排指令寄存器读使能信号？ 能不能设置为一直为1
    
    always @(posedge clk) begin
        // 当复位信号为0，给指令地址复位为0，npc复位为4
        if (!resetn) begin
            pc_reg <= 32'b0;
            npc_reg <= 32'b100;
            inst_sram_en_reg <= 1;  //能不能这么干？
        // 一般的情况下，需要依据npc的值，和跳转值和跳转地址进行多路选择
        end else begin
            // 如果跳转指令为真，那么将在ID阶段计算得到的jmp_addr赋值给pc
            if (jmp) begin
                pc_reg <= jmp_addr;
            end else begin
                pc_reg <= npc_reg;
                npc_reg <= npc_reg + 4;
            end
        end

    end
    
    // 将寄存器和外界输出连上线
    assign npc = npc_reg;
    assign pc  = pc_reg;
    assign inst_sram_en = inst_sram_en_reg;
    
endmodule


/////////////////////////////////////////////////////////////////////////////////////

//`define FETCH 3'b000
//`define FETCH_WAIT 3'b001  // 新增的等待状态
//`define DECODE 3'b010
//`define EXECUTE 3'b011
//`define MEM_ACCESS 3'b100
//`define WRITEBACK  3'b101


//    reg [31:0] inst_addr_reg;
//    reg en;
//    assign inst_sram_en = en;
//    assign next_pc = inst_addr_reg;
    
    
//    reg [31:0] pc_output;
//    assign inst_addr = pc_output;
//    always @(posedge clk) begin
//        if (state == `FETCH) begin
//            pc_output <= pc;
//        end 
//    end

//    always @(posedge clk) begin
//        // 当复位的时候
//        if (!resetn) begin
//            inst_addr_reg <= 32'b0;  // 复位时PC置为0
//            en <= 1;  // 禁用inst_sram_en信号

//        // 写回阶段就赋值为1，才能在取指阶段读取指令
//        end else if (state == `MEM_ACCESS) begin
//            if (jmp | bbt) begin
//                inst_addr_reg <= jmp_addr;  // 如果有跳转指令，设置PC为跳转地址
//                // $display("跳转指令 Time %t: jmp_addr:%b", $time, jmp_addr);
//                en <= 1;  // 在`FETCH`状态激活inst_sram_en
//            end else begin
//                inst_addr_reg <= pc + 4;  // 正常递增PC
//                en <= 1;  // 在`FETCH`状态激活inst_sram_en
//            end
//            // en <= 1;
//        // 其它情况不取指
//        end else begin
//            en <= 0;  // 非FETCH状态禁用inst_sram_en
//        end
//    end