`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/03 16:54:07
// Design Name: 
// Module Name: cpu
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

module cpu(
    input           clk,                // 时钟信号
    input           resetn,             // 低有效复位信号

    output          inst_sram_en,       // 指令存储器读使能
    output[31:0]    inst_sram_addr,     // 指令存储器读地址
    input[31:0]     inst_sram_rdata,    // 指令存储器读出的数据

    output          data_sram_en,       // 数据存储器端口读/写使能
    output[3:0]     data_sram_wen,      // 数据存储器写使能      
    output[31:0]    data_sram_addr,     // 数据存储器读/写地址
    output[31:0]    data_sram_wdata,    // 写入数据存储器的数据
    input[31:0]     data_sram_rdata,    // 数据存储器读出的数据

    // 供自动测试环境进行CPU正确性检查
    output[31:0]    debug_wb_pc,        // 当前正在执行指令的PC
    output          debug_wb_rf_wen,    // 当前通用寄存器组的写使能信号
    output[4:0]     debug_wb_rf_wnum,   // 当前通用寄存器组写回的寄存器编号
    output[31:0]    debug_wb_rf_wdata   // 当前指令需要写回的数据
);

    
   
    wire [31:0] rdata1; // 寄存器读端口1
    
    wire [31:0] rdata2; // 寄存器读端口2
    wire we;           // 寄存器的写使能

    wire [31:0] wdata; // 寄存器写数据
    wire [31:0] wdata_cmp; // cmp指令下的写回数据
    
    
    wire invalid;            // 无效指令标志

        // ID/EX段间寄存器
    reg [31:0] ID_EX_IR;
    reg        ID_EX_we;
    reg [4:0]  ID_EX_waddr;          // 寄存器写回要格外仔细考虑
    reg        ID_EX_alu_en;         //用来在MEM/WB阶段判断写回什么数据
    reg [4:0]  ID_EX_alu_card;       // 在EXE阶段让alu正确工作
    reg        ID_EX_data_sram_en;
    reg [3:0]  ID_EX_data_sram_wen;
    reg        ID_EX_movz_en;
    reg        ID_EX_sll_en;
    reg        ID_EX_cmp_en;
    reg [31:0] ID_EX_rdata1;
    reg [31:0] ID_EX_rdata2;
    reg [31:0] ID_EX_pc;
    reg        ID_EX_invalid;
    
    // EX/MEM
    reg [31:0]  EX_MEM_IR;
    reg         EX_MEM_we;
    reg         EX_MEM_movz_en;
    reg [4:0]   EX_MEM_waddr;
    reg         EX_MEM_sll_en;
    reg         EX_MEM_cmp_en;
    reg         EX_MEM_alu_en;
    reg [31:0]  EX_MEM_alu_out;
    reg [31:0]  EX_MEM_rdata1;
    reg [31:0]  EX_MEM_rdata2;
    reg         EX_MEM_data_sram_en;
    reg [3:0]   EX_MEM_data_sram_wen;
    reg [31:0]  EX_MEM_pc;
    reg         EX_MEM_invalid;
    reg [31:0]  EX_MEM_wdata_cmp;
    reg [31:0]  EX_MEM_data_sram_addr;
    reg [31:0]  EX_MEM_data_sram_wdata;
    reg [31:0]  EX_MEM_alu_data1;
    reg [31:0]  EX_MEM_alu_data2;
    
    // MEM/WB
    reg         MEM_WB_movz_en;
    reg         MEM_WB_alu_en;
    reg [31:0]  MEM_WB_alu_out;
    reg [31:0]  MEM_WB_rdata1;
    reg [31:0]  MEM_WB_rdata2;
    reg [31:0]  MEM_WB_IR;
    reg         MEM_WB_cmp_en;
    reg         MEM_WB_movz_en;
    reg         MEM_WB_sll_en;
    reg         MEM_WB_data_sram_en;
    reg [3:0]   MEM_WB_data_sram_wen;
    reg         MEM_WB_we;
    reg [4:0]   MEM_WB_waddr;
    reg [31:0]  MEM_WB_pc;
    reg         MEM_WB_invalid;
    reg [31:0]  MEM_WB_data_sram_rdata;
    reg [31:0]  MEM_WB_wdata;
    reg [31:0]  MEM_WB_data_sram_addr;
    reg [31:0]  MEM_WB_data_sram_wdata;
    
    //////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////     IF   ////////////////////////////////
    // IF段需要做的事，取出指令，放入指令存储器，计算npc
    //////////////////////////////////////////////////////////////////////////////
    
    // 遗留的隐患：1.使能信号能不能一直设定为1
    // 2. 是不是设定了太多寄存器导致一个时钟周期读不上来
    
    wire [31:0] jmp_addr;       // 从ID阶段接过来，传输跳转地址
    wire jmp;                   // 从ID阶段传过来，用于判断是不是要跳转
    wire [31:0] pc;
    wire [31:0] IF_ID_npc;
    wire [31:0] IF_ID_IR;
    
    // 程序计数器，用于记录指令地址
    // 内部有两个寄存器，分别是npc和pc
    // 增加输入信号，判断是不是发生了LW后ADD，之后想办法停止一周期取出指令，停止指令译码器的更新
    pc_register u_pc_register(
        .clk            (clk),          // 不受流水线管
        .jmp_addr       (jmp_addr),     // 在ID才能得到       
        .jmp            (jmp),          // 在ID才能得到
        .resetn         (resetn),       // 复位信号
        .npc            (npc),          // pc + 4
        .pc             (pc),          // 指令地址
        .inst_sram_en   (inst_sram_en),  // 指令存储器读使能
        .EX_MEM_IR      (ID_EX_IR),
        .ID_EX_IR       (IF_ID_IR)
    );
   
    assign inst_sram_addr = pc;
    assign IF_ID_npc = npc;
    assign IF_ID_IR = inst_sram_rdata;
  
      
    //////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////    ID   ////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////   

    wire we_decoder;        // 指令译码器给出的写使能
    wire [4:0] waddr;       // 寄存器写地址
    wire [4:0]  raddr1;     //寄存器读地址1
    wire [4:0]  raddr2;     //寄存器读地址2
    wire alu_en;            // alu使能
    wire [4:0] alu_card;    // alu功能区分
    // jmp在ID段被定义
    wire bbt;               // bbt信号
    wire sram_en;           // 将来才会正式赋给输出信号
    wire [3:0]  sram_wen; 
    wire movz_en;           // movz指令的使能
    wire sll_en;            // sll指令的使能
    wire cmp_en;            // cmp指令的使能
    wire [4:0] mem_wb_waddr;
    wire mem_wb_we;
    wire invalid;
    
    


    // 指令译码器
    // 没在内部设置任何段间寄存器，需要在外面进行更新
    inst_decoder u_inst_decoder(
        //input
        .inst       (IF_ID_IR),     // 指令寄存器，需要传下去
        .clk        (clk),          // 时钟，不归流水线管
        //output
        .wen        (we_decoder),   // 寄存器写是能的逻辑
        .waddr      (waddr),        // 寄存器写地址
        .raddr1     (raddr1),       // 寄存器读地址1
        .raddr2     (raddr2),       // 寄存器读地址2
        .alu_en     (alu_en),       // alu使能
        .alu_card   (alu_card),     // alu执行码
        .jmp        (jmp),          // j指令使能
        .bbt        (bbt),          // bbt指令使能    
        .data_sram_en   (sram_en), //数据存储器使能
        .data_sram_wen  (sram_wen),// 数据存储器写使能
        .movz_en        (movz_en),      // movz使能
        .sll_en         (sll_en),       // sll使能
        .cmp_en         (cmp_en),        // cmp使能
        .invalid        (invalid)       // invalid
    );
    
//    always @(posedge clk) begin
//         $display("Time %t: waddr: %h, IF_ID_IR: %h", $time, waddr, IF_ID_IR);
//    end
    
    
    // 寄存器堆
    regfile u_regfile(
        .clk        (clk),
        .raddr1     (raddr1),
        .rdata1     (rdata1),
        .raddr2     (raddr2),
        .rdata2     (rdata2),
        .we         (mem_wb_we),
        .waddr      (mem_wb_waddr),
        .wdata      (wdata)
    );
    
    // 计算跳转地址
    addr_calculator u_addr_calculator(
        .clk        (clk),
        .npc        (IF_ID_npc),
        .inst       (IF_ID_IR),
        .rdata1     (rdata1),
        .raddr2     (raddr2),
        .jmp        (jmp),
        .bbt        (bbt),
        .jmp_addr   (jmp_addr)
    );
    
    
    

    
    always @(posedge clk) begin
//        ID_EX_IR <= IF_ID_IR;
//        ID_EX_we <= we_decoder ;
//        ID_EX_waddr <= waddr;
//        ID_EX_alu_en <= alu_en;
//        ID_EX_alu_card <= alu_card;
//        ID_EX_data_sram_en <= sram_en;
//        ID_EX_data_sram_wen <= sram_wen;
//        ID_EX_sll_en <= sll_en;
//        ID_EX_cmp_en <= cmp_en;
//        ID_EX_rdata1 <= rdata1;
//        ID_EX_rdata2 <= rdata2;
//        ID_EX_pc     <= pc;
//        ID_EX_invalid<= invalid;
//        ID_EX_movz_en<= movz_en;
        
        // 流水线锁
        if (ID_EX_IR[31:26] == 6'b100011 & IF_ID_IR[31:26] == 6'b000000 & (ID_EX_IR[20:16] == IF_ID_IR[25:21] | ID_EX_IR[20:16] == IF_ID_IR[20:16]) ) begin
            // $display("Time %t: 预测到冲突，插入气泡. IF_ID_IR: %h, ID_EX_IR: %h",$time, IF_ID_IR, ID_EX_IR);
            ID_EX_IR <= 32'b0;
            ID_EX_we <= 0 ;
            ID_EX_waddr <= 0;
            ID_EX_alu_en <= 0;
            ID_EX_alu_card <= 0;
            ID_EX_data_sram_en <= 0;
            ID_EX_data_sram_wen <= 0;
            ID_EX_sll_en <= 0;
            ID_EX_cmp_en <= 0;
            ID_EX_rdata1 <= 0;
            ID_EX_rdata2 <= 0;
            // ID_EX_pc     <= 0;
            ID_EX_invalid<= 1;
            ID_EX_movz_en<= 0;
        end else begin
            // $display("Time %t: 气泡结束，正常. IF_ID_IR: %h, ID_EX_IR: %h",$time, IF_ID_IR, ID_EX_IR);
            ID_EX_IR <= IF_ID_IR;
            ID_EX_we <= we_decoder ;
            ID_EX_waddr <= waddr;
            ID_EX_alu_en <= alu_en;
            ID_EX_alu_card <= alu_card;
            ID_EX_data_sram_en <= sram_en;
            ID_EX_data_sram_wen <= sram_wen;
            ID_EX_sll_en <= sll_en;
            ID_EX_cmp_en <= cmp_en;
            ID_EX_rdata1 <= rdata1;
            ID_EX_rdata2 <= rdata2;
            ID_EX_pc     <= pc;
            ID_EX_invalid<= invalid;
            ID_EX_movz_en<= movz_en;
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////     EX   ////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////
    
    // 这是直接可以通过定向解决的
    wire    [31:0]      alu_data1;
    wire    [31:0]      alu_data2;
    
    
    assign alu_data1 = ({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (EX_MEM_IR[31:26] == 6'b000000) }} & EX_MEM_alu_out)  | 
                       ({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (EX_MEM_IR[31:26] == 6'b111110) }} & EX_MEM_wdata_cmp)| 
                       ({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == MEM_WB_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (MEM_WB_IR[31:26] == 6'b000000) }} & MEM_WB_wdata)         & ~({32{(ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (EX_MEM_IR[31:26] == 6'b000000) }}) & ~({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (EX_MEM_IR[31:26] == 6'b111110) }} )   | 
                       ({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == MEM_WB_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (MEM_WB_IR[31:26] == 6'b111110) }} & MEM_WB_wdata)           & ~({32{(ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (EX_MEM_IR[31:26] == 6'b111110) }}) & ~({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (EX_MEM_IR[31:26] == 6'b000000) }})  | 
                       ({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == MEM_WB_IR[20:16]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (MEM_WB_IR[31:26] == 6'b100011) }} & MEM_WB_data_sram_rdata) & ~({32{(ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (EX_MEM_IR[31:26] == 6'b000000) }}) & ~({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (EX_MEM_IR[31:26] == 6'b111110) }} ) |
                       (ID_EX_rdata1 & ~({32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == EX_MEM_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & ((EX_MEM_IR[31:26] == 6'b000000) | (EX_MEM_IR[31:26] == 6'b111110)) }} | {32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == MEM_WB_IR[15:11]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & ((MEM_WB_IR[31:26] == 6'b000000) | (MEM_WB_IR[31:26] == 6'b111110)) }} | {32{(ID_EX_IR[25:21] != 0) & (ID_EX_IR[25:21] == MEM_WB_IR[20:16]) & ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ) & (MEM_WB_IR[31:26] == 6'b100011) }})) ;
                       
    assign alu_data2 = ({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (EX_MEM_IR[31:26] == 6'b000000) }} & EX_MEM_alu_out)  | 
                       ({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (EX_MEM_IR[31:26] == 6'b111110) }} & EX_MEM_wdata_cmp)  |
                       ({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == MEM_WB_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (MEM_WB_IR[31:26] == 6'b000000) }} & MEM_WB_wdata)         & ~({32{(ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (EX_MEM_IR[31:26] == 6'b000000) }}) & ~({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (EX_MEM_IR[31:26] == 6'b111110) }} ) |
                       ({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == MEM_WB_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (MEM_WB_IR[31:26] == 6'b111110) }} & MEM_WB_wdata)           & ~({32{(ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (EX_MEM_IR[31:26] == 6'b111110) }})   & ~({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (EX_MEM_IR[31:26] == 6'b000000) }} ) |  
                       ({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == MEM_WB_IR[20:16]) & (ID_EX_IR[31:26] == 6'b000000) & (MEM_WB_IR[31:26] == 6'b100011) }} & MEM_WB_data_sram_rdata )& ~({32{(ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (EX_MEM_IR[31:26] == 6'b000000) }}) & ~({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & (EX_MEM_IR[31:26] == 6'b111110) }}) |
                       (ID_EX_rdata2 & ~({32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & ((EX_MEM_IR[31:26] == 6'b000000) | (EX_MEM_IR[31:26] == 6'b111110) ) }} | {32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == MEM_WB_IR[15:11]) & (ID_EX_IR[31:26] == 6'b000000) & ((MEM_WB_IR[31:26] == 6'b000000)| (MEM_WB_IR[31:26] == 6'b111110)) }} | {32{(ID_EX_IR[20:16] != 0) & (ID_EX_IR[20:16] == MEM_WB_IR[20:16]) & (ID_EX_IR[31:26] == 6'b000000) & (MEM_WB_IR[31:26] == 6'b100011) }}));
    
//    always @(posedge clk) begin
//         $display("Time %t: alu_data1: %h, ID_EX_rdata1: %h, alu_data2: %h,ID_EX_rdata2: %h, alu_out: %h", $time, alu_data1, ID_EX_rdata1, alu_data2, ID_EX_rdata2, alu_out);
//    end
    
//    always @(posedge clk) begin
//        $display("Time %t: j1: %b, j2: %b, j3: %b, j4: %b", $time, (ID_EX_IR[20:16] == EX_MEM_IR[15:11]), ((ID_EX_IR[31:26] == 6'b000000) | (ID_EX_IR[31:26] == 6'b101011) | (ID_EX_IR[31:26] == 6'b100011) | (ID_EX_IR[31:26] == 6'b111111) ), (EX_MEM_IR[31:26] == 6'b000000), EX_MEM_cmp_en);
//    end
    
    wire [31:0] alu_out_part;
    wire [31:0] alu_out;
    wire [31:0] cmp_data1;
    wire [31:0] cmp_data2;
    
    my_alu u_alu(
        .A          (alu_data1),
        .B          (alu_data2),
        .Cin        (0     ),
        .Card       (ID_EX_alu_card),
        .F          (alu_out_part)
    );
    
                                                  // ({32{EX_MEM_sll_en}} & (EX_MEM_alu_data2 << EX_MEM_IR[10:6])) | 
    assign alu_out =({32{~ID_EX_sll_en}} & alu_out_part) | ({32{ID_EX_sll_en}} & (alu_data2 << ID_EX_IR[10:6]));
    
    // 在执行阶段提前将数据存储器需要的内存读写使能赋出去
    assign data_sram_en = ID_EX_data_sram_en;
    assign data_sram_wen = ID_EX_data_sram_wen;
    
    // 数据存储器内存读地址，需要传递到MEM阶段
    assign data_sram_addr = {32{ID_EX_data_sram_en & ~((EX_MEM_data_sram_en == 1) & (EX_MEM_data_sram_wen != 4'b1111) & ID_EX_IR[25:21] == EX_MEM_IR[20:16] )}} & (alu_data1 + {{16{ID_EX_IR[15]}}, ID_EX_IR[15:0]})     |
                            {32{ID_EX_data_sram_en &  ((EX_MEM_data_sram_en == 1) & (EX_MEM_data_sram_wen != 4'b1111) & ID_EX_IR[25:21] == EX_MEM_IR[20:16] )}} & (data_sram_rdata + {{16{ID_EX_IR[15]}}, ID_EX_IR[15:0]}) ;    //sw或lw
    // 数据存储器所写入的数据，需要传递到MEM阶段
    assign data_sram_wdata = ({32{(ID_EX_data_sram_wen == 4'b1111) & ((ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (EX_MEM_IR[31:26] == 6'b000000 ))}} & EX_MEM_alu_out)  |
                             ({32{(ID_EX_data_sram_wen == 4'b1111) & ((ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (EX_MEM_IR[31:26] == 6'b111110 ))}} & EX_MEM_wdata_cmp)  |
                             {32{(ID_EX_data_sram_wen == 4'b1111) & ~((ID_EX_IR[20:16] == EX_MEM_IR[15:11]) & (EX_MEM_IR[31:26] == 6'b000000 | EX_MEM_IR[31:26] == 6'b111110))}} & ID_EX_rdata2;

//    always @(posedge clk) begin
//           $display("Time %t: data_sram_wdata: %h, data_sram_addr: %h, ID_EX_rdata2: %h, EX_MEM_wdata_cmp: %h", $time,  data_sram_wdata,data_sram_addr, ID_EX_rdata2, EX_MEM_wdata_cmp );
//    end
    
//    always @(posedge clk) begin
//           $display("Time %t: ex_cmp_data1: %h, MEM_WB_wdata: %h, ex_cmp_data2: %h, ID_EX_rdata1: %h, ID_EX_rdata2: %h, ID_EX_IR: %h, EX_MEM_IR: %h", $time, ex_cmp_data1, EX_MEM_alu_out, ex_cmp_data2, ID_EX_rdata1, ID_EX_rdata2, ID_EX_IR, EX_MEM_IR);
//    end
    
    // 与cmp相关的数据冲突
    assign cmp_data2 = ({32{(MEM_WB_IR[31:26] == 6'b000000) & (MEM_WB_IR[15:11] == EX_MEM_IR[25:21])}} & EX_MEM_alu_out) | ( (~{32{(MEM_WB_IR[31:26] == 6'b000000) & (MEM_WB_IR[15:11] == EX_MEM_IR[25:21])}}) & ID_EX_rdata2);
    assign cmp_data1 = ({32{(MEM_WB_IR[31:26] == 6'b000000) & (MEM_WB_IR[15:11] == EX_MEM_IR[20:16])}} & EX_MEM_alu_out) | ( (~{32{(MEM_WB_IR[31:26] == 6'b000000) & (MEM_WB_IR[15:11] == EX_MEM_IR[20:16])}}) & ID_EX_rdata1);
    
    
    assign wdata_cmp = {32{ID_EX_cmp_en}} & { {22{1'b0}}, ~(cmp_data1 <= cmp_data2) , ~($signed(cmp_data1) <= $signed(cmp_data2)) ,~(cmp_data1 < cmp_data2) , ~($signed(cmp_data1) < $signed(cmp_data2)) ,~(cmp_data1 == cmp_data2) ,(cmp_data1 <= cmp_data2) ,($signed(cmp_data1) <= $signed(cmp_data2)) ,(cmp_data1 < cmp_data2) , ($signed(cmp_data1) < $signed(cmp_data2)) ,(cmp_data1 == cmp_data2)};
    
    always @(posedge clk) begin
        // 寄存器的正常更新，不涉及旁路
        EX_MEM_IR               <=  ID_EX_IR;
        EX_MEM_we               <=  ID_EX_we;
        EX_MEM_waddr            <=  ID_EX_waddr;
        EX_MEM_movz_en          <=  ID_EX_movz_en;
        EX_MEM_sll_en           <=  ID_EX_sll_en;
        EX_MEM_cmp_en           <=  ID_EX_cmp_en;
        EX_MEM_alu_out          <=  alu_out; 
        EX_MEM_rdata1           <=  ID_EX_rdata1;
        EX_MEM_rdata2           <=  ID_EX_rdata2;
        EX_MEM_data_sram_en     <=  ID_EX_data_sram_en;
        EX_MEM_data_sram_wen    <=  ID_EX_data_sram_wen;
        EX_MEM_alu_en           <=  ID_EX_alu_en;
        EX_MEM_pc               <=  ID_EX_pc;
        EX_MEM_invalid          <=  ID_EX_invalid;
        EX_MEM_wdata_cmp        <=  wdata_cmp;
        EX_MEM_data_sram_addr   <=  data_sram_addr;
        EX_MEM_data_sram_wdata  <=  data_sram_wdata;
        EX_MEM_alu_data1        <=  alu_data1;
        EX_MEM_alu_data2        <=  alu_data2;

        
//        // 流水线锁
//        if (EX_MEM_IR[31:26] == 6'b100011 & ID_EX_IR[31:26] == 6'b000000 & (EX_MEM_IR[20:16] == ID_EX_IR[25:21] | EX_MEM_IR[20:16] == ID_EX_IR[20:16]) ) begin
//            EX_MEM_IR <= 32'b0;
//        end else begin
//            EX_MEM_IR <= ID_EX_IR;
//        end
        
    end
    
    //////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////     MEM   ///////////////////////////////
    //////////////////////////////////////////////////////////////////////////////
    
    wire we_movz;      // movz指令给出的写使能
    assign we_movz = ((EX_MEM_IR[20:16] != MEM_WB_IR[15:11]) & (EX_MEM_rdata2 == 32'b0) & EX_MEM_movz_en) |
                      ((EX_MEM_IR[20:16] == MEM_WB_IR[15:11]) & (MEM_WB_wdata == 32'b0) & EX_MEM_movz_en);
    
    assign mem_wb_we = (EX_MEM_we | we_movz) & ~EX_MEM_invalid;       // 译码器没法读寄存器，所以只能判断部分写使能
    
//    always @(posedge clk) begin
//         $display("Time %t: waddr: %h, mem_wb_we: %h, EX_MEM_we: %h, we_movez: %h,EX_MEM_movz_en: %h, EX_MEM_rdata2: %h, IF_ID_IR: %h", $time, EX_MEM_waddr,mem_wb_we,EX_MEM_we, we_movz, EX_MEM_movz_en,EX_MEM_rdata2, EX_MEM_IR);
//    end
    
    assign mem_wb_waddr = EX_MEM_waddr;
    // 读的时候
    assign wdata = (({32{ ~((MEM_WB_data_sram_wen == 4'b1111)& ~((MEM_WB_data_sram_en == 1) & (MEM_WB_data_sram_addr == EX_MEM_IR[20:16])) & (MEM_WB_data_sram_addr == EX_MEM_data_sram_addr)) & EX_MEM_data_sram_en & ~(EX_MEM_data_sram_wen == 4'b1111)}} & data_sram_rdata) |         // 一般的内存读
                   ({32{ ((MEM_WB_data_sram_wen == 4'b1111) & (MEM_WB_data_sram_addr == EX_MEM_data_sram_addr)) & EX_MEM_data_sram_en & ~(EX_MEM_data_sram_wen == 4'b1111)}} & MEM_WB_data_sram_wdata) |    // sw后的内存读
                   ({32{EX_MEM_alu_en}} & EX_MEM_alu_out) | 
                   ({32{we_movz}} & EX_MEM_alu_data1) | 
                   // ({32{EX_MEM_sll_en}} & (EX_MEM_alu_data2 << EX_MEM_IR[10:6])) | 
                   ({32{EX_MEM_cmp_en}} & EX_MEM_wdata_cmp)) & {32{~EX_MEM_invalid}};
                        

//    always @(posedge clk) begin
//           $display("Time %t: wdata: %h, data_sram_wdata: %h , MEM_WB_wdata: %h,data_sram_rdata: %h, EX_MEM_data_sram_addr: %h ", $time, wdata, data_sram_wdata, MEM_WB_wdata,data_sram_rdata, EX_MEM_data_sram_addr);
//    end
    
    
    
    always @(posedge clk) begin
        MEM_WB_movz_en  <=  EX_MEM_movz_en;
        MEM_WB_alu_en   <=  EX_MEM_alu_en;
        MEM_WB_alu_out  <=  EX_MEM_alu_out;
        MEM_WB_rdata1   <=  EX_MEM_rdata1;
        MEM_WB_rdata2   <=  EX_MEM_rdata2;
        MEM_WB_IR       <=  EX_MEM_IR;
        MEM_WB_cmp_en   <=  EX_MEM_cmp_en;
        MEM_WB_movz_en  <=  EX_MEM_movz_en;
        MEM_WB_sll_en   <=  EX_MEM_sll_en;
        MEM_WB_we       <=  EX_MEM_we;
        MEM_WB_data_sram_en     <=  EX_MEM_data_sram_en;
        MEM_WB_data_sram_wen    <=  EX_MEM_data_sram_wen;
        MEM_WB_waddr            <=  EX_MEM_waddr;
        MEM_WB_pc               <=  EX_MEM_pc;
        MEM_WB_invalid          <=  EX_MEM_invalid;
        MEM_WB_data_sram_rdata  <=  data_sram_rdata;
        MEM_WB_wdata            <=  wdata;
        MEM_WB_data_sram_addr   <=  EX_MEM_data_sram_addr;
        MEM_WB_data_sram_wdata  <=  EX_MEM_data_sram_wdata;
    end
    
    //////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////     WB   ////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////
    
    // 写回的数据分为三个部分 cmp, movz指令在ID得到，运算指令在exe得到，sw和lw指令在MEM得到
    // 但是写回的信号可以直接在ID段得到
    

//    assign we_movz = ((MEM_WB_rdata2 == 0) & MEM_WB_movz_en);
//    assign we = MEM_WB_we | we_movz;       // 译码器没法读寄存器，所以只能判断部分写使能
    
    // assign mem_wb_waddr = MEM_WB_waddr;
    // cmp指令下的写回数据
    // assign wdata_cmp = {32{MEM_WB_cmp_en}} & { {22{1'b0}}, ~(MEM_WB_rdata1 <= MEM_WB_rdata2) , ~($signed(MEM_WB_rdata1) <= $signed(MEM_WB_rdata2)) ,~(MEM_WB_rdata1 < MEM_WB_rdata2) , ~($signed(MEM_WB_rdata1) < $signed(MEM_WB_rdata2)) ,~(MEM_WB_rdata1 == MEM_WB_rdata2) ,(MEM_WB_rdata1 <= MEM_WB_rdata2) ,($signed(MEM_WB_rdata1) <= $signed(MEM_WB_rdata2)) ,(MEM_WB_rdata1 < MEM_WB_rdata2) , ($signed(MEM_WB_rdata1) < $signed(MEM_WB_rdata2)) ,(MEM_WB_rdata1 == MEM_WB_rdata2)};
    // 准备写入寄存器的数据
    // assign wdata = ({32{MEM_WB_data_sram_en & ~(MEM_WB_data_sram_wen == 4'b1111)}} & data_sram_rdata) | ({32{MEM_WB_alu_en}} & MEM_WB_alu_out) | ({32{we_movz}} & MEM_WB_rdata1) | ({32{MEM_WB_sll_en}} & (MEM_WB_rdata2 << MEM_WB_IR[10:6])) | ({32{MEM_WB_cmp_en}} & wdata_cmp);
    
    // 遗留隐患：不知道能不能直接用data_sram_rdata
    
    
    assign debug_wb_pc = MEM_WB_pc;
    assign debug_wb_rf_wen = mem_wb_we;
    assign debug_wb_rf_wnum = mem_wb_waddr;
    assign debug_wb_rf_wdata = wdata;
    
endmodule
