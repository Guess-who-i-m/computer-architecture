`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/27 18:35:28
// Design Name: 
// Module Name: alu
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

`define ADD     5'b00001
`define ADDc    5'b00010
`define SUB     5'b00011
`define SUBc    5'b00100
`define SUBr    5'b00101
`define SUBrc   5'b00110
`define LDA     5'b00111
`define LDB     5'b01000
`define NA      5'b01001
`define NB      5'b01010
`define OR      5'b01011
`define AND     5'b01100
`define XNOR    5'b01101
`define XOR     5'b01110
`define NAND    5'b01111
`define ZERO    5'b10000

module my_alu(
    input  [31:0]   A   ,
    input  [31:0]   B   ,
    input           Cin ,
    input  [4 :0]   Card,

    output [31:0]   F   
    );
    
    wire [32:0] temp_0;
    wire [32:0] temp_1;
    wire [32:0] temp_2;
    wire [32:0] temp_3;
    wire [32:0] temp_4;
    wire [32:0] temp_5;
    
    wire [31:0] add_res;
    wire [31:0] addc_res;
    wire [31:0] sub_res;
    wire [31:0] subc_res;
    wire [31:0] subr_res;
    wire [31:0] subrc_res;
    wire [31:0] lda_res;
    wire [31:0] ldb_res;
    wire [31:0] na_res;
    wire [31:0] nb_res;
    wire [31:0] or_res;
    wire [31:0] and_res;
    wire [31:0] xnor_res;
    wire [31:0] xor_res;
    wire [31:0] nand_res;
    wire [31:0] zero_res;
    
    assign temp_0 = {1'b0, A} + {1'b0, B};
    assign temp_1 = {1'b0, A} + {1'b0, B} + Cin;
    assign temp_2 = {1'b0, A} - {1'b0, B};
    assign temp_3 = {1'b0, A} - {1'b0, B} - Cin;
    assign temp_4 = {1'b0, B} - {1'b0, A};
    assign temp_5 = {1'b0, B} - {1'b0, A} - Cin;
    
    assign add_res = temp_0[31:0];
    assign addc_res = temp_1[31:0];

    assign sub_res = temp_2[31:0];
    assign subc_res = temp_3[31:0];
    assign subr_res = temp_4[31:0];
    assign subrc_res = temp_5[31:0];
    
    assign lda_res = A;
    assign ldb_res = B;
    assign na_res = ~A;
    assign nb_res = ~B;
    assign or_res = A | B;
    assign and_res = A & B;
    assign xnor_res = ( A & B ) | (~A & ~B);
    assign xor_res = A ^ B;
    assign nand_res = ~ ( A & B );
    assign zero_res = 32'b0;
    
    assign F = ({32{Card == `ADD}} & add_res)       |
               ({32{Card == `ADDc}} & addc_res)     |
               ({32{Card == `SUB}} & sub_res)       |
               ({32{Card == `SUBc}} & subc_res)     |
               ({32{Card == `SUBr}} & subr_res)     |
               ({32{Card == `SUBrc}} & subrc_res)   |
               ({32{Card == `LDA}} & lda_res)       |
               ({32{Card == `LDB}} & ldb_res)       |
               ({32{Card == `NA}}  & na_res)        |
               ({32{Card == `NB}}  & nb_res)        |
               ({32{Card == `OR}}  & or_res)        |
               ({32{Card == `AND}}  & and_res)      |
               ({32{Card == `XNOR}}  & xnor_res)    |
               ({32{Card == `XOR}}  & xor_res)      |
               ({32{Card == `NAND}}  & nand_res)    |
               ({32{Card == `ZERO}}  & zero_res);

endmodule