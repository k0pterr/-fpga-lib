//------------------------------------------------------------------------------
//  project:       any
//
//  description:   wrapper for common.pkg
//------------------------------------------------------------------------------

`ifndef COMMON_SVH
`define COMMON_SVH

`include "common.pkg"

//------------------------------------------------------------------------------
`define PRINT_MACRO_STATUS(x,y = "")                \
        `ifdef x                                    \
            $write("%-40s - ON  %s\n", `"x`", y);   \
        `else                                       \
            $write("%-40s - OFF %s\n", `"x`", y);   \
        `endif

`endif // COMMON_SVH

