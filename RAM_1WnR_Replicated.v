//# Multi-Ported Memory using Replication (1WnR)

// Implements a memory with a single write port and multiple concurrent read
// ports (1WnR) by replicating the storage once for each read port and having
// writes go to all replicated storage banks. The implementation of the
// storage is set by a parameter.

// There is no synchronous clear on the output: In Quartus at least, any
// register driving it cannot be retimed, and it may not be as portable.
// Instead, use separate logic (e.g.: an [Annuller](./Annuller.html)) to
// zero-out the output down the line.

//## Write Forwarding

// The READ_NEW_DATA parameter control the behaviour of simultaneous reads and
// writes to the same address. This is the most important parameter when
// considering what kind of memory block the CAD tool will infer.

// * `READ_NEW_DATA = 0` describes a memory which returns the OLD value (in the
// memory) on coincident read and write (no write-forwarding).  This is
// well-suited for LUT-based memory, such as MLABs.
// * `READ_NEW_DATA = 1` (or any non-zero value) describes a memory which
// returns NEW data (from the write) on coincident read and write, usually by
// inferring some surrounding write-forwarding logic.  Good for dedicated
// Block RAMs, such as M10K.

// The inferred write-forwarding logic also allows the RAM to operate at
// higher frequency, since a read corrupted by a simultaneous write to the
// same address will be discarded and replaced by the write value at the
// output mux of the forwarding logic. Otherwise, the RAM must internally
// perform the write on one edge of the clock, and the read on the other,
// which requires a longer cycle time.

//### Quartus

// For Quartus, if you do not want write-forwarding, but still get the higher
// speed at the price of indeterminate behaviour on coincident read/writes,
// use "no_rw_check" as part of the RAMSTYLE (e.g.: "M10K, no_rw_check").
// Depending on the FPGA hardware, this may also help when returning OLD data.
// If that fails, add this setting to your Quartus project:
// `set_global_assignment -name ADD_PASS_THROUGH_LOGIC_TO_INFERRED_RAMS OFF`
// to disable creation of write-forwarding logic, as Quartus ignores the
// "no_rw_check" RAMSTYLE for M10K BRAMs.

//### Vivado

// Vivado uses a different mechanism to control write-forwarding: set
// RW_ADDR_COLLISION to "yes" to force the inference of write forwarding
// logic, or "no" to prevent it. Otherwise, set it to "auto".

`default_nettype none

module RAM_1WnR_Replicated
#(
    parameter                       WORD_WIDTH          = 0,
    parameter                       READ_PORT_COUNT     = 0,
    parameter                       ADDR_WIDTH          = 0,
    parameter                       DEPTH               = 0,
    parameter                       USE_INIT_FILE       = 0,
    parameter                       INIT_FILE           = "",
    parameter   [WORD_WIDTH-1:0]    INIT_VALUE          = 0,
    parameter                       RAMSTYLE            = "",
    // See RAM_Simple_Dual_Port for usage of these parameters
    parameter                       READ_NEW_DATA       = 0,
    parameter                       RW_ADDR_COLLISION   = "",

    // Do not set at instantiation, except in IPI
    parameter TOTAL_READ_DATA  = WORD_WIDTH * READ_PORT_COUNT,
    parameter TOTAL_READ_ADDR  = ADDR_WIDTH * READ_PORT_COUNT
)
(
    input   wire                            clock,

    input   wire    [WORD_WIDTH-1:0]        write_data,
    input   wire    [ADDR_WIDTH-1:0]        write_address,
    input   wire                            write_enable,

    output  wire    [TOTAL_READ_DATA-1:0]   read_data,
    input   wire    [TOTAL_READ_ADDR-1:0]   read_address,
    input   wire    [READ_PORT_COUNT-1:0]   read_enable
);

// There is no logic: it's a number of copies of 1W1R memories with the write
// ports tied together. It's not the most area-efficient method, but it is the
// simplest, fastest, and most flexible when it fits.

    generate
    genvar i;

        for (i=0; i < READ_PORT_COUNT; i=i+1) begin: per_read_port

            RAM_Simple_Dual_Port
            #(
                .WORD_WIDTH         (WORD_WIDTH),
                .ADDR_WIDTH         (ADDR_WIDTH),
                .DEPTH              (DEPTH),
                .RAMSTYLE           (RAMSTYLE),
                .READ_NEW_DATA      (READ_NEW_DATA),
                .RW_ADDR_COLLISION  (RW_ADDR_COLLISION),
                .USE_INIT_FILE      (USE_INIT_FILE),
                .INIT_FILE          (INIT_FILE),
                .INIT_VALUE         (INIT_VALUE)
            )
            Replicated_Storage_Bank
            (
                .clock              (clock),
                .wren               (write_enable),
                .write_addr         (write_address),
                .write_data         (write_data),
                .rden               (read_enable  [i]),
                .read_addr          (read_address [ADDR_WIDTH*i +: ADDR_WIDTH]),
                .read_data          (read_data    [WORD_WIDTH*i +: WORD_WIDTH])
            );

        end

    endgenerate

endmodule

