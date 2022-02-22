module mycpu_top(
    input         aclk,
    input         aresetn,
//axi interface
    output [ 3:0] arid,
    output [31:0] araddr,
    output [ 7:0] arlen,
    output [ 2:0] arsize,
    output [ 1:0] arburst,
    output [ 1:0] arlock,
    output [ 3:0] arcache,
    output [ 2:0] arprot,
    output        arvalid,
    input         arready,
    
    input [ 3:0] rid,
    input [31:0] rdata,
    input [ 1:0] rresp,
    input        rlast,
    input        rvalid,
    output       rready,
    
    output [ 3:0] awid,
    output [31:0] awaddr,
    output [ 7:0] awlen,
    output [ 2:0] awsize,
    output [ 1:0] awburst,
    output [ 1:0] awlock,
    output [ 3:0] awcache,
    output [ 2:0] awprot,
    output        awvalid,
    input         awready,
    
    output [ 3:0] wid,
    output [31:0] wdata,
    output [ 3:0] wstrb,
    output        wlast,
    output        wvalid,
    input         wready,
    
    input [ 3:0] bid,
    input [ 1:0] bresp,
    input        bvalid,
    output       bready,
/* inst sram interface*/
//    output        inst_sram_en,
//    output [ 3:0] inst_sram_wen,
/*  output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,*/
    // data sram interface
//    output        data_sram_en,
//    output [ 3:0] data_sram_wen,
/*  output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,*/
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge aclk) reset <= ~aresetn; 

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;

wire [`ES_TO_ID_BYQ_WD -1:0] es_to_id_byp_block;
wire [`MS_TO_ID_BYQ_WD -1:0] ms_to_id_byp_block;
wire [`WS_TO_ID_BYQ_WD -1:0] wb_to_id_byp_block;
//ERTN 
wire [31 :0] csr_epc;
wire [31 :0] csr_eentry;
wire [31 :0] csr_crmd;
//Int
wire  has_int;
//wire [0                   :0] ws_has_int;
//wire [0                   :0] ms_has_int;
wire  ws_ertn;
wire  ms_ertn;
wire  ws_ex;
wire  ms_ex;
//wire  [0                  :0] es_inst_csrrd;
//wire  [0                  :0] es_inst_csrwr;
//wire  [0                  :0] es_inst_csrxchg; 
//wire  [0                  :0] ms_inst_csrrd;
//wire  [0                  :0] ms_inst_csrwr;
//wire  [0                  :0] ms_inst_csrxchg; 
//wire  [0                  :0] ws_inst_csrrd;
//wire  [0                  :0] ws_inst_csrwr;
//wire  [0                  :0] ws_inst_csrxchg; 
//wire  [0                  :0] es_inst_rdcntid;
//wire  [0                  :0] ms_inst_rdcntid;
//wire  [0                  :0] ws_inst_rdcntid;
wire  [3 :0] es_to_ds_csr_inst;
wire  [3 :0] ms_to_ds_csr_inst;
wire  [3 :0] ws_to_ds_csr_inst;
//transfer_bridge to cpu wire
wire         inst_sram_req;
wire         inst_sram_wr;
wire  [ 1:0] inst_sram_size;
wire  [31:0] inst_sram_addr;
wire  [ 3:0] inst_sram_wstrb;
wire  [31:0] inst_sram_wdata;
wire         inst_sram_addr_ok;
wire         inst_sram_data_ok;
wire  [31:0] inst_sram_rdata;
wire         data_sram_req;
wire         data_sram_wr;
wire  [ 1:0] data_sram_size;
wire  [31:0] data_sram_addr;
wire  [ 3:0] data_sram_wstrb;
wire  [31:0] data_sram_wdata;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire [31:0] data_sram_rdata;


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

wire [`TLB_TO_WS_BUS_WD -1:0] tlb_to_ws_bus;
wire [`WS_TO_TLB_BUS_WD -1:0] ws_to_tlb_bus;
wire [`WS_TO_ES_CSR_BUS -1:0] ws_to_es_csr_bus;
wire [`TLB_TO_ES_BUS - 1: 0] tlb_to_es_bus;
wire [13:0] ws_csr_num_to_es;
wire [ 4:0] ws_tlbop_to_es;


wire [13:0] ms_csr_num;
wire [ 4:0] ms_tlbop;
wire [13:0] es_csr_num;
wire [13:0] ds_csr_num;
//Axi to Sram Transfer Bridge
transfer_bridge transfer_bridge(
    .aclk           (aclk      ),
    .aresetn        (aresetn),

    .arid           (arid      ),
    .araddr         (araddr    ),
    .arlen          (arlen     ),
    .arsize         (arsize    ),
    .arburst        (arburst   ),
    .arlock         (arlock    ),
    .arcache        (arcache   ),
    .arprot         (arprot    ),
    .arvalid        (arvalid   ),
    .arready        (arready   ),
    
    .rid            (rid       ),
    .rdata          (rdata     ),
    .rresp          (rresp     ),
    .rlast          (rlast     ),
    .rvalid         (rvalid    ),
    .rready         (rready    ),
    
    .awid           (awid      ),
    .awaddr         (awaddr    ),
    .awlen          (awlen     ),
    .awsize         (awsize    ),
    .awburst        (awburst   ),
    .awlock         (awlock    ),
    .awcache        (awcache   ),
    .awprot         (awprot    ),
    .awvalid        (awvalid   ),
    .awready        (awready   ),
    
    .wid            (wid       ),
    .wdata          (wdata     ),
    .wstrb          (wstrb     ),
    .wlast          (wlast     ),
    .wvalid         (wvalid    ),
    .wready         (wready    ),
    
    .bid            (bid       ),
    .bresp          (bresp     ),
    .bvalid         (bvalid    ),
    .bready         (bready    ),
    
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wr      (inst_sram_wr     ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_rdata   (inst_sram_rdata  ),
    .data_sram_req     (data_sram_req    ),
    .data_sram_wr      (data_sram_wr     ),
    .data_sram_size    (data_sram_size   ),
    .data_sram_addr    (data_sram_addr   ),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_wdata   (data_sram_wdata  ),
    .data_sram_addr_ok (data_sram_addr_ok),
    .data_sram_data_ok (data_sram_data_ok),
    .data_sram_rdata   (data_sram_rdata  )
);

// IF stage
if_stage if_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //ertn
    .csr_epc        (csr_epc        ),
    .csr_eentry     (csr_eentry     ),
    .ws_ertn        (ws_ertn      ),
    .ws_ex          (ws_ex          ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_req   (inst_sram_req   ),
    .inst_sram_wr    (inst_sram_wr  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_size(inst_sram_size),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    //from ws
    .csr_crmd(csr_crmd),
    .ws_csr_num_to_fs(ws_csr_num_to_es),
    .ws_tlbop(ws_tlbop_todsdedsxfddfdf_es)
    //from ms
    .ms_csr_num(ms_csr_num),
    .ms_tlbop(ms_tlbop),
    //from es
    .es_csr_num(es_csr_num),
    //from ds
    .ds_csr_num(ds_csr_num)
);
// ID stage
id_stage id_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //add block code
    .es_to_id_byp_block (es_to_id_byp_block),
    .ms_to_id_byp_block (ms_to_id_byp_block),
    .wb_to_id_byp_block (wb_to_id_byp_block),
    //Int
    .has_int            (has_int),
    //.es_inst_csrrd      (es_inst_csrrd),
    //.es_inst_csrwr      (es_inst_csrwr),
    //.es_inst_csrxchg    (es_inst_csrxchg),
    //.ms_inst_csrrd      (ms_inst_csrrd),
    //.ms_inst_csrwr      (ms_inst_csrwr),
    //.ms_inst_csrxchg    (ms_inst_csrxchg),
    //.ws_inst_csrrd      (ws_inst_csrrd),
    //.ws_inst_csrwr      (ws_inst_csrwr),
    //.ws_inst_csrxchg    (ws_inst_csrxchg),
    .ws_ertn            (ws_ertn),
    .ws_ex              (ws_ex),
    //.es_inst_rdcntid    (es_inst_rdcntid),
    //.ms_inst_rdcntid    (ms_inst_rdcntid),
    //.ws_inst_rdcntid    (ws_inst_rdcntid)
    .es_to_ds_csr_inst (es_to_ds_csr_inst),
    .ms_to_ds_csr_inst (ms_to_ds_csr_inst),
    .ws_to_ds_csr_inst (ws_to_ds_csr_inst),
    .ds_csr_num(ds_csr_num)
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //from ws
    .ws_csr_num_to_es(ws_csr_num_to_es),
    .ws_tlbop_to_es(ws_tlbop_to_es),
    .ws_to_es_csr_bus(ws_to_es_csr_bus),
    .csr_crmd(csr_crmd)
    //from ms
    .ms_csr_num(ms_csr_num),
    .ms_tlbop(ms_tlbop),
    //to tlb
    .invtlb_op(invtlb_op),
    .invtlb_valid(invtlb_valid),
    .s1_vppn(s1_vppn),
    .s1_asid(s1_asid),
    //from tlb
    .tlb_to_es_bus(tlb_to_es_bus),
    //Int
    .ms_ex          (ms_ex     ),
    .ws_ertn        (ws_ertn        ),
    .ms_ertn        (ms_ertn        ),
    .ws_ex          (ws_ex),
    // data sram interface
    .data_sram_req   (data_sram_req   ),
    .data_sram_wr  (data_sram_wr  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_size(data_sram_size),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok),
    //add code
    .es_to_id_byp_block (es_to_id_byp_block),
    //Int
    //.es_inst_csrrd      (es_inst_csrrd),
    //.es_inst_csrwr      (es_inst_csrwr),
    //.es_inst_csrxchg    (es_inst_csrxchg),
    //.es_inst_rdcntid    (es_inst_rdcntid)
    .es_to_ds_csr_inst(es_to_ds_csr_inst),
    .es_csr_num(es_csr_num)
);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),
    //add code
    .ms_to_id_byp_block (ms_to_id_byp_block),
    //Int
    .ms_ex           (ms_ex),
    .ms_ertn         (ms_ertn),
    .ws_ex           (ws_ex),
    .ws_ertn         (ws_ertn),
    //.ms_inst_csrrd      (ms_inst_csrrd),
    //.ms_inst_csrwr      (ms_inst_csrwr),
    //.ms_inst_csrxchg    (ms_inst_csrxchg),
    //.ms_inst_rdcntid    (ms_inst_rdcntid),
    .ms_to_ds_csr_inst(ms_to_ds_csr_inst),
    .ms_csr_num(ms_csr_num),
    .ms_tlbop(ms_tlbop)
);


// WB stage
wb_stage wb_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //tlb
    .tlb_to_ws_bus(tlb_to_ws_bus),
    .ws_to_tlb_bus(ws_to_tlb_bus),
    //to es
    .ws_to_es_csr_bus(ws_to_es_csr_bus),
    .ws_csr_num_to_es(ws_csr_num_to_es),
    .ws_tlbop_to_es(ws_tlbop_to_es),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //add code
    .wb_to_id_byp_block (wb_to_id_byp_block),
    //Ertn
    .csr_epc(csr_epc),
    .csr_eentry(csr_eentry),
    .csr_crmd(csr_crmd),
    //.inst_ertn(inst_ertn),
    //Int
    .has_int(has_int),
    //.ws_has_int(ws_has_int),
    .ws_ertn(ws_ertn),
    .ws_ex_o(ws_ex),
    //.ws_inst_csrrd      (ws_inst_csrrd),
    //.ws_inst_csrwr      (ws_inst_csrwr),
    //.ws_inst_csrxchg    (ws_inst_csrxchg),
    //.ws_inst_rdcntid    (ws_inst_rdcntid)
    .ws_to_ds_csr_inst(ws_to_ds_csr_inst)
);

assign  {s0_vppn,
        s0_asid,
        s0_va_bit12,
        //s1_vppn,
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
        } = ws_to_tlb_bus;



assign tlb_to_ws_bus = {s0_found,
	                    s0_index,
	                    s0_ppn,
	                    s0_ps,
	                    s0_plv,
	                    s0_mat,
	                    s0_d,
	                    s0_v,
	                    //s1_found,
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
};

assign tlb_to_es_bus = {s1_found, s1_index, s1_ppn, s1_ps, s1_plv, s1_mat, s1_d, s1_v};

tlb tlb_u(
   .clk(aclk),
   .reset(reset),
	// search port 0 (for fetch)
	.s0_vppn(s0_vppn),
	.s0_asid(s0_asid),
	.s0_va_bit12(s0_va_bit12),
	.s0_found(s0_found),
	.s0_index(s0_index),
	.s0_ppn(s0_ppn),
	.s0_ps(s0_ps),
	.s0_plv(s0_plv),
	.s0_mat(s0_mat),
	.s0_d(s0_d),
	.s0_v(s0_v),
	// search port 1 (for load/store)
	.s1_vppn(s1_vppn),
	.s1_asid(s1_asid),
	.s1_va_bit12(s1_va_bit12),
	.s1_found(s1_found),
	.s1_index(s1_index),
	.s1_ppn(s1_ppn),
	.s1_ps(s1_ps),
	.s1_plv(s1_plv),
	.s1_mat(s1_mat),
	.s1_d(s1_d),
	.s1_v(s1_v),
	// invtlb opcode
	.invtlb_op(invtlb_op),
    .invtlb_valid(invtlb_valid),
	// write port
	.we(we), //w(rite) e(nable)
	.w_index(w_index),
	.w_e(w_e),
	.w_vppn(w_vppn),
	.w_ps(w_ps),
	.w_asid(w_asid),
	.w_g(w_g),
	.w_ppn0(w_ppn0),
	.w_plv0(w_plv0),
	.w_mat0(w_mat0),
	.w_d0(w_d0),
	.w_v0(w_v0),
	.w_ppn1(w_ppn1),
	.w_plv1(w_plv1),
	.w_mat1(w_mat1),
	.w_d1(w_d1),
	.w_v1(w_v1),
	// read port
	.r_index(r_index),
	.r_e(r_e),
	.r_vppn(r_vppn),
	.r_ps(r_ps),
	.r_asid(r_asid),
	.r_g(r_g),
	.r_ppn0(r_ppn0),
	.r_plv0(r_plv0),
	.r_mat0(r_mat0),
	.r_d0(r_d0),
	.r_v0(r_v0),
	.r_ppn1(r_ppn1),
	.r_plv1(r_plv1),
	.r_mat1(r_mat1),
	.r_d1(r_d1),
	.r_v1(r_v1)
);

endmodule