//******************************************************************************
//*
//*      Project:     Any
//*
//*      Description: Common code definitions file
//*
//*      Version 2.0
//*
//*      Copyright (c) 2008-2018, Harry E. Zhurov
//*
//------------------------------------------------------------------------------

`ifndef COMMON_H
`define COMMON_H

//------------------------------------------------------------------------------
package common;

//------------------------------------------------------------------------------
function automatic int clog2 (input int n); // this function calculates ceil(log2(n))
begin
    int num = n;
    int res;
    num = num - 1;                          // without this statement clog2(32) will be 6 but must be 5
    for (res = 0; num > 0; res = res + 1)
        num = num >> 1;

    return res;
end
endfunction
//------------------------------------------------------------------------------
function automatic int max(input int x, input int y);
    return x > y ? x : y;
endfunction
//------------------------------------------------------------------------------
function automatic int bits(input int x);
    int n = clog2(x);
    return  ( x == (1 << n) ) ? n + 1 : n;
endfunction
//------------------------------------------------------------------------------

endpackage

import common::*;
//------------------------------------------------------------------------------
`define PRINT_MACRO_STATUS(x,y = "")                \
        `ifdef x                                    \
            $write("%-50s - ON  %s\n", `"x`", y);   \
        `else                                       \
            $write("%-50s - OFF %s\n", `"x`", y);   \
        `endif

//------------------------------------------------------------------------------
`define CONSTRUCT_DIR(path1,path2) { path1, "/", path2 }

`endif // COMMON_H

