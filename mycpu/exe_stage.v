`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to tlb
    output [4 :0] invtlb_op,
    output        invtlb_valid,
    output        s1_vppn,
    output        s1_asid,
    //from tlb
    input [`TLB_TO_ES_BUS -1: 0] tlb_to_es_bus, 
    //from ws
    input  [`WS_TO_ES_CSR_BUS -1:0] ws_to_es_csr_bus,
    input  [13:0] ws_csr_num_to_es,
    input  [ 4:0] ws_tlbop_to_es,
    input  [31:0] csr_crmd, 
    //from ms
    input  [13:0] ms_csr_num,
    input  [ 4:0] ms_tlbop,
    //Int
    input [0:0] ws_ex,
    input [0:0] ms_ex,
    input [0:0] ws_ertn,
    input [0:0] ms_ertn,
    // data sram interface
    output        data_sram_req  ,
    //output        data_sram_en   ,
    output        data_sram_wr   ,
    output [ 1:0] data_sram_size ,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    //add block and bypass code
    output [`ES_TO_ID_BYQ_WD -1:0] es_to_id_byp_block,
    //Int
    //output [0: 0] es_inst_csrrd,
    //output [0: 0] es_inst_csrwr,
    //output [0: 0] es_inst_csrxchg,
    //output [0: 0] es_inst_rdcntid
    output [3                  :0] es_to_ds_csr_inst,
    output [13                 :0] es_csr_num
); 

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [18:0] es_alu_op     ;
wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_gr_we_r    ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;
wire        es_res_from_mem;
wire        es_res_from_mem_r;
wire [ 4:0] es_load_op;
wire [ 2:0] es_store_op;
wire        no_store;
wire        inst_is_sdiv;
wire        inst_is_udiv;
wire [31:0] divisor;
wire [31:0] dividend;
wire [63:0] unsigned_div_res;
wire [63:0] signed_div_res;
wire        signed_dividend_tvalid;
wire        signed_divisor_tvalid;
wire        signed_dividend_tready;
wire        signed_divisor_tready;
wire        signed_dout_tvalid;
reg         signed_dividend_sent;
reg         signed_divisor_sent;
wire        unsigned_dividend_tvalid;
wire        unsigned_divisor_tvalid;
wire        unsigned_dividend_tready;
wire        unsigned_divisor_tready;
wire        unsigned_dout_tvalid;
reg         unsigned_dividend_sent;
reg         unsigned_divisor_sent;
wire [31:0] div_result;
wire [31:0] es_final_res;

wire [ 4:0] es_to_id_dest;
wire        es_wen;
wire [31:0] es_to_id_res;
wire        not_forward;
//Lab 8 add inst judge signal
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;
wire        es_inst_csrrd;
wire        es_inst_csrwr;
wire        es_inst_csrxchg;
wire        es_inst_rdcntid;
wire [31:0] es_inst; 
wire        es_ex;
wire        es_ex_r;
wire [ 5:0] es_ecode;
wire [ 5:0] es_ecode_r;
wire [ 8:0] es_esubcode;
wire        has_int;
wire        has_ale;
wire        has_ale_o;
wire [ 2:0] es_counter_op;

wire [ 4:0] es_tlb_op;
wire [ 4:0] es_invtlb_op;

reg  [63:0] counter;
wire [31:0] counter_res;

reg         es_req;
wire [ 3:0] data_sram_wen;
wire        data_sram_en;
wire        data_sram_hand_succ;

wire [18:0] s1_vppn;
wire [ 9:0] s1_index;
wire        s1_va_bit12;

wire        tlb_block;
wire  [2:0] fs_tlb_ex;

assign {fs_tlb_ex     ,   //234:232
        es_invtlb_op   ,  //231:227
        es_tlb_op      ,  //226:222
        es_counter_op  ,  //221:219
        es_esubcode    ,  //218:210
        es_ecode       ,  //209:204
        inst_syscall   ,  //203:203
        has_int        ,  //202:202
        es_ex          ,  //201:201
        inst_ertn      ,  //200:200
        es_inst        ,  //199:168
        inst_csrrd     ,  //167:167
        inst_csrwr     ,  //166:166
        inst_csrxchg,     //165:165
        es_alu_op      ,  //164:146
        es_res_from_mem,  //145:145
        es_store_op    ,  //144:142
        es_load_op     ,  //141:137
        es_src1_is_pc  ,  //136:136
        es_src2_is_imm ,  //135:135
        es_gr_we       ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;
//assign es_res_from_mem = es_load_op;
/*In lab 8, we need to STORE rj_value  and   rkd_value
  in order to rightly do operations on csrrX registers
  We ALSO need to store inst_csrrX signals in order to
  judge if this instruction is CSRRX operation.
*/
assign es_to_ms_bus = {es_tlb_ex      ,  //253:249
                       fs_tlb_ex      ,  //248:246
                       tlb_to_es_bus  ,  //245:209
                       es_invtlb_op   ,  //208:204
                       es_tlb_op      ,  //203:199
                       has_ale_o       , //198:198
                       es_counter_op[0], //197:197
                       es_esubcode    ,  //196:188
                       es_ecode_r     ,  //187:182
                       inst_syscall   ,  //181:181
                       has_int        ,  //180:180
                       es_ex_r        ,  //179:179
                       inst_ertn      ,  //178:178
                       es_inst        ,  //177:146
                       inst_csrxchg   ,  //145:145
                       inst_csrwr     ,  //144:144
                       inst_csrrd     ,  //143:143
                       es_rkd_value   ,  //142:111
                       es_rj_value    ,  //110:79
                       es_load_op     ,  //78:74
                       es_store_op    ,  //73:71
                       es_res_from_mem_r,  //70:70
                       es_gr_we_r     ,  //69:69
                       es_dest        ,  //68:64
                       es_final_res   ,  //63:32
                       es_pc             //31:0
                      };
                      
assign es_to_id_byp_block = {has_ale_o,
                             es_wen,
                             es_to_id_dest,
                             es_final_res,not_forward
                             };
                             
assign es_to_ds_csr_inst = {es_inst_csrrd,
                            es_inst_csrwr,
                            es_inst_csrxchg,
                            es_inst_rdcntid
                            };
//lab 6 change ready_go for div
assign es_allowin     = !es_valid | es_ready_go & ms_allowin;
assign es_to_ms_valid =  es_valid & es_ready_go & ~ws_ertn & ~ws_ex;
always @(posedge clk) begin
    if (reset /*|| ~ws_ertn || ~ws_ex*/) begin     
        es_valid <= 1'b0;
    end
    else if( ws_ertn | ws_ex) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid & es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end
assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
                                      es_rj_value;                           
assign es_alu_src2 = es_src2_is_imm ? es_imm : 
                                      es_rkd_value;
alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ), //3
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );
//module mydiv ip
assign inst_is_sdiv = es_alu_op[15] | es_alu_op[16];
assign inst_is_udiv = es_alu_op[17] | es_alu_op[18];
assign divisor  = es_rkd_value;
assign dividend = es_rj_value;
//Below is to judge when sent is valid
always @(posedge clk) begin
    if(reset) begin
        signed_dividend_sent <= 1'b0;
    end else if(signed_dividend_tvalid & signed_dividend_tready) begin
        signed_dividend_sent <= 1'b1;
    end else if(es_allowin) begin
        signed_dividend_sent <= 1'b0;
    end 
end
always @(posedge clk) begin
    if(reset) begin
        signed_divisor_sent <= 1'b0;
    end else if(signed_dividend_tvalid & signed_dividend_tready) begin
        signed_divisor_sent <= 1'b1;
    end else if(es_allowin) begin
        signed_divisor_sent <= 1'b0;
    end 
end
assign signed_divisor_tvalid  = !signed_divisor_sent  && es_valid && inst_is_sdiv;
assign signed_dividend_tvalid = !signed_dividend_sent && es_valid && inst_is_sdiv; 
mydiv_signed mydiv_signed(
    .aclk(clk),
    .s_axis_divisor_tdata(divisor),
    .s_axis_dividend_tdata(dividend),
    .s_axis_divisor_tready(signed_divisor_tready),
    .s_axis_divisor_tvalid(signed_divisor_tvalid),
    .s_axis_dividend_tready(signed_dividend_tready),
    .s_axis_dividend_tvalid(signed_dividend_tvalid),
    .m_axis_dout_tdata(signed_div_res),
    .m_axis_dout_tvalid(signed_dout_tvalid)
);
//Below is to judge when sent is valid
always @(posedge clk) begin
    if (reset) begin
        unsigned_dividend_sent <= 1'b0;
    end else if (unsigned_dividend_tvalid & unsigned_dividend_tready) begin
        unsigned_dividend_sent <= 1'b1;
    end else if (es_allowin) begin
        unsigned_dividend_sent <= 1'b0;
    end 
end
always @(posedge clk) begin
    if (reset) begin
        unsigned_divisor_sent <= 1'b0;
    end else if (unsigned_dividend_tvalid & unsigned_dividend_tready) begin
        unsigned_divisor_sent <= 1'b1;
    end else if (es_allowin) begin
        unsigned_divisor_sent <= 1'b0;
    end 
end
assign unsigned_divisor_tvalid  = !unsigned_divisor_sent  & es_valid & inst_is_udiv;
assign unsigned_dividend_tvalid = !unsigned_dividend_sent & es_valid & inst_is_udiv; 
mydiv_unsigned mydiv_unsigned(
    .aclk(clk),
    .s_axis_divisor_tdata(divisor),
    .s_axis_dividend_tdata(dividend),
    .s_axis_divisor_tready(unsigned_divisor_tready),
    .s_axis_divisor_tvalid(unsigned_divisor_tvalid),
    .s_axis_dividend_tready(unsigned_dividend_tready),
    .s_axis_dividend_tvalid(unsigned_dividend_tvalid),
    .m_axis_dout_tdata(unsigned_div_res),
    .m_axis_dout_tvalid(unsigned_dout_tvalid)
);
//Select the Div Result
assign div_result = ({32{es_alu_op[15]}} & signed_div_res[63:32])   |
                    ({32{es_alu_op[16]}} & signed_div_res[31:0])   |
                    ({32{es_alu_op[17]}} & unsigned_div_res[63:32]) |
                    ({32{es_alu_op[18]}} & unsigned_div_res[31:0]) ;
//Select the Final Result
assign es_final_res = (inst_is_sdiv | inst_is_udiv)         ? div_result: 
                      (es_counter_op[2] | es_counter_op[1]) ? counter_res:
                                                              es_alu_result;
//es_ready_go need fixing in Lab 15
assign es_ready_go = (inst_is_udiv & ~ws_ertn & ~ws_ex) ? unsigned_dout_tvalid:
                     (inst_is_sdiv & ~ws_ertn & ~ws_ex) ? signed_dout_tvalid: 
                     (data_sram_en & ~ws_ertn & ~ws_ex) ? data_sram_hand_succ:
                     ((tlb_block | plv_blocked) & ~ws_ertn & ~ws_ex) ? 1'b0 :1'b1;

//block and forward add code
assign es_to_id_dest = es_dest;
assign es_wen        = es_valid & es_gr_we_r;
assign es_to_id_res  = es_alu_result;
assign not_forward   = es_res_from_mem & es_valid;
//Int & Exception
assign no_store = ms_ex | ws_ex | ws_ertn | ms_ertn;
assign es_inst_csrrd = inst_csrrd & es_valid;
assign es_inst_csrwr = inst_csrwr & es_valid;
assign es_inst_csrxchg = inst_csrxchg & es_valid;
//lab 9 add ale
assign has_ale = ((es_load_op[0] |es_load_op[2] |es_store_op[0]) & (data_sram_addr[0] != 1'b0))|
                 ((es_load_op[4] |es_store_op[2]) & (data_sram_addr[1:0] != 2'b0));
assign has_ale_o =  has_ale & es_valid;
assign es_ecode_r = has_ale? 6'h09:
                    es_tlb_refill? 6'h3f:
                    es_load_inv?  6'h01:
                    es_store_inv? 6'h02:
                    es_plv_inv?   6'h07:
                    es_tlb_modified? 6'h04: es_ecode;

assign es_ex_r = es_ex | has_ale | (|es_tlb_ex);
assign es_gr_we_r = es_gr_we & ~has_ale_o & es_valid;
assign es_res_from_mem_r = es_res_from_mem & ~has_ale_o;

always @(posedge clk) begin
    if (reset||counter==64'hffffffffffffffff) begin 
        counter <= 64'b0;
    end
    else counter <=counter + 1;
end
assign counter_res = (es_counter_op[2]) ? counter[31:0]:
                                          counter[63:32];
assign es_inst_rdcntid = es_counter_op[0] & es_valid;
//es_req

assign data_sram_en    = ((|es_load_op)| es_mem_we) & es_valid & ~has_ale;
assign data_sram_wen   = (es_store_op[2] & es_valid & ~no_store) ? 4'hf:
                         (es_store_op[1] & es_valid & ~no_store) ? (4'h1 << data_sram_addr[1:0]):
                         (es_store_op[0] & es_valid & ~no_store) ? (4'h3 << {data_sram_addr[1],1'b0}):
                                                                   4'h0;
assign data_sram_addr  = es_alu_result;//div change
assign data_sram_wdata = es_store_op[1] ? {4{es_rkd_value[ 7:0]}} :
                         es_store_op[0] ? {2{es_rkd_value[15:0]}} :
                                             es_rkd_value[31:0];

always @(posedge clk) begin
    if (reset) begin
        es_req <= 1'b0;
    end
    else if (data_sram_addr_ok & data_sram_req) begin
        es_req <= 1'b0;
    end
    else if (data_sram_en & ms_allowin) begin
        es_req <= 1'b1;
    end
end
assign data_sram_req = es_req;
assign data_sram_hand_succ = data_sram_addr_ok & data_sram_req;
assign data_sram_wr  = (data_sram_wen != 4'h0 & es_valid & ~no_store);
assign data_sram_size= (es_store_op[2] & es_valid)? 2'd2:
                       (es_store_op[0] & es_valid)? 2'd1:
                                                    2'd0;
assign data_sram_wstrb = data_sram_wen;

//Move tlbsrch & invtlb here do mmu here

wire [18:0] csr_tlbehi_vppn;
wire [ 9:0] csr_asid_asid;
wire [18:0] rk_va;
wire [ 9:0] rj_asid;

wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_ppn;      
wire [ 5:0] s1_ps;
wire [ 1:0] s1_plv;
wire [ 1:0] s1_mat;
wire        s1_d;
wire        s1_v;

wire        es_tlb_refill;
wire        es_plv_inv;
wire        es_load_inv;
wire        es_store_inv;
wire        es_tlb_modified;
wire  [1:0] crmd_plv;
wire        plv_blokced;
wire  [4:0] es_tlb_ex;

assign {s1_found, s1_index, s1_ppn, s1_ps, s1_plv, s1_mat, s1_d, s1_v} = tlb_to_es_bus;
assign es_tlb_ex = {es_tlb_refill, es_plv_inv, es_load_inv, es_store_inv, es_tlb_modified};

assign {csr_tlbehi_vppn, csr_asid_asid} = ws_to_es_csr_bus; 
assign rk_va   = es_rkd_value[31:13];
assign rj_asid = es_rj_value[9:0];
assign invtlb_op    = es_invtlb_op;
assign inbtlb_valid = es_tlb_op[0];

assign es_tlb_refill = es_valid & ~s1_found;
assign es_load_inv   = es_valid & s1_found & (|es_load_op)  & ~s1_v;
assign es_store_inv  = es_valid & s1_found & (|es_store_op) & ~s1_v;
//plv
assign crmd_plv      = csr_crmd[1:0];
assign es_plv_inv    = es_valid & s1_found & s1_v && ((s0_plv == 0) && (crmd_plv == 1 || crmd_plv == 2 || crmd_plv == 3)); 
assign plv_blocked   = (ws_csr_num_to_es == `CSR_CRMD || ms_csr_num == `CSR_CRMD) & es_valid;
//modified
assign es_tlb_modified = es_valid & (|es_store_op) & s1_found & s1_v & ~es_plv_inv & ~s1_d;

//don't foreget vabit12 
assign s1_vppn = ({19{es_tlb_op[4]}} & csr_tlbehi_vppn)|
                 ({19{(invtlb_op==5'b00100)|(invtlb_op==5'b00101)|(invtlb_op==5'b00110)}}) & rk_va;
assign s1_asid = {10{es_tlb_op[4]}} & csr_asid_asid|
                 ({10{(invtlb_op==5'b00100)|(invtlb_op==5'b00101)|(invtlb_op==5'b00110)}}) & rj_asid;

//We also need to fix es_ready_go
assign tlb_block = (((ws_csr_num_to_es == `CSR_ASID) || (ws_csr_num_to_es == `CSR_TLBEHI) || ws_tlbop_to_es[3]/*tlbrd*/)
                || ((ms_csr_num == `CSR_ASID) || (ms_csr_num == `CSR_TLBEHI) || ms_tlbop[3]/*tlbrd*/)) & es_valid;

//to fs
wire        es_csr_we;
wire [13:0] es_csr_num_o;

assign es_csr_we    = (inst_csrwr | inst_csrxchg) & es_valid & ~es_ex_r;
assign es_csr_num_o = es_counter_op[0]? 64: es_inst[23:10];
assign es_csr_num   = {14{es_valid}} & {14{es_csr_we}} & es_csr_num_o;

endmodule