//------------------------------------------------------------------------------
//
//     ANB Read Memory Controller stuff
//

`include "bmd_mc.svh"

//------------------------------------------------------------------------------
//
//     ANB Read Memory Controller crossbar module
//
module automatic smc_rd_crossbar_m    
#(
    parameter N = 1
)
(
    input logic clk,
    //input logic rst,
    
    anb_rd_if.s   m[N],
    smc_rd_if.m   s
);
    
import bmd_mc_defs::*;    

typedef logic [       N-1:0] id_pattern_t;
typedef logic [clog2(N)-1:0] rd_id_t;
//--------------------------------------------------------------------
//
//   Objects
//

id_pattern_t       grant = 0;
id_pattern_t       mask  = 0;

rd_id_t            aid   = 0;  
//rd_id_t            id;  

//  Master address channel
smc_addr_t         m_addr[N];
smc_trn_max_len_t  m_len[N];
id_pattern_t       m_avalid;
id_pattern_t       m_aready;

//  Master data channel
smc_data_t         m_data[N];
smc_data_be_t      m_strb[N];
id_pattern_t       m_valid; 
id_pattern_t       m_ready; 
id_pattern_t       m_last;

//--------------------------------------------------------------------
//
//   Logic
//
//------------------------------------------------
generate
    for(genvar i = 0; i < N; ++i) begin
        assign m_addr[i]   = m[i].addr;
        assign m_len[i]    = m[i].len;
        assign m_avalid[i] = m[i].avalid;
        assign m[i].aready = m_aready[i];

        assign m[i].data   = m_data[i];
        //assign m[i].strb   = m_strb[i];
        assign m[i].last   = m_last[i];
        assign m[i].valid  = m_valid[i];
        assign m_ready[i]  = m[i].ready;
    end
endgenerate
//------------------------------------------------
//
//   Round-Robin Arbiter
//
always_ff @(posedge clk) begin
    if(grant == 0) begin
        if(s.aready) begin
            for(int i = 0; i < N; ++i) begin
                if(m_avalid[i] & ~mask[i]) begin
                    grant[i]  <= 1;
                    aid       <= i;
                    mask      <= mask | (1 << i);
                    break;
                end
                if(i == N-1) begin
                    mask <= 0;
                end
            end
        end
    end
    else begin
        grant[aid] <= m_avalid[aid];
    end
end

always_comb begin
    s.aid       = aid;
    s.avalid    = m_avalid[aid] & grant[aid];  // 'grant[aid]' because 'aid' always indexing any 'm_avalid'
    s.addr      = m_addr[aid];                 //  even if there is not granting to this master            
    s.len       = m_len[aid];
    m_aready    = s.aready ? grant : 0;

    m_valid       = 0;
    m_valid[s.id] = s.valid;

    s.ready       = m_ready[s.id];
    
    for(int i = 0; i < N; ++i) begin
        m_data[i] = s.data;
        m_strb[i] = s.strb;
        m_last[i] = s.last;
    end
end
        
endmodule
//------------------------------------------------------------------------------

