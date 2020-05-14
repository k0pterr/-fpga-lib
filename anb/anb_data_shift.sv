//------------------------------------------------------------------------------
//
//     Project:     Any
//
//     Description: ANB Data Stream Shifters
//
//     Version: 1.0
//
//------------------------------------------------------------------------------

`include "common.svh"
`include "cfg_params_generated.svh"

//------------------------------------------------------------------------------
//
//   ANB Data Channel Align module
//
//
//   DESCRIPTION
//
//     Terms
//     ~~~~~
//
//         -----------+----------------------------------------------------------------
//         data unit  | input data word slice. Size of data unit must be a divisor 
//                    | of DATA_W (see below) without remainder.
//         -----------+----------------------------------------------------------------
//
//
//     Parameters
//     ~~~~~~~~~~
//
//         -----------+----------------------------------------------------------------
//         DATA_W     | specifies ANB data word width in 8-bit bytes.
//         -----------+----------------------------------------------------------------
//         MAX_OFFSET | set limit for data shift, dramatically affects synthesis 
//                    | result.
//         -----------+----------------------------------------------------------------
//         SPAN:      | set a size of data unit. Data unit shifted as whole subword. 
//                    | For example, if DATA_W = 16, SPAN = 4, this means that input 
//                    | 128 bit bus handled as 4 32-bit subwords.
//         -----------+----------------------------------------------------------------
//
//     Ports
//     ~~~~~
//
//         -----------+----------------------------------------------------------------
//         offset     | offset within input data word in data units, typically consists
//                    | of address LSBs (if SPAN = 1).
//         -----------+----------------------------------------------------------------
//         len        | length of data stream tail - in fact, the last data word size 
//                    | in data units.
//         -----------+----------------------------------------------------------------
//         m          | master data interface - input data for the module
//         -----------+----------------------------------------------------------------
//         s          | slave data interface - output data of the module
//         -----------+----------------------------------------------------------------
//
//
//     Examples
//     ~~~~~~~~
//
//            src.addr: transaction address
//            src.len:  tranaction length
//
//        ---+--------------------------------------------------------------------  
//         1.| DATA_W     = 4   // bytes -> 32-bit bus width
//           | MAX_OFFSET = 4
//           | SPAN       = 1   // data unit = 1 byte
//           |
//           | offset = src.addr[clog2(MAX_OFFSET)-1:0] = src.addr[1:0]
//           | len    = src.len[clog2(DATA_W/SPAN)-1:0] = src.len[1:0]
//        ---+--------------------------------------------------------------------  
//         2.| DATA_W     = 16  // bytes -> 128-bit bus width
//           | MAX_OFFSET = 4
//           | SPAN       = 1   // data unit = 1 byte
//           |
//           | offset = src.addr[clog2(MAX_OFFSET)-1:0] = src.addr[1:0]
//           | len    = src.len[clog2(DATA_W/SPAN)-1:0] = src.len[3:0]
//        ---+--------------------------------------------------------------------  
//         3.| DATA_W     = 16  // bytes -> 128-bit bus width
//           | MAX_OFFSET = 4
//           | SPAN       = 4   // data unit = 4 bytes
//           |
//           | offset = src.addr[0 +: clog2(MAX_OFFSET*SPAN)]/SPAN = src.addr[3:2]
//           | len    = src.len [0 +: clog2(DATA_W)]/SPAN          = src.len[3:2]
//        ---+--------------------------------------------------------------------  
//
//

module automatic anb_data_align_m
#(
    parameter   DATA_W        = 16,                   // data units
    parameter   MAX_OFFSET    = 4,                    // data units
    parameter   SPAN          = 4,                    // data unit size
    localparam  OFFSET_W      = clog2(MAX_OFFSET),
    localparam  LEN_W         = clog2(DATA_W/SPAN),
    localparam  type offset_t = logic [OFFSET_W-1:0],
    localparam  type len_t    = logic [LEN_W-1:0]
)
(
    input  logic                clk,
                                
    input logic [OFFSET_W-1:0]  offset,
    input len_t                 len,
    anb_data_channel_if.s       m,
    anb_data_channel_if.m       s
);

//------------------------------------------------------------------------------
//
//    Settings
//
localparam DATA_WORD_LEN   = DATA_W/SPAN;
localparam DATA_WORD_LEN_W = clog2(DATA_WORD_LEN);

//------------------------------------------------------------------------------
//
//    Types
//
typedef logic  [         SPAN*8-1:0] unit_t;
typedef unit_t [  DATA_WORD_LEN-1:0] data_t;
typedef unit_t [DATA_WORD_LEN-1-1:0] data_reg_t;
typedef logic  [       OFFSET_W-1:0] data_index_t;
typedef logic  [DATA_WORD_LEN_W-1:0] data_count_t;

typedef enum logic [1:0]
{
    fsmWAIT,
    fsmRUN,
    fsmTAIL
}
fsm_t;

//------------------------------------------------------------------------------
//
//    Objects
//
data_reg_t   data_reg;
offset_t     offset_reg;
data_count_t tail_count;
fsm_t        fsm = fsmWAIT;

//------------------------------------------------------------------------------
//
//    Functions and tasks
//
function data_reg_t data_slice_high(input data_t data, input data_index_t ofst);
    
    return data >> ofst*8*SPAN;
    
endfunction
//------------------------------------------------
function data_count_t tail_data_count(input offset_t offset, input len_t len);

    return ( offset + len)%DATA_W;
    
endfunction
//------------------------------------------------------------------------------
function data_t merge_out(input data_reg_t   dreg, 
                          input data_t       din, 
                          input data_index_t oset);
    
    data_t dout;
    int    didx = 0;
    
    for(int i = 0; i < DATA_WORD_LEN-1; ++i) begin
        if(i < DATA_WORD_LEN - oset) begin
            dout[i] = dreg[i];
        end
        else begin
            dout[i] = din[didx];
            ++didx;
        end
    end
    dout[DATA_WORD_LEN-1] = din[didx];
            
    return dout;
    
endfunction
//------------------------------------------------------------------------------
//
//    Logic
//
always_comb begin : mux_b
    
    s.valid = m.valid;
    m.ready = s.ready;

    s.data = m.data;
    s.last = m.last;
    
    case(fsm)
    //----------------------------------------    
    fsmWAIT: begin
        if( offset && !m.last ) begin
            s.valid = 0;
            m.ready = 1;
        end
        
        if(m.last && offset) begin
            s.data = data_slice_high(m.data, offset);
        end
    end
    //----------------------------------------
    fsmRUN: begin
        s.data = merge_out(data_reg, m.data, offset);
        
        s.valid = m.valid;
        m.ready = s.ready;
        if(tail_count > offset_reg || tail_count == 0) begin // not fit in the last data word
            s.last = 0;
        end
    end
    //----------------------------------------
    fsmTAIL: begin
        s.data = data_reg;

        s.valid = 1;
        m.ready = 0;
        s.last  = 1;
    end
    //----------------------------------------
    endcase
    
end : mux_b

always_ff @(posedge clk) begin
    if(m.valid && m.ready) begin
        data_reg <= data_slice_high(m.data, offset);
    end
    
    if(fsm == fsmWAIT && m.valid) begin
        offset_reg <= offset;
        tail_count <= tail_data_count(offset, len);
    end
    
end

always_ff @(posedge clk) begin
    
    case(fsm)
    //----------------------------------------
    fsmWAIT: begin
        if(m.valid && !m.last && offset) begin
            fsm <= fsmRUN;
        end
    end
    //----------------------------------------    
    fsmRUN: begin
        if(m.valid && m.ready && m.last) begin
            if(tail_count <= offset_reg && tail_count) begin // fit in the last data word
                fsm <= fsmWAIT;
            end
            else begin
                fsm <= fsmTAIL;
            end
        end
    end
    //----------------------------------------
    fsmTAIL: begin
        if(s.ready) begin
            fsm <= fsmWAIT;
        end
    end
    //----------------------------------------
    endcase
end

//------------------------------------------------------------------------------
//
//    Instances
//

//------------------------------------------------------------------------------

endmodule : anb_data_align_m
//------------------------------------------------------------------------------
//******************************************************************************
//******************************************************************************
//******************************************************************************
//------------------------------------------------------------------------------
//
//   ANB Data Channel Unalign module
//
//
//   DESCRIPTION
//
//     Terms
//     ~~~~~
//
//         -----------+----------------------------------------------------------------
//         data unit  | input data word slice. Size of data unit must be a divisor 
//                    | of DATA_W (see below) without remainder.
//         -----------+----------------------------------------------------------------
//
//
//     Parameters
//     ~~~~~~~~~~
//
//         -----------+----------------------------------------------------------------
//         DATA_W     | specifies ANB data word width in 8-bit bytes.
//         -----------+----------------------------------------------------------------
//         MAX_OFFSET | set limit for data shift, dramatically affects synthesis 
//                    | result.
//         -----------+----------------------------------------------------------------
//         SPAN:      | set a size of data unit. Data unit shifted as whole subword. 
//                    | For example, if DATA_W = 16, SPAN = 4, this means that input 
//                    | 128 bit bus handled as 4 32-bit subwords.
//         -----------+----------------------------------------------------------------
//
//     Ports
//     ~~~~~
//
//         -----------+----------------------------------------------------------------
//         offset     | offset within input data word in data units, typically consists
//                    | of address LSBs (if SPAN = 1).
//         -----------+----------------------------------------------------------------
//         len        | length of data stream tail - in fact, the last data word size 
//                    | in data units.
//         -----------+----------------------------------------------------------------
//         m          | master data interface - input data for the module
//         -----------+----------------------------------------------------------------
//         s          | slave data interface - output data of the module
//         -----------+----------------------------------------------------------------
//
//
//     Examples
//     ~~~~~~~~
//
//            src.addr: transaction address
//            src.len:  tranaction length
//
//        ---+--------------------------------------------------------------------  
//         1.| DATA_W     = 4   // bytes -> 32-bit bus width
//           | MAX_OFFSET = 4
//           | SPAN       = 1   // data unit = 1 byte
//           |
//           | offset = src.addr[clog2(MAX_OFFSET)-1:0] = src.addr[1:0]
//           | len    = src.len[clog2(DATA_W/SPAN)-1:0] = src.len[1:0]
//        ---+--------------------------------------------------------------------  
//         2.| DATA_W     = 16  // bytes -> 128-bit bus width
//           | MAX_OFFSET = 4
//           | SPAN       = 1   // data unit = 1 byte
//           |
//           | offset = src.addr[clog2(MAX_OFFSET)-1:0] = src.addr[1:0]
//           | len    = src.len[clog2(DATA_W/SPAN)-1:0] = src.len[3:0]
//        ---+--------------------------------------------------------------------  
//         3.| DATA_W     = 16  // bytes -> 128-bit bus width
//           | MAX_OFFSET = 4
//           | SPAN       = 4   // data unit = 4 bytes
//           |
//           | offset = src.addr[0 +: clog2(MAX_OFFSET*SPAN)]/SPAN = src.addr[3:2]
//           | len    = src.len [0 +: clog2(DATA_W)]/SPAN          = src.len[3:2]
//        ---+--------------------------------------------------------------------  
//
//
module automatic anb_data_unalign_m
#(
    parameter   DATA_W        = 16,                   // data units
    parameter   MAX_OFFSET    = 4,                    // data units
    parameter   SPAN          = 4,                    // data unit size
    localparam  OFFSET_W      = clog2(MAX_OFFSET),
    localparam  LEN_W         = clog2(DATA_W/SPAN),
    localparam  type offset_t = logic [OFFSET_W-1:0],
    localparam  type len_t    = logic [LEN_W-1:0]
)
(
    input  logic           clk,
                           
    input offset_t         offset,
    input len_t            len,
    anb_data_channel_if.s  m,
    anb_data_channel_if.m  s
);

//------------------------------------------------------------------------------
//
//    Settings
//
localparam DATA_WORD_LEN   = DATA_W/SPAN;
localparam DATA_WORD_LEN_W = clog2(DATA_WORD_LEN);
localparam TAIL_WORD_LEN_W = bits(DATA_WORD_LEN);

//------------------------------------------------------------------------------
//
//    Types
//
typedef logic  [         SPAN*8-1:0] unit_t;
typedef unit_t [  DATA_WORD_LEN-1:0] data_t;
typedef unit_t [   MAX_OFFSET-1-1:0] data_reg_t;
typedef logic  [DATA_WORD_LEN_W-1:0] data_count_t;
typedef logic  [TAIL_WORD_LEN_W-1:0] tail_count_t;

typedef enum logic [1:0]
{
    fsmWAIT,
    fsmRUN,
    fsmTAIL
}
fsm_t;

//------------------------------------------------------------------------------
//
//    Objects
//
data_reg_t   data_reg;
offset_t     offset_reg;
tail_count_t tail_count;
fsm_t        fsm = fsmWAIT;

//------------------------------------------------------------------------------
//
//    Functions and tasks
//
function data_reg_t data_slice_high(input data_t data, input offset_t ofst);

    return data >> (DATA_W-ofst*SPAN)*8;

endfunction
//------------------------------------------------
function tail_count_t tail_data_count(input offset_t offset, input len_t len);

    return  offset + last_word_len(len);

endfunction
//------------------------------------------------------------------------------
function tail_count_t last_word_len(input len_t len);
    
    return len ? len : 1 << DATA_WORD_LEN_W;
                               
endfunction
//------------------------------------------------------------------------------
function data_t merge_out(input data_reg_t dreg, 
                          input data_t     din, 
                          input offset_t   oset);

    data_t dout;
    int    didx = 0;

    for(int i = 0; i < DATA_WORD_LEN; ++i) begin
        if(i < oset) begin
            dout[i] = dreg[i];
        end
        else begin
            dout[i] = din[didx];
            ++didx;
        end
    end

    return dout;

endfunction
//------------------------------------------------------------------------------
//
//    Logic
//
always_comb begin : mux_b

    s.valid = m.valid;
    m.ready = s.ready;

    s.data = m.data;
    s.last = m.last;

    case(fsm)
    //----------------------------------------    
    fsmWAIT: begin

        if(offset) begin
            //s.data = merge_out('x, m.data, offset);
            s.data = merge_out('0, m.data, offset);
            if(offset + last_word_len(len) > DATA_WORD_LEN) begin
                s.last = 0;
            end
        end
    end
    //----------------------------------------
    fsmRUN: begin
        s.data = merge_out(data_reg, m.data, offset_reg);

        if(tail_count > DATA_WORD_LEN) begin           // not fit in the last data word
            s.last = 0;
        end
    end
    //----------------------------------------
    fsmTAIL: begin
        s.data = data_reg;

        s.valid = 1;
        m.ready = 0;
        s.last  = 1;
    end
    //----------------------------------------
    endcase

end : mux_b

always_ff @(posedge clk) begin
    if(m.valid && m.ready) begin
        if(fsm == fsmWAIT) begin
            data_reg <= data_slice_high(m.data, offset);
        end
        else begin
            data_reg <= data_slice_high(m.data, offset_reg);
        end
    end

    if(fsm == fsmWAIT && m.valid) begin
        offset_reg <= offset;
        tail_count <= tail_data_count(offset, len);
    end

end

always_ff @(posedge clk) begin

    case(fsm)
    //----------------------------------------
    fsmWAIT: begin
        if(m.valid && m.ready && offset) begin
            if(m.last) begin
                if(offset + last_word_len(len) > DATA_WORD_LEN) begin
                    fsm <= fsmTAIL;
                end
            end
            else begin
                fsm <= fsmRUN;
            end
        end
    end
    //----------------------------------------    
    fsmRUN: begin
        if(m.valid && m.ready && m.last) begin
            if(tail_count <= DATA_WORD_LEN) begin      // fit in the last data word
                fsm <= fsmWAIT;
            end
            else begin
                fsm <= fsmTAIL;
            end
        end
    end
    //----------------------------------------
    fsmTAIL: begin
        if(s.ready) begin
            fsm <= fsmWAIT;
        end
    end
    //----------------------------------------
    endcase
end

//------------------------------------------------------------------------------
//
//    Instances
//

//------------------------------------------------------------------------------

endmodule : anb_data_unalign_m
//------------------------------------------------------------------------------

