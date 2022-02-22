`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    input  [0                  :0] data_sram_data_ok,
    //add block and bypass code
    output [`MS_TO_ID_BYQ_WD -1:0] ms_to_id_byp_block,
    //Int
    output [0                  :0] ms_ex,
    output [0                  :0] ms_ertn,
    //output [0                  :0] ms_inst_csrrd,
    //output [0                  :0] ms_inst_csrwr,
    //output [0                  :0] ms_inst_csrxchg,
    //output [0:                  0] ms_inst_rdcntid,
    output [3                  :0] ms_to_ds_csr_inst,
    input  [0                  :0] ws_ertn,
    input  [0                  :0] ws_ex,
    //csr
    output [13                 :0] ms_csr_num,
    output [ 4                 :0] ms_tlbop  
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        need_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [ 2:0] ms_store_op;
wire [ 4:0] ms_load_op;
wire [31:0] mem_result;
wire [31:0] ms_final_result;
//Lab 8 add code, es_to_ms bus ADD signals!!!!
wire [31:0] ms_rj_value;
wire [31:0] ms_rkd_value;
wire [31:0] ms_inst;
wire [31:0] lb_result;
wire [31:0] lbu_result;
wire [31:0] lh_result;
wire [31:0] lhu_result;
wire [31:0] ms_rdata;

wire [ 4:0] ms_to_id_dest;
wire        ms_wen;
wire [31:0] ms_to_id_res;
wire        ms_blk;

wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;
wire        ms_inst_csrrd;
wire        ms_inst_csrwr;
wire        ms_inst_csrxchg;
wire        ms_inst_rdcntid;

wire [5: 0] ms_ecode;
wire [8: 0] ms_esubcode;
wire        ms_has_int;
wire        ms_counter_op;
wire        has_ale;

wire [ 4:0] ms_tlb_op;
wire [ 4:0] ms_invtlb_op;
wire [36:0] tlb_to_es_bus;

reg  [31:0] data_buf;
reg         data_buf_valid;
reg         ms_data_invalid;
wire        ms_clear;
wire [2:0]  fs_tlb_ex;
wire [4:0]  es_tlb_ex;

assign {es_tlb_ex      , //253:249
        fs_tlb_ex      , //248:246
        tlb_to_es_bus  , //245:209
        ms_invtlb_op   , //208:204
        ms_tlb_op      , //203:199
        has_ale        , //198:198
        ms_counter_op  ,  //197:197 
        ms_esubcode    ,  //196:188
        ms_ecode       ,  //187:182
        inst_syscall   ,  //181:181
        ms_has_int     ,  //180:180
        ms_ex          ,  //179:179
        inst_ertn      ,  //178:178
        ms_inst        ,  //177:146
        inst_csrxchg   ,  //145:145
        inst_csrwr     ,  //144:144
        inst_csrrd     ,  //143:143
        ms_rkd_value   ,  //142:111
        ms_rj_value    ,  //110:79
        ms_load_op     ,  //78:74
        ms_store_op    ,  //73:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

assign ms_ertn = inst_ertn & ms_valid;
//We need to add signals in the ms_to_ws_bus
assign ms_to_ws_bus = {es_tlb_ex      ,  //243:239
                       fs_tlb_ex      ,  //238:236
                       tlb_to_es_bus  ,  //235:199
                       ms_invtlb_op   ,  //198:194
                       ms_tlb_op      ,  //193:189
                       ms_counter_op  ,  //188:188
                       ms_esubcode    ,  //187:179
                       ms_ecode       ,  //178:173
                       inst_syscall   ,  //172:172
                       ms_has_int     ,  //171:171
                       ms_ex          ,  //170:170
                       inst_ertn      ,  //169:169
                       ms_inst        ,  //168:137
                       inst_csrxchg   ,  //136:136
                       inst_csrwr     ,  //135:135
                       inst_csrrd     ,  //134:134
                       ms_rkd_value   ,  //133:102
                       ms_rj_value    ,  //101:70
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };
                      
assign ms_to_id_byp_block = {ms_wen,
                             ms_to_id_dest,
                             ms_final_result,
                             ms_blk
                             };
                      
assign ms_to_ds_csr_inst = {ms_inst_csrrd,
                            ms_inst_csrwr,
                            ms_inst_csrxchg,
                            ms_inst_rdcntid
                            };

assign ms_inst_csrrd = inst_csrrd & ms_valid;
assign ms_inst_csrwr = inst_csrwr & ms_valid;
assign ms_inst_csrxchg = inst_csrxchg & ms_valid;

assign need_mem = ms_res_from_mem | ((|ms_store_op) & ~has_ale);
assign ms_ready_go    = (data_sram_data_ok | data_buf_valid | ~need_mem ) & ~ms_data_invalid;
assign ms_allowin     = !ms_valid | ms_ready_go & ws_allowin;
assign ms_to_ws_valid = ms_valid & ms_ready_go & ~ws_ertn & ~ws_ex;
always @(posedge clk) begin
    if (reset /*|| ~ws_ertn || ~ws_ex*/) begin
        ms_valid <= 1'b0;
    end
    else if (ws_ertn | ws_ex) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid & ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end
//Lab 7 change code
assign ms_rdata = (ms_valid & data_buf_valid)? data_buf : data_sram_rdata;

assign lb_result = (ms_alu_result[1:0] == 2'b00)? {{24{ms_rdata[7]}},ms_rdata[7:0]}:
                   (ms_alu_result[1:0] == 2'b01)? {{24{ms_rdata[15]}},ms_rdata[15:8]}:
                   (ms_alu_result[1:0] == 2'b10)? {{24{ms_rdata[23]}},ms_rdata[23:16]}:
                                                  {{24{ms_rdata[31]}},ms_rdata[31:24]}  ;
assign lbu_result = (ms_alu_result[1:0] == 2'b00)? {24'b0,ms_rdata[7:0]}:
                    (ms_alu_result[1:0] == 2'b01)? {24'b0,ms_rdata[15:8]}:
                    (ms_alu_result[1:0] == 2'b10)? {24'b0,ms_rdata[23:16]}:
                                                   {24'b0,ms_rdata[31:24]}  ;
assign lhu_result = (ms_alu_result[1] == 1'b0)? {16'b0,ms_rdata[15:0]}:{16'b0,ms_rdata[31:16]};   
assign lh_result  = (ms_alu_result[1] == 1'b0)? {{16{ms_rdata[15]}},ms_rdata[15:0]}:
                                               {{16{ms_rdata[31]}},ms_rdata[31:16]};   


assign mem_result = ms_load_op[4] ? data_sram_rdata:
                    ms_load_op[3] ? lb_result      :
                    ms_load_op[2] ? lh_result:
                    ms_load_op[1] ? lbu_result: lhu_result;
                

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;

//add block and bypass code
assign ms_to_id_dest = ms_dest;
assign ms_wen        = ms_gr_we & ms_to_ws_valid & ms_valid;
assign ms_to_id_res  = ms_final_result;
assign ms_blk = ms_valid & ms_res_from_mem;
assign ms_inst_rdcntid = ms_counter_op & ms_valid;
//Sram control signals
//Buffer
always @(posedge clk) begin
    if (reset) begin
        data_buf_valid <= 1'b0;
    end 
    else if (ws_ertn | ws_ex) begin
        data_buf_valid <= 1'b0;
    end
    else if (ms_valid & data_sram_data_ok & ~ws_allowin) begin
        data_buf_valid <= 1'b1;
    end
    else if (ms_to_ws_valid & ws_allowin) begin
        data_buf_valid <= 1'b0;
    end
end
always @(posedge clk) begin
    if(reset) begin
        data_buf <= 32'b0;
    end
    else if (ms_valid & data_sram_data_ok & ~ws_allowin) begin
        data_buf <= mem_result;
    end
end
//Cancel
assign ms_clear = ws_ertn | ws_ex;

always @(posedge clk) begin
    if (reset) begin
        ms_data_invalid <= 1'b0;
    end
    else if (ms_clear & es_to_ms_valid) begin
        ms_data_invalid <= 1'b1;
    end
    else if (ms_clear & ~ms_allowin & ~ms_ready_go) begin
        ms_data_invalid <= 1'b1;
    end
    else if (data_sram_data_ok) begin
        ms_data_invalid <= 1'b0;
    end
end

wire ms_csr_we;
wire [13:0] ms_csr_num_o;


assign ms_csr_we    = (ms_inst_csrwr | ms_inst_csrwr) & ms_valid & ~ms_ex;
assign ms_csr_num_o = ms_counter_op? 64: ms_inst[23:10];
assign ms_csr_num   = {14{ms_valid}} & ms_csr_num_o & {14{ms_csr_we}};
assign ms_tlbop     = ms_tlb_op & {5{ms_valid}};


endmodule