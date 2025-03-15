`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/11 14:15:00
// Design Name: 
// Module Name: branch
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


module branch(
    input clk,
    input resetn,
    
    // 取值阶段
    input  [31:0]   pc,
    // 译码阶段
    input           bbt,
    input  [31:0]   jmp_addr,
    output [31:0]   predicted_addr,
    // 执行阶段
    output          predicted_success
    );
    
    // 声明页表项的结构
    reg[65:0] BTB[63:0];        // [31:0]  转移目标地址
                                // [63:32] 转移指令的地址
                                // [65:64] 2位BPB
    
    wire [5:0] IF_index = pc[7:2];
    
    reg        in_BTB;
    reg [31:0] IF_ID_pc_tmp;
    reg [31:0] jaddr_from_BTB;
    reg reg_predict_success;
    assign predicted_addr = jaddr_from_BTB;
    assign predicted_success = reg_predict_success;
    
    // 完成初始化
    integer i;
    initial begin
        for(i = 0;i < 64;i = i + 1) begin
            BTB[i] = 0;
        end
        jaddr_from_BTB <= 0;
        reg_predict_success <=0;
    end
    
    always @(posedge clk) begin
        // 复位信号初始化
        if (~resetn) begin
            // 重置BTB的所有内容
            for(i = 0;i < 64;i = i + 1) begin
                BTB[i] = 0;
            end
            jaddr_from_BTB <= 0;
            reg_predict_success <=0;
        end else begin
            // 取指阶段
            // 1. 判断当前PC值对应的指令是否在BTB中
            if (BTB[IF_index][63:32] == pc) begin
                jaddr_from_BTB <= BTB[IF_index][31:0];
                IF_ID_pc_tmp <= 32'b0;
                in_BTB <= 1;
            end else begin
                IF_ID_pc_tmp <= pc;         // 如果不在BTB中，先用IF_ID_pc_tmp记录
                jaddr_from_BTB <= 32'b0;
                in_BTB <= 0;
            end
            
            // 译码阶段
            // 1. 在先前指令在BTB的基础上进一步判断是否分支成功
            if (in_BTB) begin
                if ( jmp_addr == jaddr_from_BTB) begin
                    // 预测成功，后续指令可以正确执行
                    reg_predict_success <= 1;
                end else begin
                    // 预测失败，清空提前执行的一周期指令
                    reg_predict_success <= 0;
                 end
            end else begin
                reg_predict_success <= 0;
                // 2. 在先前指令不在BTB的基础上判断是否是分支指令
                if (bbt) begin
                    BTB[IF_ID_pc_tmp[7:2]][31:0]    <= jmp_addr;
                    BTB[IF_ID_pc_tmp[7:2]][63:32]   <= IF_ID_pc_tmp;
                end 
            end
        end
    end
    
endmodule
