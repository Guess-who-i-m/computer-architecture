`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/28 18:10:25
// Design Name: 
// Module Name: regfile
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


module regfile(
    input clk,                  //Ê±ÖÓĞÅºÅ
    input [4:0]  raddr1,        //¼Ä´æÆ÷¶Ñ¶ÁµØÖ·1
    output   [31:0] rdata1,     //¼Ä´æÆ÷¶Ñ¶Á·µ»ØµØÖ·1
    input [4:0]  raddr2,        //¼Ä´æÆ÷¶ÁµØÖ·2
    output [31:0] rdata2,       //¼Ä´æÆ÷¶Á·µ»ØµØÖ·2
    input  we,                  //¼Ä´æÆ÷¶ÑĞ´Ê¹ÄÜ
    input [4:0] waddr,                //¼Ä´æÆ÷¶ÑĞ´µØÖ·
    input [31:0] wdata                 //¼Ä´æÆ÷¶ÑĞ´Êı¾İ
    );
    
    reg [31:0] regheap [31:0];
    
    integer i;
    
    // ¶Ô¼Ä´æÆ÷¶Ñ½øĞĞ³õÊ¼»¯
    initial begin
        for (i=0; i<32; i = i + 1) begin
            regheap[i] = 32'b0;
        end
    end
    
    assign rdata1 = regheap[raddr1];
    assign rdata2 = regheap[raddr2];
    
    always @(posedge clk) begin
        if (we == 1 && waddr != 5'b00000) begin
            regheap[waddr] <= wdata;
        end
    end
    
endmodule
