//------------------------------------------------------------------------------
//
//    Project:     Any
//
//    Description: Inferred Distibuted Simple Dual-Port RAM module
//
//------------------------------------------------------------------------------

module dist_ram_sdp_m
                #(
                   parameter int ADDR_WIDTH,
                   parameter int WORD_WIDTH,
                   parameter     OUT_REGISTERED = "YES",
                   parameter     INIT_FILE = ""  
                 )
(
    input  logic                  clk,

    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [WORD_WIDTH-1:0] data_in,

    input  logic [ADDR_WIDTH-1:0] raddr,
    output logic [WORD_WIDTH-1:0] data_out
);

//------------------------------------------------------------------------------
//
//    Settings
//
//
localparam RAM_SIZE = 2**ADDR_WIDTH;

//------------------------------------------------------------------------------
//
//    Objects
//
//
(* ram_style="distributed" *)
logic [WORD_WIDTH-1:0] ram[RAM_SIZE];

//------------------------------------------------------------------------------
//
//     Logic
//
initial begin
    if(INIT_FILE != "") begin
        $readmemh(INIT_FILE, ram, 0);
    end
end

//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if(we) begin
        ram[waddr] <= data_in;
    end
end

//------------------------------------------------------------------------------
if(OUT_REGISTERED == "YES") begin
    always_ff @(posedge clk) begin
        data_out <= ram[raddr];
    end
end
else begin
    assign data_out = ram[raddr];
end

endmodule : dist_ram_sdp_m
//------------------------------------------------------------------------------

