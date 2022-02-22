`ifndef MYCPU_H
    `define MYCPU_H         

    `define BR_BUS_WD       34
    `define FS_TO_DS_BUS_WD 68
    `define DS_TO_ES_BUS_WD 235
    `define ES_TO_MS_BUS_WD 254
    `define MS_TO_WS_BUS_WD 244
    `define WS_TO_RF_BUS_WD 38
    `define ES_TO_ID_BYQ_WD 40
    `define MS_TO_ID_BYQ_WD 39
    `define WS_TO_ID_BYQ_WD 38
    `define WS_TO_TLB_BUS_WD 170
    `define TLB_TO_WS_BUS_WD 170
    `define WS_TO_ES_CSR_BUS 29
    `define TLB_TO_ES_BUS 37

    //csrr addr
    `define CSR_CRMD    0
    `define CSR_PRMD    1
    `define CSR_EUEN    2
    `define CSR_ECFG    4 
    `define CSR_ESTAT   5
    `define CSR_ERA     6
    `define CSR_BADV    7
    `define CSR_EENTRY  12
    `define CSR_TLBIDX  16
    `define CSR_TLBEHI  17
    `define CSR_TLBELO0 18
    `define CSR_TLBELO1 19 //TLBELO is tlbelo, not tlbel0
    `define CSR_ASID    24
    `define CSR_PGDL    25
    `define CSR_PGDH    26
    `define CSR_PGD     27
    `define CSR_CPUID   32
    `define CSR_SAVE0   48
    `define CSR_SAVE1   49
    `define CSR_SAVE2   50
    `define CSR_SAVE3   51
    `define CSR_TID     64
    `define CSR_TCFG    65
    `define CSR_TVAL    66
    `define CSR_TICLR   68
    `define CSR_LLBCTL  96
    `define CSR_TLBRENTRY 136
    `define CSR_CTAG    152
    `define CSR_DMW0    384
    `define CSR_DMW1    385   
`endif