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
    input  [31:0] ID_EX_IR,
    input  [31:0] EX_MEM_IR,
    input  [31:0] predicted_addr,
    input         predicted_success,
    output [31:0] npc,    //当前指令地址
    output [31:0] pc,      // 下一条指令
    output inst_sram_en,         // 内存读使能
    output jmp_reg_sign,
    output [31:0] pc_tmp_reg_value
    );
    
    reg jmp_reg;
    reg [31:0] pc_reg;
    reg [31:0] npc_reg;
    reg [31:0] pc_tmp_reg;
    reg [31:0] predicted_tmp_reg;
    
    assign jmp_reg_sign = jmp_reg; 
    assign pc_tmp_reg_value = pc_tmp_reg;
    
    always @(posedge clk) begin
        // 当复位信号为0，给指令地址复位为0，npc复位为4
        if (!resetn) begin
            pc_reg <= 32'b0;
            npc_reg <= 32'b100;
            jmp_reg <= 0;
            pc_tmp_reg <= 32'b0;
        // 一般的情况下，需要依据npc的值，和跳转值和跳转地址进行多路选择
        end else begin
            // 如果跳转指令为真，那么将在ID阶段计算得到的jmp_addr赋值给pc
            if (jmp_reg & ~predicted_success ) begin
                jmp_reg <= 0;
                pc_tmp_reg <= 32'b0;
                if (predicted_tmp_reg == 32'b0) begin
                    pc_reg <= npc_reg;
                    npc_reg <= npc_reg +4;
                    
                end else begin
                    predicted_tmp_reg = 32'b0;
                    pc_reg <= pc_tmp_reg + 4;
                    npc_reg <= pc_tmp_reg +8;
                end  
            end else begin
                if (jmp) begin
                    jmp_reg <= jmp;
                    pc_tmp_reg <= jmp_addr;
                    pc_reg <= (predicted_addr == 0) ? jmp_addr : predicted_addr +4 ;
                    npc_reg <= (predicted_addr == 0) ? jmp_addr + 4 : predicted_addr +8 ;
                    predicted_tmp_reg <= predicted_addr;
                end else begin
                    jmp_reg <= 0;
                    if ((EX_MEM_IR[31:26] == 6'b100011 & ID_EX_IR[31:26] == 6'b000000 & (EX_MEM_IR[20:16] == ID_EX_IR[25:21] | EX_MEM_IR[20:16] == ID_EX_IR[20:16])) | 
                        (ID_EX_IR[31:26] == 6'b111111)) begin
                        
                    end else begin
                        //pc_reg <= (predicted_addr == 0) ? npc_reg : predicted_addr +4 ;
                        // npc_reg <= (predicted_addr == 0) ? npc_reg + 4 : predicted_addr +8 ;
                        pc_reg <= npc_reg;
                        npc_reg <= npc_reg + 4;
                    end
                end
            end
        end
    end
    
    // 将寄存器和外界输出连上线
    assign npc = npc_reg;
    assign pc  = pc_reg;
    assign inst_sram_en = ~(EX_MEM_IR[31:26] == 6'b100011 & ID_EX_IR[31:26] == 6'b000000 & (EX_MEM_IR[20:16] == ID_EX_IR[25:21] | EX_MEM_IR[20:16] == ID_EX_IR[20:16]));
    
endmodule


