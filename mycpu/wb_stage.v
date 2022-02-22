`include "mycpu.h"

module wb_stage(
    input                            clk           ,
    input                            reset         ,
    //allowin
    output                           ws_allowin    ,
    //from ms
    input                            ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1 :0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1 :0]  ws_to_rf_bus  ,
    //ws--tlb
    input  [`TLB_TO_WS_BUS_WD -1:0]  tlb_to_ws_bus ,
    output [`WS_TO_TLB_BUS_WD -1:0]  ws_to_tlb_bus ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    //add block and bypass code
    output [`WS_TO_ID_BYQ_WD -1 :0] wb_to_id_byp_block,
    //to es
    output [`WS_TO_ES_CSR_BUS-1 :0] ws_to_es_csr_bus,
    output [13:0] ws_csr_num_to_es,
    output [ 4:0] ws_tlbop_to_es,
    //Ertn
    output [31:0] csr_epc ,
    output [31:0] csr_eentry,
    output [31:0] csr_crmd,
    //output [0: 0] inst_ertn,
    //Int
    /*We should tell this 'ws_has_int' from 'has_int'. 'Ws_has_int' means
    this instruction has tag 'int', 'has_int' means the instruction which
    is in the ID pipeline has int*/   
    output [0: 0] has_int,
    //output [0: 0] ws_has_int,
    output [0: 0] ws_ertn,
    output [0: 0] ws_ex_o,
    //output [0: 0] ws_inst_csrrd ,
    //output [0: 0] ws_inst_csrwr,
    //output [0: 0] ws_inst_csrxchg,
    //output [0: 0] ws_inst_rdcntid
    output  [3: 0] ws_to_ds_csr_inst
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire [31:0] ws_pc_0;
wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
//Lab 8 add code and signals!!!
wire [31:0] ws_rj_value;
wire [31:0] ws_rkd_value;
wire [31:0] ws_inst;
wire        ertn_reflush;
wire        wb_counter_op;

wire [ 4:0] wb_to_id_dest;
wire        wb_wen;
wire [31:0] wb_to_id_res;

wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_syscall;
wire        inst_ertn;
wire        ws_inst_csrrd;
wire        ws_inst_csrwr;
wire        ws_inst_csrxchg;
wire        ws_inst_rdcntid;
wire [13:0] csr_num;
wire        csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire [31:0] csr_rvalue;
wire [ 7:0] hw_int_in;
wire [ 0:0] ipi_int_in;
//Output Control Registers
wire [31:0] csr_era   ;
wire [31:0] csr_estat ;
wire [31:0] coreid_in ;
wire [ 5:0] wb_ecode;
wire [ 8:0] wb_esubcode;
wire [31:0] csr_crmd;
wire [31:0] csr_dmw0;
wire [31:0] csr_dmw1;


wire  [              18:0] s0_vppn;
wire  [               9:0] s0_asid;
wire                       s0_va_bit12;
wire                       s0_found;
wire [               3:0]  s0_index;
wire [              19:0]  s0_ppn;
wire [               5:0]  s0_ps;
wire [               1:0]  s0_plv;
wire [               1:0]  s0_mat;
wire                       s0_d;
wire                       s0_v;
	// search port 1 (for load/store)
wire  [              18:0] s1_vppn;
wire  [               9:0] s1_asid;
wire                       s1_va_bit12;
wire                       s1_found;
wire [                3:0] s1_index;
wire [               19:0] s1_ppn;
wire [                5:0] s1_ps;
wire [               1:0]  s1_plv;
wire [               1:0]  s1_mat;
wire                       s1_d;
wire                       s1_v;
	// invtlb opcode
wire  [               4:0] invtlb_op;
wire                       invtlb_valid;
	// write port
wire                       we; //w(rite) e(nable)
wire  [3               :0] w_index;
wire                       w_e;
wire  [              18:0] w_vppn;
wire  [               5:0] w_ps;
wire  [               9:0] w_asid;
wire                       w_g;
wire  [              19:0] w_ppn0;
wire  [               1:0] w_plv0;
wire  [               1:0] w_mat0;
wire                       w_d0;
wire                       w_v0;
wire  [              19:0] w_ppn1;
wire  [               1:0] w_plv1;
wire  [               1:0] w_mat1;
wire                       w_d1;
wire                       w_v1;
	// read port
wire  [3              :0] r_index;
wire                      r_e;
wire [              18:0] r_vppn;
wire [               5:0] r_ps;
wire [               9:0] r_asid;
wire                      r_g;
wire [              19:0] r_ppn0;
wire [               1:0] r_plv0;
wire [               1:0] r_mat0;
wire                      r_d0;
wire                      r_v0;
wire [              19:0] r_ppn1;
wire [               1:0] r_plv1;
wire [               1:0] r_mat1;
wire                      r_d1;
wire                      r_v1;

wire csr_asid_we;
wire csr_tlbidx_index_we;
wire csr_tlbidx_nul_we;
wire csr_tlbehi_vppn_we;
wire csr_tlbelo0_we;
wire csr_tlbelo1_we;
wire csr_tlbidx_ps_we;

wire [9:0] csr_asid_asid_w;
wire [7:0] csr_asid_asidbits_w;
wire [3:0] csr_tlbidx_index_w;
wire csr_tlbidx_nul_w;
wire [18:0] csr_tlbehi_vppn_w;
wire [23:0] csr_tlbelo0_ppn_w;
wire [6:0]  csr_tlbelo0_con_w;
wire [23:0] csr_tlbelo1_ppn_w;
wire [6:0]  csr_tlbelo1_con_w;
wire [5:0]  csr_tlbidx_ps_w;
wire [4:0] ws_tlb_op;
wire [3:0] rand_index;
wire [4:0] ws_invtlb_op;

wire [3:0] csr_tlbidx_index;
wire [5:0] csr_tlbidx_ps;
wire       csr_tlbidx_nul;
wire [18:0] csr_tlbehi_vppn;
wire      csr_tlbelo0_g;
wire [23:0] csr_tlbelo0_ppn;
wire      csr_tlbelo0_v;
wire [1:0] csr_tlbelo0_plv;
wire [1:0] csr_tlbelo0_mat;
wire       csr_tlbelo0_d;
wire       csr_tlbelo1_g;
wire [23:0] csr_tlbelo1_ppn;
wire       csr_tlbelo1_v;
wire [1:0] csr_tlbelo1_plv;
wire [1:0] csr_tlbelo1_mat;
wire       csr_tlbelo1_d;
wire [9:0] csr_asid_asid;
wire [7:0] csr_asid_asidbits;
wire [9:0] rj_asid;
wire [18:0] rk_va;
wire [36:0] tlb_to_es_bus;
wire [ 2:0] fs_tlb_ex;
wire [ 4:0] es_tlb_ex;

//Need assign
wire [31:0] error_vppn;


assign {es_tlb_ex      ,  //243:239
        fs_tlb_ex      ,  //238:236 
        tlb_to_es_bus  ,  //235:199
        ws_invtlb_op   ,  //194:198
        ws_tlb_op      ,  //193:189
        wb_counter_op  ,  //188:188
        wb_esubcode    ,  //187:179
        wb_ecode       ,  //178:173
        inst_syscall   ,  //172:172
        ws_has_int     ,  //171:171
        ws_ex          ,  //170:170
        inst_ertn      ,  //169:169
        ws_inst        ,  //168:137
        inst_csrxchg   ,  //136:136
        inst_csrwr     ,  //135:135
        inst_csrrd     ,  //134:134
        ws_rkd_value   ,  //133:102
        ws_rj_value    ,  //101:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;
assign {s1_found, s1_index, s1_ppn, s1_ps, s1_plv, s1_mat, s1_d, s1_v} = tlb_to_es_bus;
assign ws_inst_csrrd = inst_csrrd & ws_valid;
assign ws_inst_csrwr = inst_csrwr & ws_valid;
assign ws_inst_csrxchg = inst_csrxchg & ws_valid;
assign ws_to_ds_csr_inst = {ws_inst_csrrd,
                            ws_inst_csrwr,
                            ws_inst_csrxchg,
                            ws_inst_rdcntid
                            };

assign ws_ertn = inst_ertn & ws_valid;
assign ws_ex_o = ws_ex & ws_valid;

assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };
                      
assign wb_to_id_byp_block = {wb_wen,
                             wb_to_id_dest,
                             rf_wdata
                             };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid | ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_ertn | ws_ex_o) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid & ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we & ws_valid;
assign rf_waddr = ws_dest;
//If csrrX, we just need to write the old value into the registers
assign rf_wdata = (ws_inst_csrrd | ws_inst_csrwr | ws_inst_csrxchg | wb_counter_op)? csr_rvalue:
                                                                            ws_final_result;
// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;
//add block and bypass code
assign wb_to_id_dest = ws_dest;
assign wb_wen        = ws_gr_we && ws_valid;
assign wb_to_id_res  = rf_wdata;
//Lab 8 add code
assign csr_we    = (ws_inst_csrxchg | ws_inst_csrwr /*| ws_tlb_op[4]*/) & ws_valid & ~ws_ex;
assign csr_num   = wb_counter_op ? 64 : ws_inst[23:10];//lab9 need to change
assign csr_wmask = (ws_inst_csrwr)? 32'hffffffff : ws_rj_value;       //If the inst is csr_wmask, we set the mask all bits 1
assign csr_wvalue= ws_rkd_value;
assign hw_int_in = 8'b0;   //Initialize all 0
assign ipi_int_in= 1'b0;
assign coreid_in = 32'b0;
//Lab 9 add
assign ws_pc_0 = {ws_pc[31:2], 2'b0};
assign ertn_reflush = inst_ertn & ws_valid;
csrr csrr(
    .clk(clk),
    .reset(reset),
    .wb_ex(ws_ex_o),
    .hw_int_in(hw_int_in),
    .ipi_int_in(ipi_int_in),
    .ws_pc_e(ws_pc),
    .ws_pc(ws_pc_0),//lab9 changed
    .wb_vaddr(ws_final_result),
    .ertn_reflush(ertn_reflush),
    .csr_num(csr_num),
    .csr_we(csr_we),
    .csr_wmask(csr_wmask),
    .csr_wvalue(csr_wvalue),
    .wb_ecode(wb_ecode),
    .wb_esubcode(wb_esubcode),
    .coreid_in(coreid_in),
    .csr_rvalue(csr_rvalue),
    //If this is int
    .has_int(has_int),
    //Control registers
    .csr_era(csr_era),
    .csr_eentry(csr_eentry),
    .csr_crmd(csr_crmd),
    .csr_dmw0(csr_dmw0),
    .csr_dmw1(csr_dmw1),
    //inst_ertb
    .ws_ertn(ws_ertn),
    //tlbidx
    .csr_tlbidx_index(csr_tlbidx_index),
    .csr_tlbidx_index_we(csr_tlbidx_index_we),
    .csr_tlbidx_index_w(csr_tlbidx_index_w),
    .csr_tlbidx_ps(csr_tlbidx_ps),
    .csr_tlbidx_ps_we(csr_tlbidx_ps_we),
    .csr_tlbidx_ps_w(csr_tlbidx_ps_w),
    .csr_tlbidx_nul(csr_tlbidx_nul),
    .csr_tlbidx_nul_we(csr_tlbidx_nul_we),
    .csr_tlbidx_nul_w(csr_tlbidx_nul_w),
    //tlbehi
    .csr_tlbehi_vppn(csr_tlbehi_vppn),
    .csr_tlbehi_vppn_we(csr_tlbehi_vppn_we),
    .csr_tlbehi_vppn_w(csr_tlbehi_vppn_w),
    //tlblo0
    .csr_tlbelo0_we(csr_tlbelo0_we),
    .csr_tlbelo0_ppn_w(csr_tlbelo0_ppn_w),
    .csr_tlbelo0_con_w(csr_tlbelo0_con_w),
    .csr_tlbelo0_d(csr_tlbelo0_d),
    .csr_tlbelo0_ppn(csr_tlbelo0_ppn),
    .csr_tlbelo0_v(csr_tlbelo0_v),
    .csr_tlbelo0_plv(csr_tlbelo0_plv),
    .csr_tlbelo0_mat(csr_tlbelo0_mat),
    .csr_tlbelo0_g(csr_tlbelo0_g),
    //tlb0lo1
    .csr_tlbelo1_we(csr_tlbelo1_we),
    .csr_tlbelo1_ppn_w(csr_tlbelo1_ppn_w),
    .csr_tlbelo1_con_w(csr_tlbelo1_con_w),
    .csr_tlbelo1_d(csr_tlbelo1_d),
    .csr_tlbelo1_ppn(csr_tlbelo1_ppn),
    .csr_tlbelo1_v(csr_tlbelo1_v),
    .csr_tlbelo1_plv(csr_tlbelo1_plv),
    .csr_tlbelo1_mat(csr_tlbelo1_mat),
    .csr_tlbelo1_g(csr_tlbelo1_g),
    //asid
    .csr_asid_we(csr_asid_we),
    .csr_asid_asid_w(csr_asid_asid_w),
    .csr_asid_asidbits_w(csr_asid_asidbits_w),
    .csr_asid_asid(csr_asid_asid),
    .csr_asid_asidbits(csr_asid_asidbits),
    //ex
    .fs_tlb_ex(fs_tlb_ex),
    .es_tlb_ex(ex_tlb_ex),
    .error_vppn(error_vppn)
);
//to es csr
assign ws_to_es_csr_bus = {csr_tlbehi_vppn, csr_asid_asid};  

//EPC
assign csr_epc = {32{ws_valid}} & csr_era;
assign ws_inst_rdcntid = wb_counter_op & ws_valid;
//tlb inst
//assign ws_to_es_tlb_s1_bus = {s1_vppn, s1_asid, s1_va_bit12};
assign ws_to_tlb_bus = {//s1_vppn,
                        //s1_asid,
                        //s1_va_bit12,
                        //invtlb_op,
                        //invtlb_valid,
                        we,
                        w_index,
                        w_e,
	                    w_vppn,
	                    w_ps,
	                    w_asid,
	                    w_g,
	                    w_ppn0,
	                    w_plv0,
	                    w_mat0,
	                    w_d0,
	                    w_v0,
	                    w_ppn1,
	                    w_plv1,
	                    w_mat1,
	                    w_d1,
	                    w_v1,
	                    r_index
                        };
//assign {s1_found, s1_index, s1_vppn, s1_ps, s1_plv, s1_mat, s1_d, s1_v} = es_to_ws_tlb_s1_bus;
assign {//s1_found,
	    //s1_index,
	    //s1_ppn,
	    //s1_ps,
	    //s1_plv,
	    //s1_mat,
	    //s1_d,
	    //s1_v,
	    r_e,
	    r_vppn,
	    r_ps,
	    r_asid,
	    r_g,
	    r_ppn0,
	    r_plv0,
	    r_mat0,
	    r_d0,
	    r_v0,
	    r_ppn1,
	    r_plv1,
	    r_mat1,
	    r_d1,
	    r_v1
	    } = tlb_to_ws_bus;
//assign rk_va = ws_rkd_value [31:13];
//assign rj_asid = ws_rj_value [9:0];
//assign invtlb_op = ws_invtlb_op;
//assign invtlb_valid = ws_tlb_op[0];
/*assign s1_vppn = ({19{ws_tlb_op[4]}} & csr_tlbehi_vppn)|
                 ({19{(invtlb_op==5'b00100)|(invtlb_op==5'b00101)|(invtlb_op==5'b00110)}}) & rk_va;
assign s1_asid = {10{ws_tlb_op[4]}} & csr_asid_asid|
                 ({10{(invtlb_op==5'b00100)|(invtlb_op==5'b00101)|(invtlb_op==5'b00110)}}) & rj_asid;*/
//assign s1_va_bit12 = ws_tlb_op[4] & csr_asid_asidbits;
//assign r_index = {4{ws_tlb_op[4]}} ? csr_tlbidx_index: csr_tlbidx_index;
assign we = ws_tlb_op[2] | ws_tlb_op[1];
assign w_index =  ws_tlb_op[2] ? csr_tlbidx_index:
                  ws_tlb_op[1] ? rand_index: rand_index;
assign w_vppn = csr_tlbehi_vppn;
assign w_e = (csr_estat == 6'h3f)? ~csr_tlbidx_nul: 1'b1;
assign w_ps = csr_tlbidx_ps;
assign w_asid = csr_asid_asid;
assign w_g = csr_tlbelo0_g & csr_tlbelo1_g;
assign w_ppn0 = csr_tlbelo0_ppn;
assign w_plv0 = csr_tlbelo0_plv;
assign w_mat0 = csr_tlbelo0_mat;
assign w_d0 = csr_tlbelo0_d;
assign w_v0 = csr_tlbelo0_v;
assign w_ppn1 = csr_tlbelo1_ppn;
assign w_plv1 = csr_tlbelo1_plv;
assign w_mat1 = csr_tlbelo1_mat;
assign w_d1 = csr_tlbelo1_d;
assign w_v1 = csr_tlbelo1_v; 

//Move tlbsrch to exe
assign csr_asid_we = ws_tlb_op[3] & r_e;
assign csr_tlbidx_index_we = ws_tlb_op[4] & (s1_found);
assign csr_tlbidx_nul_we = ws_tlb_op[4] | ws_tlb_op[3];
assign csr_tlbehi_vppn_we = ws_tlb_op[3] & r_e;
assign csr_tlbelo0_we = ws_tlb_op[3] & r_e;
assign csr_tlbelo1_we = ws_tlb_op[3] & r_e;
assign csr_tlbidx_ps_we = ws_tlb_op[3] & r_e;
//assign csr_tlbrentry_we = 1'b0;

assign csr_asid_asid_w = r_asid;
assign csr_asid_asidbits_w = 8'h0a;
assign csr_tlbidx_index_w = s1_index;
assign csr_tlbidx_nul_w =   ws_tlb_op[4] ? ~(s1_found):~r_e;
assign csr_tlbehi_vppn_w =  r_vppn;
assign csr_tlbelo0_ppn_w = {4'b0, r_ppn0};
assign csr_tlbelo0_con_w = {r_g, r_mat0, r_plv0, r_d0, r_v0};
assign csr_tlbelo1_ppn_w = {4'b0, r_ppn1};
assign csr_tlbelo1_con_w = {r_g, r_mat1, r_plv1, r_d1, r_v1};
assign csr_tlbidx_ps_w = r_ps;

//wire [6:0] tlb_rd_0 = {lo0_ppn0,1'b0,r_mat0,r_d0,r_v0,r_g};
//wire [6:0] tlb_rd_1 = {lo1_ppn1,r_plv1,r_mat1,r_d1,r_v1,r_g};


reg [3:0] rand;
always @(posedge clk) begin
    //rand <= {$random} % 16;
    if(reset)begin
        rand<=4'b0;
    end
    else if (rand!=4'b1111) begin
        rand<=rand+4'b0001;
    end
    else if (rand==4'b1111) begin
        rand<=4'b0;
    end
end
assign rand_index = rand;

assign ws_csr_num_to_es = {14{ws_valid}} & csr_num & {14{csr_we}};
assign ws_tlbop_to_es =   {5{ws_valid}} & ws_tlb_op;

endmodule