`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/23 19:51:16
// Design Name: 
// Module Name: addr_calculator
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


module addr_calculator(
    input           clk,
    input   [31:0]  npc,
    input           jmp,
    input           bbt,
    input   [31:0]  inst,
    input   [31:0]  rdata1,
    input   [4:0]   raddr2,
    output  [31:0]  jmp_addr
    
    );
    
//    always @(posedge clk) begin
//         $display("Time %t: jmp_addr: %h, jmp: %h, bbt: %h, rdata1: %h, raddr2: %h", $time, jmp_addr, jmp, bbt, rdata1, raddr2);
//    end
    
    assign jmp_addr = ({32{jmp & ~bbt}} & {npc[31:28], inst[25:0] << 2}) |
                  ( (bbt & rdata1[raddr2]) ? (({{14{inst[15]}}, inst[15:0], 2'b00} ) + npc) : npc ) |
                  ({32{~jmp}} & npc);
    
endmodule
