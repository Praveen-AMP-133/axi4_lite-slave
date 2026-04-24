//`timescale 1ns/1ps
module tb_axi4_lite_slave;

    //========================================================
    // CLOCK & RESET
    //========================================================
    reg ACLK;
    reg ARESETn;

    // WRITE ADDRESS CHANNEL
    reg  [3:0] AWADDR;
    reg        AWVALID;
    wire       AWREADY;

    // WRITE DATA CHANNEL
    reg  [31:0] WDATA;
    reg  [3:0]  WSTRB;
    reg         WVALID;
    wire        WREADY;

    // WRITE RESPONSE CHANNEL
    wire [1:0] BRESP;
    wire       BVALID;
    reg        BREADY;

    // READ ADDRESS CHANNEL
    reg  [3:0] ARADDR;
    reg        ARVALID;
    wire       ARREADY;

    // READ DATA CHANNEL
    wire [31:0] RDATA;
    wire [1:0]  RRESP;
    wire        RVALID;
    reg         RREADY;

    //--------------------------------------------------------
    // DUT
    //--------------------------------------------------------
    axi4_lite_slave dut (.*);

    //--------------------------------------------------------
    // CLOCK
    //--------------------------------------------------------
    always #5 ACLK = ~ACLK;

    //--------------------------------------------------------
    // RESET
    //--------------------------------------------------------
    task reset_dut;
    begin
        ACLK = 0;
        ARESETn = 0;

        AWVALID = 0; WVALID = 0; BREADY = 0;
        ARVALID = 0; RREADY = 0;

        repeat (5) @(posedge ACLK);
        ARESETn = 1;
        repeat (2) @(posedge ACLK);
    end
    endtask

    //--------------------------------------------------------
    // UNIFIED WRITE TASK
    //--------------------------------------------------------
    task axi_write_full(
        input [3:0] addr,
        input [31:0] data,
        input integer mode,        // 0: AW->W, 1: W->AW, 2: parallel
        input integer delay_aw,
        input integer delay_w,
        input integer delay_bready
    );
    begin
        $display("\n[WRITE] ADDR=%h DATA=%h MODE=%0d", addr, data, mode);

        fork
            //------------------------------------------------
            // ADDRESS CHANNEL
            //------------------------------------------------
            begin
                #(delay_aw);
                if (mode != 1) begin
                    @(posedge ACLK);
                    AWADDR  <= addr;
                    AWVALID <= 1;
                    wait (AWREADY);
                    @(posedge ACLK);
                    AWVALID <= 0;
                end
            end

            //------------------------------------------------
            // DATA CHANNEL
            //------------------------------------------------
            begin
                #(delay_w);
                if (mode != 0) begin
                    @(posedge ACLK);
                    WDATA  <= data;
                    WSTRB  <= 4'hF;
                    WVALID <= 1;
                    wait (WREADY);
                    @(posedge ACLK);
                    WVALID <= 0;
                end
            end
        join

        // Handle missing phase (for strict ordering modes)
        if (mode == 0) begin
            @(posedge ACLK);
            WDATA  <= data;
            WSTRB  <= 4'hF;
            WVALID <= 1;
            wait (WREADY);
            @(posedge ACLK);
            WVALID <= 0;
        end

        if (mode == 1) begin
            @(posedge ACLK);
            AWADDR  <= addr;
            AWVALID <= 1;
            wait (AWREADY);
            @(posedge ACLK);
            AWVALID <= 0;
        end

        //------------------------------------------------
        // RESPONSE (with backpressure)
        //------------------------------------------------
        #(delay_bready);
        @(posedge ACLK);
        BREADY <= 1;

        wait (BVALID);
        $display("[WRITE RESP] BRESP=%0d TIME=%0t", BRESP, $time);

        @(posedge ACLK);
        BREADY <= 0;
    end
    endtask

    //--------------------------------------------------------
    // UNIFIED READ TASK
    //--------------------------------------------------------
    task axi_read_full(
        input [3:0] addr,
        input integer delay_rready
    );
    begin
        $display("\n[READ] ADDR=%h", addr);

        @(posedge ACLK);
        ARADDR  <= addr;
        ARVALID <= 1;

        wait (ARREADY);
        @(posedge ACLK);
        ARVALID <= 0;

        #(delay_rready);
        @(posedge ACLK);
        RREADY <= 1;

        wait (RVALID);
        $display("[READ DATA] ADDR=%h DATA=%h TIME=%0t", addr, RDATA, $time);

        @(posedge ACLK);
        RREADY <= 0;
    end
    endtask

    //--------------------------------------------------------
    // EDGE CASE: VALID HOLD
    //--------------------------------------------------------
    task valid_hold_test;
    reg aw_done_local;
    reg w_done_local;
    begin
    $display("\n[EDGE] VALID HOLD TEST");

    aw_done_local = 0;
    w_done_local  = 0;

    @(posedge ACLK);
    AWADDR  <= 4'h0;
    AWVALID <= 1;
    WDATA   <= 32'hDEADBEEF;
    WVALID  <= 1;
    WSTRB   <= 4'hF;

    // Hold VALID and monitor handshake properly
    while (!(aw_done_local && w_done_local)) begin
        @(posedge ACLK);

        if (AWVALID && AWREADY)
            aw_done_local = 1;

        if (WVALID && WREADY)
            w_done_local = 1;
    end

    // Deassert VALID AFTER handshake
    @(posedge ACLK);
    AWVALID <= 0;
    WVALID  <= 0;

    // Response
    BREADY <= 1;
    wait (BVALID);
    @(posedge ACLK);
    BREADY <= 0;

    $display("[EDGE DONE]");
    end
    endtask

    //--------------------------------------------------------
    // RANDOM STRESS TEST (ADD THIS)
    //--------------------------------------------------------
    task random_stress;
        integer i;
        begin
        $display("\n[RANDOM STRESS TEST]");

        for (i = 0; i < 10; i = i + 1) begin

            // Random write
            axi_write_full(
                $urandom % 16,   // random address
                $urandom,        // random data
                $urandom % 3,    // mode (0/1/2)
                $urandom % 20,   // delay_aw
                $urandom % 20,   // delay_w
                $urandom % 20    // delay_bready
            );

            // Random read
            axi_read_full(
                $urandom % 16,
                $urandom % 20
            );
        end

        $display("[RANDOM STRESS DONE]");
        end
    endtask

    //--------------------------------------------------------
    // MAIN TEST
    //--------------------------------------------------------
    initial begin
        reset_dut();

        //----------------------------------------------------
        // BASIC
        //----------------------------------------------------
        axi_write_full(4'h0, 32'hAAAA1111, 2, 0, 0, 0);
        axi_read_full (4'h0, 0);

        //----------------------------------------------------
        // PROTOCOL CASES
        //----------------------------------------------------
        axi_write_full(4'h4, 32'hBBBB2222, 0, 0, 20, 0); // AW first
        axi_write_full(4'h8, 32'hCCCC3333, 1, 20, 0, 0); // W first
        axi_write_full(4'hC, 32'hDDDD4444, 2, 0, 0, 0);  // parallel

        //----------------------------------------------------
        // BACKPRESSURE
        //----------------------------------------------------
        axi_write_full(4'h0, 32'h11112222, 2, 0, 0, 30);
        axi_read_full (4'h0, 30);

        //----------------------------------------------------
        // EDGE CASES
        //----------------------------------------------------
        valid_hold_test();

        //----------------------------------------------------
        // RANDOM STRESS
        //----------------------------------------------------
        random_stress();

        //----------------------------------------------------
        // DONE
        //----------------------------------------------------
        #200;
        $display("\n ALL TESTS COMPLETED ");
        $finish;
    end
    initial begin
      $dumpfile("axi4-lite-slave.vcd");
      $dumpvars();
    end

endmodule
