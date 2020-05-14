//------------------------------------------------------------------------------
//
//    Project: Any
//
//    Description: Application Native Bus Write Agent
//
//------------------------------------------------------------------------------

`include "common.svh"
`include "cfg_params_generated.svh"
`include "bmd_mc.svh"
`include "dpc_defs.svh"

//------------------------------------------------------------------------------
module automatic anb_wr_crossbar_m import dpc_defs::*, bmd_mc_defs::*;
#(
    parameter N           = 1,
    parameter ROUND_ROBIN = 0
)
(
    input  logic   clk,
    input  logic   rst,
    anb_wr_if.s    m[N],
    anb_wr_if.m    s
);

import bmd_mc_defs::*;

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

//------------------------------------------------------------------------------
//
//    Objects
//
smc_addr_t       m_addr[N];
task_data_len_t  m_len[N];
logic [N-1:0]    m_avalid;
logic [N-1:0]    m_aready;
smc_data_t       m_data[N];
logic [N-1:0]    m_last;
logic [N-1:0]    m_valid;
logic [N-1:0]    m_ready;

mask_t           grant = 0;
id_t             aid   = 0;  
mask_t           mask = 0;

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
    for(genvar i = 0; i < N; ++i) begin : imap_b
        assign m_addr[i]   = m[i].addr;
        assign m_len[i]    = m[i].len;
        assign m_avalid[i] = m[i].avalid;
        assign m[i].aready = m_aready[i];

        assign m_data[i]   = m[i].data;
        assign m_last[i]   = m[i].last;
        assign m_valid[i]  = m[i].valid;
        assign m[i].ready  = m_ready[i];
    end : imap_b
endgenerate
//----------------------------------------------------------
//
//    Arbiter
//
typedef enum logic [1:0]
{
    arbOFF,
    arbAREADY,
    arbON
}
arbfsm_t;

arbfsm_t arbfsm;

always_ff @(posedge clk) begin : arb_b

    automatic logic data_handshake = grant ? m_valid[aid] && m_ready[aid] : 0;

    if(rst) begin
        s.avalid <= 0;
        m_aready <= 0;
        grant    <= 0;
        arbfsm   <= arbOFF;
    end
    else begin
        case(arbfsm)
        //--------------------------------------------
        arbOFF: begin
            for(int i = 0; i < N; ++i) begin
                if(ROUND_ROBIN) begin
                    if(m_avalid[i] & ~mask[i]) begin
                        $display("[%t], <smc_crossbar> m_avalid[%1d]: %x, mask: %x", $realtime, i, m_avalid[i], mask);
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
                    if(m_avalid[i]) begin
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
                s.avalid      <= 0;
                m_aready[aid] <= 1;
                grant[aid]    <= 1;
                arbfsm        <= arbON;
            end
        end
        //--------------------------------------------
        arbON: begin
            m_aready <= 0;
            if(data_handshake) begin
                if(m_last[aid]) begin
                    $display("[%t] <anb_wr_agent> arbiter -> data last, master: %2d", $realtime, aid);
                    grant  <= 0;
                    arbfsm <= arbOFF;
                end
            end
        end
        //--------------------------------------------
        endcase
    end
end : arb_b

always_comb begin
    s.addr  = m_addr[aid];
    s.len   = m_len[aid];

    s.valid = m_valid[aid] && grant[aid];
    m_ready = s.ready ? grant : 0;
    s.data  = m_data[aid];
    s.last  = m_last[aid];
end

//------------------------------------------------------------------------------

endmodule : anb_wr_crossbar_m
//------------------------------------------------------------------------------

