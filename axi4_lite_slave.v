module axi4_lite_slave #(
    parameter ADDR_WIDTH = 4,   // Address width (byte addressable)
    parameter DATA_WIDTH = 32   // Data width
)(
    input                       ACLK,      // Global clock
    input                       ARESETn,   // Active LOW reset

    //================ WRITE ADDRESS CHANNEL =================//
    input  [ADDR_WIDTH-1:0]     AWADDR,    // Write address from master
    input                       AWVALID,   // Master asserts when address is valid
    output reg                  AWREADY,   // Slave asserts when ready to accept address

    //================ WRITE DATA CHANNEL ====================//
    input  [DATA_WIDTH-1:0]     WDATA,     // Write data
    input  [(DATA_WIDTH/8)-1:0] WSTRB,     // Byte enables (1 bit per byte)
    input                       WVALID,    // Master asserts when data is valid
    output reg                  WREADY,    // Slave ready to accept data

    //================ WRITE RESPONSE CHANNEL ================//
    output reg [1:0]            BRESP,     // Write response: 00=OKAY
    output reg                  BVALID,    // Response valid
    input                       BREADY,    // Master ready to accept response

    //================ READ ADDRESS CHANNEL ==================//
    input  [ADDR_WIDTH-1:0]     ARADDR,    // Read address
    input                       ARVALID,   // Address valid
    output reg                  ARREADY,   // Slave ready

    //================ READ DATA CHANNEL =====================//
    output reg [DATA_WIDTH-1:0] RDATA,     // Read data
    output reg [1:0]            RRESP,     // Read response
    output reg                  RVALID,    // Data valid
    input                       RREADY     // Master ready
);

    //========================================================
    // INTERNAL REGISTERS (Memory mapped registers)
    //========================================================
    reg [DATA_WIDTH-1:0] regfile [0:3]; // 4 registers

    //========================================================
    // INTERNAL HANDSHAKE FLAGS
    //========================================================
    reg aw_done;   // Indicates address has been accepted
    reg w_done;    // Indicates data has been accepted

    reg [ADDR_WIDTH-1:0] awaddr_reg; // Latched write address

    //========================================================
    // WRITE CHANNEL LOGIC
    //========================================================
  	always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            AWREADY   <= 0;
            WREADY    <= 0;
            BVALID    <= 0;
            BRESP     <= 2'b00;

            aw_done   <= 0;
            w_done    <= 0;
        end
        else begin
            //------------------------------------------------
            // WRITE ADDRESS HANDSHAKE
            //------------------------------------------------
            // Accept address only if not already accepted
            if (!AWREADY && AWVALID && !aw_done) begin
                AWREADY    <= 1;               // Accept address
                awaddr_reg <= AWADDR;          // Latch address
                aw_done    <= 1;               // Mark address received
            end
            else begin
                AWREADY <= 0; // Pulse style READY
            end

            //------------------------------------------------
            // WRITE DATA HANDSHAKE
            //------------------------------------------------
            if (!WREADY && WVALID && !w_done) begin
                WREADY <= 1;   // Accept data
                w_done <= 1;   // Mark data received
            end
            else begin
                WREADY <= 0;
            end

            //------------------------------------------------
            // WRITE OPERATION (only when BOTH received)
            //------------------------------------------------
            if (aw_done && w_done && !BVALID) begin
                // Address decode (word aligned: use upper bits)
                // Example: 4 registers -> use bits [3:2]
                case (awaddr_reg[3:2])
                    2'b00: regfile[0] <= WDATA;
                    2'b01: regfile[1] <= WDATA;
                    2'b10: regfile[2] <= WDATA;
                    2'b11: regfile[3] <= WDATA;
                endcase

                BVALID <= 1;       // Send response
                BRESP  <= 2'b00;   // OKAY response
            end

            //------------------------------------------------
            // WRITE RESPONSE HANDSHAKE COMPLETE
            //------------------------------------------------
            if (BVALID && BREADY) begin
                BVALID  <= 0;      // Clear response
                aw_done <= 0;      // Ready for next transaction
                w_done  <= 0;
            end
        end
    end

    //========================================================
    // READ CHANNEL LOGIC
    //========================================================
    reg [ADDR_WIDTH-1:0] araddr_reg;

  	always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            ARREADY <= 0;
            RVALID  <= 0;
            RRESP   <= 2'b00;
        end
        else begin
            //------------------------------------------------
            // READ ADDRESS HANDSHAKE
            //------------------------------------------------
            if (!ARREADY && ARVALID && !RVALID) begin
                ARREADY    <= 1;          // Accept address
                araddr_reg <= ARADDR;    // Latch address
            end
            else begin
                ARREADY <= 0;
            end

            //------------------------------------------------
            // READ DATA GENERATION
            //------------------------------------------------
            if (ARVALID && ARREADY) begin
                case (ARADDR[3:2])
                    2'b00: RDATA <= regfile[0];
                    2'b01: RDATA <= regfile[1];
                    2'b10: RDATA <= regfile[2];
                    2'b11: RDATA <= regfile[3];
                endcase

                RVALID <= 1;      // Data valid
                RRESP  <= 2'b00;  // OKAY
            end

            //------------------------------------------------
            // READ HANDSHAKE COMPLETE
            //------------------------------------------------
            if (RVALID && RREADY) begin
                RVALID <= 0;      // Clear after transfer
            end
        end
    end

endmodule
