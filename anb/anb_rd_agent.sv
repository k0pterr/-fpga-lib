//------------------------------------------------------------------------------
//
//    Project: Any
//
//    Description: Application Native Bus Read Agent
//
//------------------------------------------------------------------------------

`include "common.svh"
`include "cfg_params_generated.svh"
`include "dpc_defs.svh"

//------------------------------------------------------------------------------
//
//   
//
module anb_rd_agent_m import dpc_defs::*, bmd_mc_defs::*;
#(
    parameter N           = 1,
    parameter ROUND_ROBIN = 0
)
(
    input  logic       clk,
    input  logic       rst,
    anb_rd_agent_if.s  m[N],
    anb_rd_agent_if.m  s
);
//------------------------------------------------------------------------------
//
//    Settings
//
localparam ID_W = N == 1 ? 1 : clog2(N);

//------------------------------------------------------------------------------
//
//    Types
//
typedef logic [ID_W-1:0] id_t;
typedef logic [   N-1:0] mask_t;
    
typedef struct
{
    id_t    tail;
    id_t    head;
    logic   push;
    logic   pop;
    logic   full;
    logic   empty;
    logic   wr_rst_busy;
    logic   rd_rst_busy;
}
id_queue_t;

typedef enum logic [1:0]
{
    acrdfsmIDLE,
    acrdfsmADDR,
    acrdfsmDONE
}
address_channel_read_fsm_t;
    
//------------------------------------------------------------------------------
//
//    Objects
//
smc_addr_t      m_addr[N];
task_data_len_t m_len[N]; 
logic [N-1:0]   m_avalid;
logic [N-1:0]   m_aready;
smc_data_t      m_data[N];
logic [N-1:0]   m_last;  
logic [N-1:0]   m_valid; 
logic [N-1:0]   m_ready; 

//address_channel_read_fsm_t acrdfsm;
id_t                       aid   = 0;
id_queue_t                 id_q;
id_t                       id;
logic                      s_anb_rd_avalid;


mask_t mask = 0;

typedef enum logic [0:0]
{
    arbOFF,
    arbAREADY
}
arbfsm_t;

arbfsm_t arbfsm;


//------------------------------------------------------------------------------
//
//    Functions and tasks
//

//------------------------------------------------------------------------------
//
//    Logic
//
//----------------------------------------------------------
generate
    for(genvar i = 0; i < N; ++i) begin
        assign m_addr[i]   = m[i].addr;
        assign m_len[i]    = m[i].len;
        assign m_avalid[i] = m[i].avalid;
        assign m[i].aready = m_aready[i];
            
        assign m[i].data   = m_data[i];
        assign m[i].last   = m_last[i];
        assign m[i].valid  = m_valid[i];
        assign m_ready[i]  = m[i].ready;
    end
endgenerate

//----------------------------------------------------------
//
//    Arbiter
//
always_ff @(posedge clk) begin : arb_b

    if(rst) begin
        s.avalid <= 0;
        arbfsm   <= arbOFF;
    end
    else begin
        case(arbfsm)
        //--------------------------------------------
        arbOFF: begin
            for(int i = 0; i < N; ++i) begin
                if(ROUND_ROBIN) begin
                    if( (m_avalid[i] & ~mask[i]) && !id_q.full) begin
                        aid      <= i;
                        s.avalid <= 1;
                        arbfsm   <= arbAREADY;
                        mask     <= mask | (1 << i);
                        break;
                    end
                    if(i == N-1) begin
                        mask <= 0;
                    end
                end
                else begin   // simple priority
                    if(m_avalid[i] && !id_q.full) begin
                        aid      <= i;
                        s.avalid <= 1;
                        arbfsm   <= arbAREADY;
                        break;
                    end
                end
            end
        end
        //--------------------------------------------
        arbAREADY: begin
            if(s.aready) begin
                s.avalid <= 0;
                arbfsm   <= arbOFF;
            end
        end
        //--------------------------------------------
        endcase
    end
end : arb_b

always_comb begin
    s.addr  = m_addr[aid];
    s.len   = m_len[aid];
    
    m_aready      = 0;
    m_aready[aid] = arbfsm == arbAREADY ? s.aready : 0;
end

always_comb begin

    id_q.tail = aid;
    id_q.push = !id_q.full && s.avalid && s.aready;
    id        = id_q.head;
    
    for(int i = 0; i < N; ++i) begin
        m_valid[i]  = 0;
        m_last[i]   = 0;
        m_data[i]   = s.data;
        
        if(i == id) begin 
            m_valid[i]  = s.valid;
            m_last[i]   = s.last;
        end
    end

    s.ready = m_ready[id];
    id_q.pop      = !id_q.empty && s.valid && s.ready && s.last;
end
//------------------------------------------------------------------------------
//
//    Instances
//
fifo_sc_m
#(
    .DATA_ITEM_TYPE ( id_t          ),
    .DEPTH          ( 32            ),
    .MEMTYPE        ( "distributed" )
)
id_q_fifo
(
    .clk         ( clk                ),
    .rst         ( rst                ),
    .tail        ( id_q.tail        ),
    .head        ( id_q.head        ),
    .push        ( id_q.push        ),
    .pop         ( id_q.pop         ),
    .full        ( id_q.full        ),
    .empty       ( id_q.empty       ),
    .wr_rst_busy ( id_q.wr_rst_busy ),
    .rd_rst_busy ( id_q.rd_rst_busy )
);
//------------------------------------------------------------------------------

endmodule : anb_rd_agent_m
//------------------------------------------------------------------------------

