`timescale 1ns / 1ps
//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changess
//====================================================================================
// 10-May-22  DWW  1000  Initial creation
//====================================================================================



module axi4_lite_slave
(
    input clk, resetn,

    //======================  AXI Slave Handler Interface  =====================

    // ASHI signals for handling AXI write requests
    output[31:0]    ASHI_WADDR,
    output[31:0]    ASHI_WDATA,
    output          ASHI_WRITE,
    input           ASHI_WIDLE,
    input[1:0]      ASHI_WRESP,

    // ASHI signals for handling AXI read requests
    output[31:0]    ASHI_RADDR,
    output          ASHI_READ,
    input           ASHI_RIDLE,
    input[31:0]     ASHI_RDATA,
    input[1:0]      ASHI_RRESP,

    //================ From here down is the AXI4-Lite interface ===============
        
    // "Specify write address"              -- Master --    -- Slave --
    input[31:0]                             AXI_AWADDR,   
    input                                   AXI_AWVALID,  
    output reg                                              AXI_AWREADY,
    input[2:0]                              AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input[31:0]                             AXI_WDATA,      
    input                                   AXI_WVALID,
    input[3:0]                              AXI_WSTRB,
    output reg                                              AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             AXI_BRESP,
    output reg                                              AXI_BVALID,
    input                                   AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[31:0]                             AXI_ARADDR,     
    input                                   AXI_ARVALID,
    input[2:0]                              AXI_ARPROT,     
    output reg                                              AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output[31:0]                                            AXI_RDATA,
    output reg                                              AXI_RVALID,
    output[1:0]                                             AXI_RRESP,
    input                                   AXI_RREADY
    //==========================================================================
 );

    // Define the handshakes for all 5 AXI channels
    wire B_HANDSHAKE  = AXI_BVALID  & AXI_BREADY;
    wire R_HANDSHAKE  = AXI_RVALID  & AXI_RREADY;
    wire W_HANDSHAKE  = AXI_WVALID  & AXI_WREADY;
    wire AR_HANDSHAKE = AXI_ARVALID & AXI_ARREADY;
    wire AW_HANDSHAKE = AXI_AWVALID & AXI_AWREADY;

    // The main fields that we pass to the handlerwhen a read or write request comes in
    reg[31:0] ashi_waddr, ashi_wdata, ashi_raddr;

    // Give the handler the write address, the write data, or the read address as soon 
    // as they appear on the bus
    assign ASHI_WADDR = (AW_HANDSHAKE) ? AXI_AWADDR : ashi_waddr;
    assign ASHI_WDATA = (W_HANDSHAKE ) ? AXI_WDATA  : ashi_wdata;
    assign ASHI_RADDR = (AR_HANDSHAKE) ? AXI_ARADDR : ashi_raddr;

    // These are signals to the handler that they should handle a read or a write
    assign ASHI_READ  = AR_HANDSHAKE;
    assign ASHI_WRITE = W_HANDSHAKE;

    // The two response signals are always whatever the handler says they are
    assign AXI_BRESP = ASHI_WRESP;
    assign AXI_RRESP = ASHI_RRESP;

    // Read-data is always whatever the handler says it is
    assign AXI_RDATA = ASHI_RDATA;

    //=========================================================================================================
    // FSM logic for handling AXI read transactions
    //=========================================================================================================
    reg read_state;

    always @(posedge clk) begin
        
        if (resetn == 0) begin
            read_state  <= 0;
            AXI_ARREADY <= 0;
            AXI_RVALID  <= 0;
        end else case(read_state)

        0:  begin
                AXI_ARREADY <= 1;               // Tell the outside world we're ready for an address
                if (AXI_ARVALID) begin          // If the AXI master has given us an address to read...
                    ashi_raddr  <= AXI_ARADDR;  //   Register the address that is being read from
                    AXI_ARREADY <= 0;           //   We are no longer ready to accept an address
                    read_state  <= 1;           //   And go wait for that read-logic to finish
                end
            end
            

        1:  if (ASHI_RIDLE) begin               // If the application-specific read-logic is done...
                AXI_RVALID <= 1;                //   Tell the AXI master that RDATA and RRESP are valid
                if (R_HANDSHAKE) begin          //   Wait for the AXI master to say "OK, I saw your response"
                    AXI_RVALID  <= 0;           //     The AXI master has registered our data
                    AXI_ARREADY <= 1;           //     Once that happens, we're ready to start a new transaction
                    read_state  <= 0;           //     And go wait for a new transaction to arrive
                end
            end

        endcase
    end
    //=========================================================================================================


    //=========================================================================================================
    // FSM logic for handling AXI write transactions
    //=========================================================================================================
    reg write_state;
    always @(posedge clk) begin

        if (resetn == 0) begin
            write_state <= 0;
            AXI_AWREADY <= 0;
            AXI_WREADY  <= 0;
            AXI_BVALID  <= 0;
        end else case(write_state)

        0:  begin
                AXI_AWREADY <= 1;
                AXI_WREADY  <= 1; 
                
                if (AW_HANDSHAKE) begin         // If this is the write-address handshake...
                    ashi_waddr  <= AXI_AWADDR;  //     Latch the address we're writing to
                    AXI_AWREADY <= 0;           //     We are no longer ready to accept a new address
                end

                if (W_HANDSHAKE) begin          // If this is the write-data handshake...
                    ashi_wdata  <= AXI_WDATA;   //     Latch the data we're going to write
                    AXI_WREADY  <= 0;           //     We are no longer ready to accept new data
                    write_state <= 1;           //     And go wait for that write-logic to complete
                end
            end

        1:  if (ASHI_WIDLE) begin               // If the application-specific write-logic is done...
                AXI_BVALID <= 1;                //   Tell the AXI master that BRESP is valid
                if (B_HANDSHAKE) begin          //   Wait for the AXI master to say "OK, I saw your response"
                    AXI_BVALID  <= 0;           //     Once that happens, lower BVALID again
                    AXI_AWREADY <= 1;           //     We're ready to accept another address
                    AXI_WREADY  <= 1;           //     And we're ready to accept new data
                    write_state <= 0;           //     Go wait for a new transaction to arrive
                end
            end

        endcase
    end
    //=========================================================================================================


endmodule
