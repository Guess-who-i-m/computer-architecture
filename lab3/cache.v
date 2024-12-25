`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/18 15:20:03
// Design Name: 
// Module Name: cache
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


module cache (
    input            clk             ,  // 时钟
    input            resetn          ,  // 低有效复位信号

    //  Sram-Like接口信号，用于CPU访问Cache
    input         cpu_req      ,    //由CPU发送至Cache
    input  [31:0] cpu_addr     ,    //由CPU发送至Cache
    output [31:0] cache_rdata  ,    //由Cache返回给CPU
    output        cache_addr_ok,    //由Cache返回给CPU
    output        cache_data_ok,    //由Cache返回给CPU

    //  AXI接口信号，用于Cache访问主存
    output [3 :0] arid   ,              //Cache向主存发起读请求时使用的AXI信道的id号
    output [31:0] araddr ,              //Cache向主存发起读请求时所使用的地址
    output        arvalid,              //Cache向主存发起读请求的请求信号
    input         arready,              //读请求能否被接收的握手信号

    input  [3 :0] rid    ,              //主存向Cache返回数据时使用的AXI信道的id号
    input  [31:0] rdata  ,              //主存向Cache返回的数据
    input         rlast  ,              //是否是主存向Cache返回的最后一个数据
    input         rvalid ,              //主存向Cache返回数据时的数据有效信号
    output        rready                //标识当前的Cache已经准备好可以接收主存返回的数据
);

    // 一些宏观的全局变量
    wire miss;                          //用来描述IF2判断的是否命中
    wire stop;

    /*TODO：完成指令Cache的设计代码*/
    // -------------IF1--------------
    // 读取tag和二路数据存储器中的数据
    
    // 二路数据存储器
    // 数据存储器的特点是在IF1直接异步读取，在IF2需要同步写入
    wire    [9:0]   way0_raddr;
    reg     [9:0]   way0_waddr;
    wire            way0_ren;
    reg             way0_wen;
    wire    [31:0]  way0_rdata;
    reg     [31:0]  way0_wdata;
    reg             flag;
    
    
    // 对wire类型进行连线
    assign way0_raddr = cpu_addr[11:2];             // 以cpu地址的[11:2]作为cache访存地址，包括了index6位和offset高3位（一次取一字）
    assign way0_ren   = cpu_req & ~stop;            // 只有在cpu请求，并且上一周期的指令命中的时候才可以读取
    
    blk_mem_gen_0 way0(
        .clka       (clk),
        .clkb       (clk),
        .addra      (way0_waddr),
        .addrb      (way0_raddr),
        .wea        (way0_wen),
        .enb        (way0_ren),
        .dina       (way0_wdata),
        .doutb      (way0_rdata)
    );
    
    // way1
    wire    [9:0]   way1_raddr;
    reg     [9:0]   way1_waddr;
    wire            way1_ren;
    reg             way1_wen;
    wire    [31:0]  way1_rdata;
    reg     [31:0]  way1_wdata;
    

    
    // 对wire类型进行连线
    assign way1_raddr = cpu_addr[11:2];             // 以cpu地址的[11:2]作为cache访存地址，包括了index6位和offset高3位（一次取一字）
    assign way1_ren   = cpu_req & ~stop;            // 只有在cpu请求，并且上一周期的指令命中的时候才可以读取
    
    blk_mem_gen_0 way1(
        .clka       (clk),
        .clkb       (clk),
        .addra      (way1_waddr),
        .addrb      (way1_raddr),
        .wea        (way1_wen),
        .enb        (way1_ren),
        .dina       (way1_wdata),
        .doutb      (way1_rdata)
    );
    
    // 接下来访问tag存储器
    //首先声明需要的变量
    reg         tag0_wen;
    reg [19:0]  tag0_wdata;
    reg [6:0]   tag0_windex;
    wire        way0_hit;
    wire        way0_valid;
    

    
    icache_tagv_table tags0(
        .clk            (clk),
        .resetn         (resetn),
        .wen            (tag0_wen),
        .valid_wdata    (1),
        .tag_wdata      (tag0_wdata),
        .windex         (tag0_windex),
        .rden           (way0_ren),
        .cpu_addr       (cpu_addr),
        .hit            (way0_hit),
        .valid          (way0_valid)
    );
    
    //首先声明需要的变量
    reg         tag1_wen;
    reg [19:0]  tag1_wdata;
    reg [6:0]   tag1_windex;
    wire        way1_hit;
    wire        way1_valid;
    

    
    icache_tagv_table tags1(
        .clk            (clk),
        .resetn         (resetn),
        .wen            (tag1_wen),
        .valid_wdata    (1),
        .tag_wdata      (tag1_wdata),
        .windex         (tag1_windex),
        .rden           (way1_ren),
        .cpu_addr       (cpu_addr),
        .hit            (way1_hit),
        .valid          (way1_valid)
    );
    
    
    // -----------IF1/IF2------------
    // 将IF1读取到的内容全部存入段间寄存器中
    // 首先声明段间寄存器
    wire[31:0]  IF1_IF2_way0_rdata;
    wire[31:0]  IF1_IF2_way1_rdata;
    reg [31:0]  IF1_IF2_cpu_addr;
    
    assign IF1_IF2_way0_rdata = way0_rdata;
    assign IF1_IF2_way1_rdata = way1_rdata;


    
    
    // ----------------IF2------------------------
    wire[19:0]  cpu_addr_tag;
    wire[6:0]   cpu_addr_index;
    wire[4:0]   cpu_addr_offset;
    
    assign cpu_addr_tag    = IF1_IF2_cpu_addr[31:12];
    assign cpu_addr_index  = IF1_IF2_cpu_addr[11:5];
    assign cpu_addr_offset = IF1_IF2_cpu_addr[4:0];
    
    // 在第二周期能够判断出来，没命中
    // 虽两个hit是wire，但是icache_tagv_table中封装了寄存器
    assign miss = ~way0_hit & ~way1_hit;  
    
    // 维护两个128行的LRU记录
    reg way0_used   [127:0];
    reg way1_used   [127:0];

    // 初始化这两个寄存器
    genvar i;
    generate
        for(i=0; i < 128; i = i + 1) begin
            initial begin
                way0_used[i] = 0;      
                way1_used[i] = 0;
            end
        end
    endgenerate
    
    // 接下来是IF2所维护的状态机
    reg [2:0]   state;
    
    // 用于实现cache与cpu交互的寄存器
    reg         reg_cache_data_ok;
    reg [31:0]  reg_cache_rdata;
    
    assign cache_data_ok = reg_cache_data_ok;
    assign cache_rdata   = reg_cache_rdata;
    assign cache_address_ok = ~miss ;
    
    // 用于实现cache与内存交互的寄存器
    reg         reg_arvalid;
    reg [3:0]   reg_arid;
    reg         reg_rready;
    reg [31:0]  reg_araddr;
    
    assign      arvalid = reg_arvalid;
    assign      arid    = reg_arid;
    assign      rready  = reg_rready;
    assign      araddr  = reg_araddr;
    

    
    
    // 用于实现握手阶段的自加
    wire [9:0]  next_way0_waddr;
    wire [9:0]  next_way1_waddr;
    
    assign next_way0_waddr = way0_waddr + 1;
    assign next_way1_waddr = way1_waddr + 1;
    
    // flag 标志已经进入了IF1
    // miss 标志1和2同时不命中
    // find 标志已经成功从内存中找到，并且不需要再停顿
    reg find;
    assign stop = flag & miss & ~find;
    
    assign cache_addr_ok = resetn & ~stop ;
    
    // LRU的替换策略，若第1路最近没被用过或者第1路此时无效，则直接用第一路写入
    wire replace;
    reg  replace_0;
    reg  replace_1;
    assign replace = ~way1_used[cpu_addr_index] || ~way1_valid; 
    
    always @(posedge clk) begin
        if (~resetn) begin
            // 初始化用于调用第0路的寄存器
            way0_waddr  <= 0;
            way0_wen    <= 0;
            way0_wdata  <= 0;
            // 初始化用于调用第1路的寄存器
            way1_waddr  <= 0;
            way1_wen    <= 0;
            way1_wdata  <= 0;
            // 标志流水线建立
            flag        <= 0;
            // 初始化用于访问第0路tag的寄存器
            tag0_wen    <= 0;
            tag0_wdata  <= 0;
            tag0_windex <= 0;
            // 初始化用于访问第1路tag的寄存器
            tag1_wen    <= 0;
            tag1_wdata  <= 0;
            tag1_windex <= 0;
            // 段间寄存器
            IF1_IF2_cpu_addr   <= 0;
            // 用于完成cpu和内存之间的交互
            reg_arvalid <= 0;
            reg_arid    <= 0;
            reg_rready  <= 0;
            reg_araddr  <= 0;
        
            state <= 0;
            find  <= 0;
        end else begin
            // IF1，如果没有停止就进行段间寄存器的更新
            if (~stop) begin
                IF1_IF2_cpu_addr   <= cpu_addr;
                flag               <= 1;
            end
            
            case (state)
                // 状态0 判断是否命中，如果命中直接将数据返回
                0: begin
                    find <= 0;
                    if (way0_hit || way1_hit) begin
                        // 如果cache命中
                        reg_cache_data_ok <= 1;
                        reg_cache_rdata <= way0_hit ? IF1_IF2_way0_rdata : IF1_IF2_way1_rdata;
                        way0_used[cpu_addr_index] <= way0_hit;
                        way1_used[cpu_addr_index] <= way1_hit;
                    end else begin
                        // 此时cache没有命中
                        // 首先确定要替换掉哪一路，并更新LRU标记
                        if (replace == 1) begin
                            way1_used[cpu_addr_index] <= 1;
                            way0_used[cpu_addr_index] <= 0;
                        end else begin
                            way0_used[cpu_addr_index] <= 1;
                            way1_used[cpu_addr_index] <= 0;
                        end
                        
                        replace_0 <= replace;
                        
                        // 随后停止让CPU向cache输送地址，停止IF1阶段的存储器读取
                        // 这两步由组合逻辑实现
                        // 停止向CPU输送数据
                        reg_cache_data_ok <= 0;
                        
                        // 接下来开始处理与内存交互的逻辑
                        reg_arvalid <= 1;       // 拉高arvalid
                        reg_arid    <= 0;       // 设置arid
                        reg_araddr  <= {IF1_IF2_cpu_addr[31:5], 5'b00000};          //这里存疑
                        
                        // 设置好读取的地址,并对应写回tag
                        if (replace == 1) begin
                            way1_waddr <= {cpu_addr_index, 3'b000} - 1;     //设置-1是为了后续的自加逻辑融洽
         
                        end else begin
                            way0_waddr <= {cpu_addr_index, 3'b000} - 1;     //设置-1是为了后续的自加逻辑融洽

                        end
                        // 完成上述操作之后，将状态切换到1
                        state <= 1;
                    end
                    
                end
                // 状态1
                // 拉高arvalid后，等待arready
                // 等待到arready后，只需要拉低arvalid，拉高rready并跳转到状态2
                1: begin
                    
                    if (arready == 1) begin
                        reg_arvalid <= 0;
                        reg_rready  <= 1;
                        state       <= 2;
                        if (replace_0 == 1) begin
                            // 接下来写回tag
                            tag1_wen <= 1;
                            tag1_windex <= cpu_addr_index;
                            tag1_wdata  <= cpu_addr_tag;
                        end else begin
                            //接下来写回tag
                            tag0_wen <= 1;
                            tag0_windex <= cpu_addr_index;
                            tag0_wdata  <= cpu_addr_tag;
                        end
                        replace_1 <= replace_0;
                    end
                end
                
                // 状态2
                // 此时已经建立好了握手状态，只需要传输数据即可
                2: begin
                    tag0_wen <= 0;
                    tag1_wen <= 0;
                    if (rvalid) begin
                        // 找到选择的一路
                        if (replace_1) begin
                            // 选择写入第1路 
                            way1_waddr <= next_way1_waddr;
                            way1_wen   <= 1;
                            way1_wdata <= rdata;
                                
                            // 如果找到了对应的要找的数据，先存入寄存器中，但不返回
                            // 等全部数据得到之后再返回给cpu
                            if (next_way1_waddr == {cpu_addr_index, cpu_addr_offset[4:2]}) begin
                                reg_cache_rdata <= rdata;
                            end
                           
                        end else begin
                            // 选择写入第0路
                            way0_waddr <= next_way0_waddr;
                            way0_wen   <= 1;
                            way0_wdata <= rdata;
                                
                            // 如果找到了对应的要找的数据，先存入寄存器中，但不返回
                            // 等全部数据得到之后再返回给cpu
                            if (next_way0_waddr == {cpu_addr_index, cpu_addr_offset[4:2]}) begin
                                reg_cache_rdata <= rdata;
                            end
                                                        
                        end
                        
                        // 接收到了最后一块的信号，那么将rready拉低，状态跳转到3
                        if (rlast) begin
                            reg_rready <= 0;
                            state <= 3;
                        end
                    end
                end
                
                // 状态3
                // 等待最后一个周期将数据返回，并将数据返回给cpu
                3: begin
                    way0_wen <= 0;
                    way1_wen <= 0;
                    state <= 4;
                    
                    find <= 1;
                end
                
                4: begin
                    find <= 0;
                    reg_cache_data_ok <= 1;
                    state <= 0;
                end
                
            endcase
        end
    end

endmodule
