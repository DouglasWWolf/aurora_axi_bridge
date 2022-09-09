`timescale 1ns / 1ps

//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//               This RTL core is a fully-functional AXI4-Master
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 10-May-22  DWW  1000  Initial creation
//
// 17-Aug-22  DWW  1001  Partial rewrite to support narrow reads and writes
//====================================================================================


module axi4_noburst_master#
(
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ADDR_WIDTH = 32
)
(

    input wire clk, resetn,


    //==================  The AXI Master Control Interface  ====================

    // AMCI signals for performing AXI writes
    input[AXI_ADDR_WIDTH-1:0]      AMCI_WADDR,
    input[AXI_DATA_WIDTH-1:0]      AMCI_WDATA,
    input[2:0]                     AMCI_WSIZE,
    input                          AMCI_WRITE,
    output reg[1:0]                AMCI_WRESP,
    output                         AMCI_WIDLE,
    
    // AMCI signals for performing AXI reads
    input[AXI_ADDR_WIDTH-1:0]      AMCI_RADDR,
    input[2:0]                     AMCI_RSIZE,
    input                          AMCI_READ,
    output reg[AXI_DATA_WIDTH-1:0] AMCI_RDATA,
    output reg[1:0]                AMCI_RRESP,
    output                         AMCI_RIDLE,

    //==========================================================================


    //======================  An AXI Master Interface  =========================

    // "Specify write address"          -- Master --    -- Slave --
    output reg [AXI_ADDR_WIDTH-1:0]     AXI_AWADDR,   
    output reg                          AXI_AWVALID,  
    output     [2:0]                    AXI_AWPROT,
    output     [3:0]                    AXI_AWID,
    output     [7:0]                    AXI_AWLEN,
    output reg [2:0]                    AXI_AWSIZE,
    output     [1:0]                    AXI_AWBURST,
    output                              AXI_AWLOCK,
    output     [3:0]                    AXI_AWCACHE,
    output     [3:0]                    AXI_AWQOS,
    input                                               AXI_AWREADY,


    // "Write Data"                     -- Master --    -- Slave --
    output reg [AXI_DATA_WIDTH-1:0]     AXI_WDATA,      
    output reg                          AXI_WVALID,
    output reg [(AXI_DATA_WIDTH/8)-1:0] AXI_WSTRB,
    output                              AXI_WLAST,
    input                                               AXI_WREADY,


    // "Send Write Response"            -- Master --    -- Slave --
    input      [1:0]                                    AXI_BRESP,
    input                                               AXI_BVALID,
    output reg                          AXI_BREADY,

    // "Specify read address"           -- Master --    -- Slave --
    output reg [AXI_ADDR_WIDTH-1:0]     AXI_ARADDR,     
    output reg                          AXI_ARVALID,
    output     [2:0]                    AXI_ARPROT,     
    output                              AXI_ARLOCK,
    output     [3:0]                    AXI_ARID,
    output     [7:0]                    AXI_ARLEN,
    output reg [2:0]                    AXI_ARSIZE,
    output     [1:0]                    AXI_ARBURST,
    output     [3:0]                    AXI_ARCACHE,
    output     [3:0]                    AXI_ARQOS,
    input                                               AXI_ARREADY,

    // "Read data back to master"       -- Master --    -- Slave --
    input [AXI_DATA_WIDTH-1:0]                          AXI_RDATA,
    input                                               AXI_RVALID,
    input [1:0]                                         AXI_RRESP,
    input                                               AXI_RLAST,
    output reg                          AXI_RREADY
    //==========================================================================

);
    localparam AXI_SIZE_WIDTH        = 3;
    localparam AXI_RESP_WIDTH        = 2;
    localparam AXI_DATA_BYTES        = (AXI_DATA_WIDTH/8);
    localparam AXI_STRB_WIDTH        = AXI_DATA_BYTES;
    localparam[AXI_STRB_WIDTH:0] ONE = 1;

    // Assign all of the "write transaction" signals that are constant
    assign AXI_AWID    = 1;   // Arbitrary ID
    assign AXI_AWLEN   = 0;   // Burst length of 1
    assign AXI_AWBURST = 1;   // Each beat of the burst increments by 1 address (ignored)
    assign AXI_AWLOCK  = 0;   // Normal signaling
    assign AXI_AWCACHE = 2;   // Normal, no cache, no buffer
    assign AXI_AWQOS   = 0;   // Lowest quality of service, unused
    assign AXI_AWPROT  = 0;   // Normal
    assign AXI_WLAST   = 1;   // Each beat is always the last beat of the burst

    // Assign all of the "read transaction" signals that are constant
    assign AXI_ARLOCK  = 0;   // Normal signaling
    assign AXI_ARID    = 1;   // Arbitrary ID
    assign AXI_ARLEN   = 0;   // Burst length of 1
    assign AXI_ARBURST = 1;   // Increment address on each beat of the burst (unused)
    assign AXI_ARCACHE = 2;   // Normal, no cache, no buffer
    assign AXI_ARQOS   = 0;   // Lowest quality of service (unused)
    assign AXI_ARPROT  = 0;   // Normal

 
    // Define the handshakes for all 5 AXI channels
    wire B_HANDSHAKE  = AXI_BVALID  & AXI_BREADY;
    wire R_HANDSHAKE  = AXI_RVALID  & AXI_RREADY;
    wire W_HANDSHAKE  = AXI_WVALID  & AXI_WREADY;
    wire AR_HANDSHAKE = AXI_ARVALID & AXI_ARREADY;
    wire AW_HANDSHAKE = AXI_AWVALID & AXI_AWREADY;

    // This mask, anded with an address, will give the byte-offset-from-aligned of that address
    wire[15:0] ADDR_OFFSET_MASK = (1 << $clog2(AXI_DATA_BYTES)) - 1;

    // These are the state variables for the read and write state machines
    reg[1:0] write_state, read_state;

    // The "state machine is idle" signals for the two AMCI interfaces
    assign AMCI_WIDLE = (AMCI_WRITE == 0) && (write_state == 0);
    assign AMCI_RIDLE = (AMCI_READ  == 0) && ( read_state == 0);

    //=========================================================================================================
    // FSM logic used for writing to the slave device.
    //
    //  To start:   AMCI_WADDR = Address to write to
    //              AMCI_WDATA = Data to write 
    //              AMCI_WSIZE = Log2 of the data-width in bytes
    //              AMCI_WRITE = Pulsed high for one cycle
    //
    //  At end:     Write is complete when "AMCI_WIDLE" goes high
    //              AMCI_WRESP = AXI_BRESP "write response" signal from slave
    //=========================================================================================================
    // This is the offset (in bytes) of AMCI_WADDR from being a fully aligned address
    wire[AXI_ADDR_WIDTH-1:0] waddr_offset = AMCI_WADDR & ADDR_OFFSET_MASK;
    //=========================================================================================================
     
    always @(posedge clk) begin

        // If we're in RESET mode...
        if (resetn == 0) begin
            write_state <= 0;
            AXI_AWVALID <= 0;
            AXI_WVALID  <= 0;
            AXI_BREADY  <= 0;
        end        
        
        // Otherwise, we're not in RESET and our state machine is running
        else case (write_state)
            
            // Here we're idle, waiting for someone to raise the 'AMCI_WRITE' flag.  Once that happens,
            // we'll place the user specified address and data onto the AXI bus, along with the flags that
            // indicate that the address and data values are valid
            0:  if (AMCI_WRITE) begin
                    AXI_AWADDR <= AMCI_WADDR;  // Place our address onto the bus
                    AXI_AWSIZE <= AMCI_WSIZE;  // Place the data-width onto the bus
    
                    // Assume for a moment that we have a full-width data
                    AXI_WSTRB <= -1;
                    AXI_WDATA <= AMCI_WDATA;

                    // If we <don't> have a full width data:
                    //    shift WSTRB up by "waddr_offset" bits
                    //    shift WDATA up by "waddr_offset" bytes
                    if (AMCI_WSIZE != $clog2(AXI_DATA_BYTES))  begin
                        AXI_WSTRB <= (( ONE << (1 << AMCI_WSIZE))-1) << waddr_offset;
                        AXI_WDATA <= AMCI_WDATA << (waddr_offset << 3);
                    end

                    AXI_AWVALID <= 1;     // Indicate that the address is valid
                    AXI_WVALID  <= 1;     // Indicate that the data is valid
                    AXI_BREADY  <= 1;     // Indicate that we're ready for the slave to respond
                    write_state <= 1;     // On the next clock cycle, we'll be in the next state
                end
                
           // Here, we're waiting around for the slave to acknowledge our request by asserting AXI_AWREADY
           // and AXI_WREADY.  Once that happens, we'll de-assert the "valid" lines.  Keep in mind that we
           // don't know what order AWREADY and WREADY will come in, and they could both come at the same
           // time.      
           1:   begin   
                    // Keep track of whether we have seen the slave raise AWREADY or WREADY
                    if (AW_HANDSHAKE) AXI_AWVALID <= 0;
                    if (W_HANDSHAKE ) AXI_WVALID  <= 0;

                    // If we've seen AWREADY (or if its raised now) and if we've seen WREADY (or if it's raised now)...
                    if ((~AXI_AWVALID || AW_HANDSHAKE) && (~AXI_WVALID || W_HANDSHAKE)) begin
                        write_state <= 2;
                    end
                end
                
           // Wait around for the slave to assert "AXI_BVALID".  
           2:   if (B_HANDSHAKE) begin
                    AMCI_WRESP  <= AXI_BRESP;
                    AXI_BREADY  <= 0;
                    write_state <= 0;
                end

        endcase
    end
    //=========================================================================================================





    //=========================================================================================================
    // FSM logic used for reading from a slave device.
    //
    //  To start: AMCI_RADDR = Address to read from
    //            AMCI_RSIZE = Log2 of the data-width in bytes
    //            AMCI_READ  = Pulsed high for one cycle
    //
    //  At end:   Read is complete when "AMCI_RIDLE" goes high.
    //            AMCI_RDATA = The data that was read
    //            AMCI_RRESP = The AXI "read response" that is used to indicate success or failure
    //=========================================================================================================
    // This is the offset (in bytes) of AXI_ARADDR from being a fully aligned address
    reg[AXI_ADDR_WIDTH-1:0] raddr_offset;
    //=========================================================================================================
    always @(posedge clk) begin
         
        if (resetn == 0) begin
            read_state  <= 0;
            AXI_ARVALID <= 0;
            AXI_RREADY  <= 0;
        end else case (read_state)

            // Here we are waiting around for someone to raise "AMCI_READ", which signals us to begin
            // a AXI read at the address specified in "AMCI_RADDR"
            0:  if (AMCI_READ) begin
                    raddr_offset <= AMCI_RADDR & ADDR_OFFSET_MASK;
                    AXI_ARADDR   <= AMCI_RADDR; 
                    AXI_ARSIZE   <= AMCI_RSIZE;
                    AXI_ARVALID  <= 1;
                    AXI_RREADY   <= 1;
                    read_state   <= 1;
                end else begin
                    AXI_ARVALID  <= 0;
                    AXI_RREADY   <= 0;
                    read_state   <= 0;
                end
            
            // Wait around for the slave to raise AXI_RVALID, which tells us that AXI_RDATA
            // contains the data we requested
            1:  begin
                    if (AR_HANDSHAKE) begin
                        AXI_ARVALID <= 0;
                    end

                    // If the slave has provided us the data we asked for...
                    if (R_HANDSHAKE) begin
                        
                        // Right justify that data into AMCI_RDATA 
                        AMCI_RDATA <= AXI_RDATA >> (raddr_offset << 3);
                        
                        // Save the read-response so our user can get it
                        AMCI_RRESP <= AXI_RRESP;
                        
                        // Lower the ready signal to make it obvious that we're done
                        AXI_RREADY <= 0;

                        // And go back to idle state
                        read_state <= 0;
                    end
                end

        endcase
    end
    //=========================================================================================================



endmodule
