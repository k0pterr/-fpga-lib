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
    parameter type ADDR_T,
    parameter type LEN_T,
    parameter type DATA_T
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
    afsmSEG
}
address_channel_fsm_t;

typedef enum logic [1:0]
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

//------------------------------------------------------------------------------
//
//    Objects
//
addr_ch_t             ars_in;           // Address (channel) Register Slice Input
addr_ch_t             ars_out;          // Address (channel) Register Slice Output

data_ch_t             drs_in;           // Data (channel) Register Slice Input
data_ch_t             drs_out;          // Data (channel) Register Slice Output

address_channel_fsm_t afsm = afsmIDLE;
address_channel_fsm_t afsm_next;

data_channel_fsm_t    dfsm = dfsmIDLE;
data_channel_fsm_t    dfsm_next;

ADDR_T                curr_addr;
ADDR_T                curr_addr_reg;
LEN_T                 rlen;               // residual length
seg_len_t             max_seg_len;
seg_len_t             curr_len;
seg_len_anbw_t        curr_len_anbw;
seg_len_anbw_t        curr_len_anbw_cnt = 0;
anb_dwc_t             ds_offset;          // 'ds' means 'data shifter'
anb_dwc_t             ds_offset_reg;      // 'ds' means 'data shifter'
anb_dwc_t             ds_last_word_len;   // 'ds' means 'data shifter'

logic                 avalid = 0;
logic                 dfirst = 1;
//logic                 dlast  = 0;

seg_len_anbw_t        anbw_cnt;

logic                 cb_dready  = 0;
logic                 cb_dvalid  = 0;

logic                 cb_din_handshake;
logic                 cb_dout_handshake;

anb_data_channel_if #( .DATA_T( DATA_T) ) ds_data_in();
anb_data_channel_if #( .DATA_T( DATA_T) ) ds_data_out();

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

    //return len/ANB_BC_W + |len[0 +:ANB_BC_W];
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

    s_a.avalid       = avalid;
    ars_out.ready    = afsm == afsmIDLE;
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

always_comb begin

    cb_dready = 0;

    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        cb_dready = ds_data_in.ready;
        if(afsm_next == afsmIDLE) begin
        end
    end
    //--------------------------------------------
    afsmSEG: begin
        cb_dready = ds_data_in.ready;
        if(drs_out.data.last) begin
            if(afsm_next == afsmSEG) begin
                cb_dready = 0;
            end
        end
    end
    //--------------------------------------------
    endcase

    cb_dvalid = cb_dready;

end

//--------------------------------------------------------------------
//
//    Address Channel FSM
//
always_ff @(posedge clk) begin
    afsm <= afsm_next;
end

always_comb begin
    afsm_next = afsm;

    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        max_seg_len = seg_len(ars_out.data.addr);
        if(ars_out.valid && s_a.aready && dfsm == dfsmIDLE) begin
            //if(max_seg_len) begin  // addr not aligned to page boundary
            if(ars_out.data.len > ANB_BC || ars_out.data.len > max_seg_len ) begin
                afsm_next = afsmSEG;
            end
        end
    end
    //--------------------------------------------
    afsmSEG: begin
        if(rlen == curr_len) begin
            afsm_next = afsmIDLE;
        end
    end
    //--------------------------------------------
    endcase

end
//--------------------------------------------------------------------

always_comb begin
    avalid = 0;
    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        curr_addr        = ars_out.data.addr;
        curr_len         = afsm_next == afsmSEG ? min(ars_out.data.len, max_seg_len) : ars_out.data.len;
        ds_offset        = 0;
        ds_last_word_len = 'x;
        avalid           = afsm_next == afsmSEG ? 1 : ars_out.valid;
    end
    //--------------------------------------------
    afsmSEG: begin
//      if(dfsm == dfsmRUN && cb_dout_handshake &&
//         curr_len_anbw_cnt == 1) begin
//          avalid = 1;
//      end
        avalid = dfsm == dfsmIDLE;
        
        curr_addr = curr_addr_reg;
        ds_offset = avalid ? ds_offset_reg : 0;
        if(rlen < PAGE_SIZE) begin
            curr_len = rlen;
        end
        else begin
            curr_len = PAGE_SIZE;
        end
        //ds_last_word_len = ds_offset + last_word_dw_len(curr_len);
        ds_last_word_len = last_word_dw_len(curr_len);

    end
    //--------------------------------------------
    endcase
    //curr_len_anbw = seg_len_anbw(curr_len);
    curr_len_anbw = seg_len_anbw(ds_offset*PCIE_BYTES + curr_len);
end

always_ff @(posedge clk) begin
    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        curr_addr_reg     <= ars_out.data.addr + curr_len;
        //curr_len_anbw_cnt <= curr_len_anbw;
        //ds_offset_reg <= ANB_DWC - seg_len_dw(ars_out.data.addr)%ANB_DWC;
        ds_offset_reg <= seg_len_dw(ars_out.data.addr)%ANB_DWC;
        if(ars_out.valid) begin
            rlen <= ars_out.data.len - curr_len;
        end

    end
    //--------------------------------------------
    afsmSEG: begin
        if(avalid) begin
            curr_addr_reg     <= curr_addr_reg + curr_len;
            //curr_len_anbw_cnt <= curr_len_anbw;
            rlen              <= rlen < PAGE_SIZE ? rlen - curr_len : rlen - PAGE_SIZE;
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

always_comb begin

    dfsm_next = dfsm;

    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        if(avalid) begin
            dfsm_next = dfsmRUN;
//          if(afsm == afsmIDLE && afsm_next == afsmIDLE) begin         // no boundary crossing
//              if( cb_din_handshake && drs_out.data.last ) begin       // check if only one ANB word
//                  dfsm_next = dfsmIDLE;
//              end
//          end
            if(curr_len_anbw == 1) begin
                dfsm_next = dfsmIDLE;
            end
        end
    end
    //--------------------------------------------
    dfsmRUN: begin
        if(cb_dout_handshake && curr_len_anbw_cnt == 1) begin
            dfsm_next = dfsmIDLE;
        end
    end
    //--------------------------------------------
    endcase

end
//--------------------------------------------------------------------
always_comb begin
    drs_out.ready = 0;

    ds_data_in.valid = 0;
    ds_data_in.data  = drs_out.data.data;
    ds_data_in.last  = 0;

    
    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        
        if(cb_dout_handshake && curr_len_anbw == 1 ) begin
            ds_data_in.last = 1;
        end

        case(afsm)
        //--------------------------------------------
        afsmIDLE: begin
            if(afsm_next == afsmIDLE) begin                               // no boundary crossing
                drs_out.ready    = ds_data_in.ready;                      // path handshake signals
                ds_data_in.valid = drs_out.valid;                         //
            end
            else begin
                drs_out.ready    = ds_data_in.last ? 0 : ds_data_in.ready;
                ds_data_in.valid = drs_out.valid;
            end
        end
        //--------------------------------------------
        afsmSEG: begin
            drs_out.ready    = ds_data_in.last && afsm_next == afsmSEG ? 0 : ds_data_in.ready;
            ds_data_in.valid = drs_out.valid;
        end
        //--------------------------------------------
        endcase

    end
    //--------------------------------------------
    dfsmRUN: begin
        drs_out.ready    = ds_data_in.last ? 0 : ds_data_in.ready;
        ds_data_in.valid = drs_out.valid;
        if(cb_dout_handshake && curr_len_anbw_cnt == 1) begin
            ds_data_in.last = 1;
        end
    end
    //--------------------------------------------
    endcase

end

always_comb begin
    cb_din_handshake  = drs_out.valid && drs_out.ready;
    cb_dout_handshake = ds_data_in.valid && ds_data_in.ready;
end

always_comb begin
    if(avalid) begin
        anbw_cnt = curr_len_anbw;
    end
    else begin
        anbw_cnt = curr_len_anbw_cnt;
    end
end

always_ff @(posedge clk) begin
    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        if(avalid) begin
            curr_len_anbw_cnt <= curr_len_anbw - 1;
            //if(afsm_next == afsmSEG) begin
            if(cb_dout_handshake && curr_len_anbw > 1) begin
                dfirst <= 0;
            end
        end
    end
    //--------------------------------------------
    dfsmRUN: begin
        if(cb_dout_handshake) begin
            dfirst <= 0;
            curr_len_anbw_cnt <= curr_len_anbw_cnt - 1;
            if(curr_len_anbw_cnt == 1) begin
       //         dfirst <= 1;
            end
        end

        if(avalid) begin
            curr_len_anbw_cnt <= curr_len_anbw;
        end
    end
    //--------------------------------------------
    endcase

end



int N = 0;
always_ff @(posedge clk) begin
    if(avalid) begin
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
end



//------------------------------------------------------------------------------
//
//    Instances
//
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

