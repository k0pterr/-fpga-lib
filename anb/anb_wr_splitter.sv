//------------------------------------------------------------------------------
//
//
//
//
//------------------------------------------------------------------------------

`include "common.svh"

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//
//
module automatic anb_wr_splitter_m
#(
    parameter type ADDR_T = logic [ 63:0],
    parameter type LEN_T  = logic [ 13:0],
    parameter type DATA_T = logic [127:0]
)
(
    input  logic   clk,
    input  logic   rst,

    anb_addr_channel_if.s    m_a,
    anb_addr_channel_if.m    s_a,

    anb_data_channel_if.s    m_d,
    anb_data_channel_if.m    s_d
);

//------------------------------------------------------------------------------
//
//    Settings
//
localparam PAGE_SIZE  = 4096;                       // bytes
localparam PCIE_DW_W  = 32;                         // bits
localparam PCIE_BYTES = PCIE_DW_W/8;                // bytes
localparam PAGE_DWC   = PAGE_SIZE/PCIE_BYTES;       // PCIe DWs
localparam ANB_DWC    = $bits(DATA_T)/PCIE_DW_W;    // ANB data bus Double Word Count (PCIe DWs)
localparam ANB_DWC_W  = clog2(ANB_DWC);             //
localparam ANB_BC     = $bits(DATA_T)/8;            // ANB data bus byte count
localparam ANB_BC_W   = clog2(ANB_BC);              //
//localparam ANB_WC     = 2**$bits(LEN_T)/ANB_BC;     // ANB data bus word count
//localparam ANB_WC_W   = clog2(ANB_WC);              //


//------------------------------------------------------------------------------
//
//    Types
//
typedef struct packed
{
    ADDR_T  addr;
    LEN_T   len;
}
adata_t;

typedef struct packed
{
    DATA_T data;
    logic last;
}
ddata_t;

typedef struct
{
    logic   valid;
    logic   ready;
    adata_t data;
}
addr_ch_t;

typedef struct
{
    logic      valid;
    logic      ready;
    ddata_t    data;
}
data_ch_t;

typedef enum logic [1:0]
{
    afsmIDLE,
   // afsmWAIT_DATA,
    afsmSEG
}
address_channel_fsm_t;

typedef enum logic [0:0]
{
    dfsmIDLE,
    dfsmRUN
}
data_channel_fsm_t;


//typedef logic [clog2(PCIE_BYTES)-1:0] dw_byte_addr_t;
typedef logic [ANB_DWC_W-1:0] anb_dwc_t;
typedef logic [ ANB_BC_W-1:0] anb_bc_t;
//typedef logic [ ANB_WC_W-1:0] anb_wc_t;

typedef logic [      clog2(PAGE_SIZE)-1:0] inpage_addr_t;
typedef logic [       bits(PAGE_SIZE)-1:0] seg_len_t;
typedef logic [       clog2(PAGE_DWC)-1:0] seg_len_dw_t;
typedef logic [bits(PAGE_SIZE/ANB_BC)-1:0] seg_len_anbw_t;

typedef struct packed
{
    logic     seg;
    seg_len_t len;
    anb_dwc_t last_word_len;
    anb_dwc_t offset;
}
ds_control_item_t;

typedef struct
{
    ds_control_item_t  tail;
    ds_control_item_t  head;
    logic              push;
    logic              pop;
    logic              full;
    logic              empty;
    logic              wr_rst_busy;
    logic              rd_rst_busy;
}
dsci_queue_t;

//------------------------------------------------------------------------------
//
//    Objects
//
(* mark_debug = "true" *) addr_ch_t             ars_in;                // Address (channel) Register Slice Input
(* mark_debug = "true" *) addr_ch_t             ars_out;               // Address (channel) Register Slice Output
(* mark_debug = "true" *)                                              
(* mark_debug = "true" *) data_ch_t             drs_in;                // Data (channel) Register Slice Input
(* mark_debug = "true" *) data_ch_t             drs_out;               // Data (channel) Register Slice Output
                                                                       
(* mark_debug = "true" *) address_channel_fsm_t afsm = afsmIDLE;       
(* mark_debug = "true" *) address_channel_fsm_t afsm_next;             
(* mark_debug = "true" *) address_channel_fsm_t afsm_next1;            
                                                                       
(* mark_debug = "true" *) data_channel_fsm_t    dfsm = dfsmIDLE;       
(* mark_debug = "true" *) data_channel_fsm_t    dfsm_next;             
                                                                       
(* mark_debug = "true" *) ADDR_T                curr_addr;             
(* mark_debug = "true" *) ADDR_T                curr_addr_reg;         
(* mark_debug = "true" *) LEN_T                 rlen;                  // residual length
(* mark_debug = "true" *) seg_len_t             max_seg_len;
(* mark_debug = "true" *) seg_len_t             curr_len;
//(* mark_debug = "true" *) seg_len_t             curr_len_reg;
(* mark_debug = "true" *) seg_len_anbw_t        curr_len_anbw;         // ANB  word count send to data shifter
(* mark_debug = "true" *) seg_len_anbw_t        curr_len_anbw_cnt = 0;
(* mark_debug = "true" *) anb_dwc_t             ds_offset;             // 'ds' means 'data shifter'
(* mark_debug = "true" *) anb_dwc_t             ds_offset_reg;         // 'ds' means 'data shifter'
(* mark_debug = "true" *) anb_dwc_t             ds_last_word_len;      // 'ds' means 'data shifter'

(* mark_debug = "true" *) logic                 avalid = 0;
(* mark_debug = "true" *) logic                 aready;

dsci_queue_t dsci_queue;

(* mark_debug = "true" *) anb_data_channel_if #( .DATA_T( DATA_T) ) ds_data_in();
anb_data_channel_if #( .DATA_T( DATA_T) ) ds_data_out();

assign afsm_next1 = afsm_next;

//------------------------------------------------------------------------------
//
//    Functions and tasks
//
function ADDR_T get_boundary(input ADDR_T addr, int bound);

    return (addr + bound) & ~(bound - 1);

endfunction

//------------------------------------------------
function seg_len_t seg_len(input inpage_addr_t addr);

    return PAGE_SIZE - addr;

endfunction
//------------------------------------------------
function seg_len_dw_t seg_len_dw(input inpage_addr_t addr);

    return ( PAGE_SIZE - (addr & ~2'b11) )/PCIE_BYTES;

endfunction
//------------------------------------------------
function anb_dwc_t last_word_dw_len(input anb_bc_t len);

    return len/PCIE_BYTES + |len[0 +:clog2(PCIE_BYTES)];

endfunction
//------------------------------------------------
function seg_len_anbw_t seg_len_anbw(input seg_len_t len);

    return len/ANB_BC + |len[ANB_BC_W-1:0];

endfunction

//------------------------------------------------
//function offset_t offset(input dw_byte_addr_t addr,
//                         input LEN_T          len);
//endfunction
//------------------------------------------------
//task gen_seg(input ADDR_T addr, input LEN_T len);
//
//    ADDR_T    curr_addr       = addr;
//    ADDR_T    next_addr;
//    seg_len_t max_seg_len;
//    seg_len_t curr_len;
//    int       ds_offset       = 0;
//    int       next_ds_offset;
//    int       ds_len;
//    int       N               = 0;
//
//    enum logic [1:0] { PATH, SEG } fsm = PATH;
//
//    $display("");
//    $display("[%t], -------- Start processing ---------", $realtime);
//
//    forever begin
//
//        case(fsm)
//        //----------------------------------------
//        PATH: begin
//            max_seg_len    = seg_len(curr_addr);
//            ds_offset      = 0;
//            next_ds_offset = ANB_DWC - seg_len_dw(curr_addr)%ANB_DWC;
//            ds_len         = seg_len_dw(curr_addr);
//            if(max_seg_len) begin
//                if(max_seg_len < len) begin
//                    curr_len = max_seg_len;
//                    fsm      = SEG;
//                end
//                else begin
//                    curr_len = len;
//                end
//            end
//            else begin
//                next_addr = curr_addr + PAGE_SIZE;
//                len      -= PAGE_SIZE;
//            end
//
//            next_addr  = curr_addr + curr_len;
//            len       -= curr_len;
//
//
//        end
//        //----------------------------------------
//        SEG: begin
//            ds_offset   = next_ds_offset;
//
//            if(len > PAGE_SIZE) begin
//                curr_len   = PAGE_SIZE;
//                next_addr  = curr_addr + PAGE_SIZE;
//                len       -= PAGE_SIZE;
//            end
//            else begin
//                curr_len = len;
//                len      = 0;
//            end
//
//
//        end
//        //----------------------------------------
//        endcase
//
//
//        $display("[%t], Seg%1d, curr_addr: %x, max_seg_len: %5d, curr_len: %5d, ds_offset: %1d, ds_len: %4d, next_addr: %x, next_ds_offset: %1d, len: %5d",
//                 $realtime,
//                 N++,
//                 curr_addr,
//                 max_seg_len,
//                 curr_len,
//                 ds_offset,
//                 ds_len,
//                 next_addr,
//                 next_ds_offset,
//                 len);
//
//        curr_addr = next_addr;
//
//        if(!len) begin
//            $display("[%t], -------- End processing ---------\n ", $realtime, );
//            break;
//        end
//    end
//
//endtask

//------------------------------------------------

//initial begin
//
//    $display("[%t], seg_len(64'hfffa_e000): %4d", $realtime, seg_len(64'hfffa_e000));
//    $display("[%t], seg_len(64'hfffa_1001): %4d", $realtime, seg_len(64'hfffa_1001));
//    $display("[%t], seg_len(64'hfffa_1ffa): %4d", $realtime, seg_len(64'hfffa_1ffa));
//    $display("[%t], seg_len(64'hfffa_1ff2): %4d", $realtime, seg_len(64'hfffa_1ff2));
//    $display("[%t], seg_len(64'hfffa_1ff4): %4d", $realtime, seg_len(64'hfffa_1ff4));
//    $display("[%t], seg_len(64'hfffa_100f): %4d", $realtime, seg_len(64'hfffa_100f));
//    $display("");
//    $display("[%t], seg_len_dw(64'hfffa_e000): %4d", $realtime, seg_len_dw(64'hfffa_e000));
//    $display("[%t], seg_len_dw(64'hfffa_1001): %4d", $realtime, seg_len_dw(64'hfffa_1001));
//    $display("[%t], seg_len_dw(64'hfffa_1ffa): %4d", $realtime, seg_len_dw(64'hfffa_1ffa));
//    $display("[%t], seg_len_dw(64'hfffa_1ff2): %4d", $realtime, seg_len_dw(64'hfffa_1ff2));
//    $display("[%t], seg_len_dw(64'hfffa_1ff4): %4d", $realtime, seg_len_dw(64'hfffa_1ff4));
//    $display("[%t], seg_len_dw(64'hfffa_100f): %4d", $realtime, seg_len_dw(64'hfffa_100f));
//
////  gen_seg(64'hfffa_1ffa, 16);
////  gen_seg(64'hfffa_1ffa, 16+4096);
////  gen_seg(64'hfffa_1ffc, 5000);
////
////  $stop(2);
//
//end
//------------------------------------------------------------------------------
//
//    Logic
//

always_comb begin
    
    ars_in.valid     = m_a.avalid;
    m_a.aready       = ars_in.ready;
    ars_in.data.addr = m_a.addr;
    ars_in.data.len  = m_a.len;

//  s_a.avalid       = ars_out.valid;
//  ars_out.ready    = s_a.aready;
//  s_a.addr         = ars_out.data.addr;
//  s_a.len          = ars_out.data.len;

    //s_a.avalid       = avalid;
    s_a.avalid       = dsci_queue.push;
    //ars_out.ready    = afsm == afsmIDLE;
    ars_out.ready    = aready;
    s_a.addr         = curr_addr;
    s_a.len          = curr_len;
end

always_comb begin
    
    drs_in.valid     = m_d.valid;
    m_d.ready        = drs_in.ready;
    drs_in.data.data = m_d.data;
    drs_in.data.last = m_d.last;

//  s_d.valid        = drs_out.valid;
//  drs_out.ready    = s_d.ready;
//  s_d.data         = drs_out.data.data;
//  s_d.last         = drs_out.data.last;

//  ds_data_in.valid    = drs_out.valid;
//  drs_out.ready       = ds_data_in.ready;
//  ds_data_in.data     = drs_out.data.data;
//  ds_data_in.last     = drs_out.data.last;

    s_d.valid         = ds_data_out.valid;
    ds_data_out.ready = s_d.ready;
    s_d.data          = ds_data_out.data;
    s_d.last          = ds_data_out.last;

end

//always_comb begin
//
//    cb_dready = 0;
//
//    case(afsm)
//    //--------------------------------------------
//    afsmIDLE: begin
//        cb_dready = ds_data_in.ready;
//        if(afsm_next == afsmIDLE) begin
//        end
//    end
//    //--------------------------------------------
//    afsmSEG: begin
//        cb_dready = ds_data_in.ready;
//        if(drs_out.data.last) begin
//            if(afsm_next == afsmSEG) begin
//                cb_dready = 0;
//            end
//        end
//    end
//    //--------------------------------------------
//    endcase
//
//    cb_dvalid = cb_dready;
//
//end

//--------------------------------------------------------------------
//
//    Address Channel FSM
//
always_ff @(posedge clk) begin
    afsm <= afsm_next;
end

always_comb begin : afsm_comb_b
    
    automatic address_channel_fsm_t next;
    
    next = afsm;

    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        if(ars_out.valid && aready) begin
            //if(ars_out.data.len > ANB_BC || ars_out.data.len > max_seg_len ) begin
            if(ars_out.data.len > max_seg_len ) begin
                next = afsmSEG;
            end
        end
    end
    //--------------------------------------------
    afsmSEG: begin : afsmSEG_b
        if(!dsci_queue.full && rlen) begin
            //if(rlen == curr_len) begin
            if(rlen <= PAGE_SIZE) begin
                next = afsmIDLE;
            end
        end
    end : afsmSEG_b
    //--------------------------------------------
    endcase
    
    afsm_next = next;

end : afsm_comb_b
//--------------------------------------------------------------------


always_comb begin
    
    avalid           = 0;
    aready           = s_a.aready && !dsci_queue.full;

    max_seg_len      = seg_len(ars_out.data.addr);
    curr_addr        = ars_out.data.addr;
    curr_len         = afsm_next == afsmSEG ? min(ars_out.data.len, max_seg_len) : ars_out.data.len;
//  ds_offset        = 0;
//  ds_last_word_len = 'x;
//  curr_len_anbw    = seg_len_anbw(ds_offset*PCIE_BYTES + curr_len);
    dsci_queue.tail.offset        = 0;
    dsci_queue.tail.last_word_len = 'x;
    dsci_queue.tail.len           = curr_len;
    dsci_queue.tail.seg           = afsm_next == afsmSEG;
    dsci_queue.push               = 0;
    
    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        //avalid = afsm_next == afsmSEG ? 1 : ars_out.valid;
        //avalid = ars_out.valid;
        dsci_queue.push = ars_out.valid && aready;
    end
    //--------------------------------------------
    afsmSEG: begin
        //avalid = dfsm == dfsmIDLE;
        
        curr_addr = curr_addr_reg;
        //ds_offset = avalid ? ds_offset_reg : 0;
        //ds_offset = ds_offset_reg;
        if(rlen < PAGE_SIZE) begin
            curr_len = rlen;
        end
        else begin
            curr_len = PAGE_SIZE;
        end
        dsci_queue.tail.offset        = ds_offset_reg;
        dsci_queue.tail.last_word_len = last_word_dw_len(curr_len);;
        dsci_queue.tail.len           = curr_len;
        dsci_queue.push               = aready;
        
        //ds_last_word_len = last_word_dw_len(curr_len);
        //curr_len_anbw    = seg_len_anbw(ds_offset*PCIE_BYTES + curr_len);
    end
    //--------------------------------------------
    endcase
end

always_ff @(posedge clk) begin
    //curr_len_reg <= curr_len;
    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        curr_addr_reg <= ars_out.data.addr + curr_len;
        rlen          <= ars_out.data.len - curr_len;
        ds_offset_reg <= seg_len_dw(ars_out.data.addr)%ANB_DWC;

    end
    //--------------------------------------------
    afsmSEG: begin
        if(dsci_queue.push) begin
            curr_addr_reg <= curr_addr_reg + curr_len;
            rlen          <= rlen < PAGE_SIZE ? rlen - curr_len : rlen - PAGE_SIZE;
        end
    end
    //--------------------------------------------
    endcase
end

//--------------------------------------------------------------------
//
//    Data Channel FSM
//
always_ff @(posedge clk) begin
    dfsm <= dfsm_next;
end

always_comb begin : dfsm_comb_b

    automatic data_channel_fsm_t next = dfsm;
    
    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        if( !dsci_queue.empty && drs_out.valid && ds_data_in.ready ) begin
            next = dfsmRUN;
            if(curr_len_anbw == 1 && ds_data_in.valid && ds_data_in.ready) begin
                next = dfsmIDLE;
            end
        end
    end
    //--------------------------------------------
    dfsmRUN: begin
        if(ds_data_in.valid && ds_data_in.ready && curr_len_anbw_cnt == 1) begin
            next = dfsmIDLE;
        end
    end
    //--------------------------------------------
    endcase
    
    dfsm_next = next;
    
end : dfsm_comb_b
//--------------------------------------------------------------------

always_comb begin
    ds_offset        = dsci_queue.head.offset;
    ds_last_word_len = dsci_queue.head.last_word_len;
    curr_len_anbw    = seg_len_anbw(ds_offset * PCIE_BYTES + dsci_queue.head.len);
end

always_comb begin
    
    automatic logic valid = 0;
    automatic logic last  = 0;
    automatic logic ready = 0;
    
    //ready            = ds_data_in.ready;
    ds_data_in.data  = drs_out.data.data;
    
    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin

        if( !dsci_queue.empty && drs_out.valid && ds_data_in.ready ) begin
            valid = drs_out.valid;
            if( curr_len_anbw == 1 ) begin
                last  = 1;
                ready = dsci_queue.head.seg ? 0 : ds_data_in.ready;
            end
            else begin
                ready = ds_data_in.ready;
            end
        end
        
    end
    //--------------------------------------------
    dfsmRUN: begin
        ready = ds_data_in.ready;
        valid = drs_out.valid;
        
        if(valid ) begin
            if(curr_len_anbw_cnt == 1) begin
                last  = 1;
                ready = dsci_queue.head.seg ? 0 : ds_data_in.ready;
            end
        end
        
        
//      ready = last ? 0 : ds_data_in.ready;
//      if(afsm == afsmIDLE) begin
//          ready = ds_data_in.ready;
//      end
    end
    //--------------------------------------------
    endcase
    
    ds_data_in.valid = valid;
    ds_data_in.last  = last;
    drs_out.ready    = ready;
end

always_ff @(posedge clk) begin
    

    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        curr_len_anbw_cnt <= curr_len_anbw - 1;
        if( dfsm_next == dfsmRUN ) begin
        end
    end
    //--------------------------------------------
    dfsmRUN: begin
        if(ds_data_in.valid && ds_data_in.ready) begin
            curr_len_anbw_cnt <= curr_len_anbw_cnt - 1;
        end
    end
    //--------------------------------------------
    endcase
end

always_comb begin
    dsci_queue.pop = 0;
    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        //if( dfsm_next == dfsmRUN ) begin
        if( !dsci_queue.empty && drs_out.valid  && ds_data_in.ready ) begin
            if(curr_len_anbw == 1) begin
                dsci_queue.pop = 1;
            end
        end
    end
    //--------------------------------------------
    dfsmRUN: begin
        if(ds_data_in.valid && ds_data_in.ready && curr_len_anbw_cnt == 1) begin
            dsci_queue.pop = 1;
        end
    end
    //--------------------------------------------
    endcase
end


int N = 0;
always_ff @(posedge clk) begin
    if(dsci_queue.push) begin
        $display("[%t], SEG%1d, fsm: %x -> %x curr_addr: %x, curr_len: %5d, curr_len_anbw: %4d, rlen: %5d, ds_offset: %1d, ds_last_word_len: %1d",
                 $realtime,
                 N++,
                 afsm,
                 afsm_next,
                 curr_addr,
                 curr_len,
                 curr_len_anbw,
                 afsm == afsmIDLE ? ars_out.data.len - curr_len : rlen < PAGE_SIZE ? rlen - curr_len : rlen - PAGE_SIZE,
                 ds_offset,
                 //ds_offset_reg,
                 ds_last_word_len );
    end
    if(drs_out.valid && drs_out.ready && drs_out.data.last) begin
        N = 0;
    end
end



//------------------------------------------------------------------------------
//
//    Instances
//
(* keep_hierarchy="yes" *)
reg_stage_m
#(
    .DATA_T ( adata_t )
)
addr_ch_reg_slice
(
    .clk       ( clk           ),
    .valid_src ( ars_in.valid  ),
    .ready_src ( ars_in.ready  ),
    .src       ( ars_in.data   ),
    .valid_dst ( ars_out.valid ),
    .ready_dst ( ars_out.ready ),
    .dst       ( ars_out.data  )
);
//------------------------------------------------------------------------------
(* keep_hierarchy="yes" *)
reg_stage_m
#(
    .DATA_T ( ddata_t )
)
data_ch_reg_slice
(
    .clk       ( clk           ),
    .valid_src ( drs_in.valid  ),
    .ready_src ( drs_in.ready  ),
    .src       ( drs_in.data   ),
    .valid_dst ( drs_out.valid ),
    .ready_dst ( drs_out.ready ),
    .dst       ( drs_out.data  )
);
//------------------------------------------------------------------------------
fifo_sc_m
#(
    .DATA_ITEM_TYPE ( ds_control_item_t ),
    .DEPTH          ( 32                ),
    .MEMTYPE        ( "distributed"     )
)
addr_queue
(
    .clk         ( clk                    ),
    .rst         ( rst                    ),
    .tail        ( dsci_queue.tail        ),
    .head        ( dsci_queue.head        ),
    .push        ( dsci_queue.push        ),
    .pop         ( dsci_queue.pop         ),
    .full        ( dsci_queue.full        ),
    .empty       ( dsci_queue.empty       ),
    .wr_rst_busy ( dsci_queue.wr_rst_busy ),
    .rd_rst_busy ( dsci_queue.rd_rst_busy )
);
//------------------------------------------------------------------------------
(* keep_hierarchy="yes" *)
anb_data_align_m
#(
    .DATA_W     ( ANB_BC     ),    // data units
    .MAX_OFFSET ( ANB_DWC    ),    // data units
    .SPAN       ( PCIE_BYTES )     // data unit size
)
data_shift
(
    .clk    ( clk              ),
    .offset ( ds_offset        ),
    .len    ( ds_last_word_len ),
    .m      ( ds_data_in       ),
    .s      ( ds_data_out      )
);

//------------------------------------------------------------------------------

endmodule : anb_wr_splitter_m
//------------------------------------------------------------------------------

