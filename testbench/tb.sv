`include "cache.svh"
// Testbench for top module
module tb;
  // Clock and reset generation.
  logic clk;
  logic reset_n;

  // CPU interface signals (driven to the DUT).
  logic [`CPU_CORES-1:0]                             cpu_valid;
  logic [`CPU_CORES-1:0]                             cpu_command;    // 0: read, 1: write
  logic [`CPU_CORES-1:0][`ADDR_BITS-`OFFSET_BITS-1:0]  cpu_addr;
  logic [`CPU_CORES-1:0][`CACHELINE_BITS-1:0]         cpu_write_data;
  logic [`CPU_CORES-1:0]                             cpu_ready;
  logic [`CPU_CORES-1:0]                             cpu_read_valid;
  logic [`CPU_CORES-1:0][`CACHELINE_BITS-1:0]         cpu_read_data;

  // Memory interface signals.
  logic                           mem_req_valid;
  logic                           mem_req_rw;       // 0: read, 1: write
  logic [`ADDR_BITS-`OFFSET_BITS-1:0] mem_req_addr;
  logic [`CACHELINE_BITS-1:0]     mem_req_data;
  logic                           mem_req_ready;
  logic                           mem_resp_valid;
  logic [`CACHELINE_BITS-1:0]     mem_resp_data;

  // Instantiate the DUT (top module).
  top dut_top (
    .clk             (clk),
    .reset_n         (reset_n),
    .cpu_valid       (cpu_valid),
    .cpu_command     (cpu_command),
    .cpu_addr        (cpu_addr),
    .cpu_write_data  (cpu_write_data),
    .cpu_ready       (cpu_ready),
    .cpu_read_valid  (cpu_read_valid),
    .cpu_read_data   (cpu_read_data),
    .mem_req_valid   (mem_req_valid),
    .mem_req_rw      (mem_req_rw),
    .mem_req_addr    (mem_req_addr),
    .mem_req_data    (mem_req_data),
    .mem_req_ready   (mem_req_ready),
    .mem_resp_valid  (mem_resp_valid),
    .mem_resp_data   (mem_resp_data)
  );

  // Instantiate the main_memory module.
  main_memory mem_inst (
    .clk             (clk),
    .reset_n         (reset_n),
    .mem_req_valid   (mem_req_valid),
    .mem_req_rw      (mem_req_rw),
    .mem_req_addr    (mem_req_addr),
    .mem_req_data    (mem_req_data),
    .mem_req_ready   (mem_req_ready),
    .mem_resp_valid  (mem_resp_valid),
    .mem_resp_data   (mem_resp_data)
  );

  // Clock generator: 10 ns period.
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset generation.
  initial begin
    reset_n = 0;
    #20;  // Hold reset low for 20 ns.
    reset_n = 1;
  end

  //--------------------------------------------------------------------------
  // Task: do_cpu_read
  // Performs a read transaction on a given CPU.
  // Arguments:
  //   cpu  - the index of the CPU performing the transaction.
  //   addr - the address to read.
  //   data - output value read from the DUT.
  //--------------------------------------------------------------------------
  task automatic do_cpu_read(
    input  int                                       cpu,
    input  logic [(`ADDR_BITS-`OFFSET_BITS-1):0]      addr,
    output logic [(`CACHELINE_BITS-1):0]             data
  );
    begin
      @(posedge clk);
      cpu_valid[cpu]      <= 1'b1;
      cpu_command[cpu]    <= 1'b0; // Read operation.
      cpu_addr[cpu]       <= addr;
      @(posedge clk);
      cpu_valid[cpu]      <= 1'b0;
      // Wait until the DUT asserts the response valid.
      wait (cpu_read_valid[cpu] == 1'b1);
      @(posedge clk); // Capture data on the next clock edge.
      data = cpu_read_data[cpu];
      $display("Time %0t: CPU%0d READ from addr %h, data = %h", $time, cpu, addr, data);
    end
  endtask

  //--------------------------------------------------------------------------
  // Task: do_cpu_write
  // Performs a write transaction on a given CPU.
  // Arguments:
  //   cpu   - the index of the CPU performing the transaction.
  //   addr  - the address to write.
  //   wdata - the data to write.
  //--------------------------------------------------------------------------
  task automatic do_cpu_write(
    input int                                       cpu,
    input logic [(`ADDR_BITS-`OFFSET_BITS-1):0]      addr,
    input logic [(`CACHELINE_BITS-1):0]             wdata
  );
    begin
      @(posedge clk);
      cpu_valid[cpu]      <= 1'b1;
      cpu_command[cpu]    <= 1'b1; // Write operation.
      cpu_addr[cpu]       <= addr;
      cpu_write_data[cpu] <= wdata;
      @(posedge clk);
      cpu_valid[cpu]      <= 1'b0;
      // Wait for the response valid, even for a write.
      wait (cpu_read_valid[cpu] == 1'b1);
      @(posedge clk);
      $display("Time %0t: CPU%0d WRITE to addr %h, data = %h", $time, cpu, addr, wdata);
    end
  endtask

  //--------------------------------------------------------------------------
  // Randomised chained‑CPU read‑write test
  //--------------------------------------------------------------------------
  task automatic run_chained_cpu_test;
    // Random test address (word‑aligned to cache‑line)
    logic [(`ADDR_BITS-`OFFSET_BITS-1):0] test_addr;

    // Per‑CPU random write data
    logic [(`CACHELINE_BITS-1):0] wr_data [`CPU_CORES];

    // Scratch for reads
    logic [(`CACHELINE_BITS-1):0] rd_data;

    // -------------------- Randomisation --------------------
    test_addr = $urandom() & {(`ADDR_BITS-`OFFSET_BITS){1'b1}};
    foreach (wr_data[i])
      wr_data[i] = $urandom() & {`CACHELINE_BITS{1'b1}};

    $display("\n--- Chained-CPU test starting @ %0t ---", $time);
    $display("Test-addr = 0x%0h", test_addr);

    // -------------------- CPU‑0: WRITE -> READ ----
    do_cpu_write(0, test_addr, wr_data[0]);
    do_cpu_read (0, test_addr, rd_data);
    assert (rd_data == wr_data[0])
      else  $error("CPU0 verify read expected %h, got %h",
                  wr_data[0], rd_data);

    // -------------------- Remaining CPUs ------------------
    for (int cpu = 1; cpu < `CPU_CORES; cpu++) begin
      // Each CPU must observe the line written by the previous CPU
      do_cpu_read(cpu, test_addr, rd_data);
      assert (rd_data == wr_data[cpu-1])
        else $error("CPU%0d initial read expected %h, got %h",
                    cpu, wr_data[cpu-1], rd_data);

      // Overwrite with its own data
      do_cpu_write(cpu, test_addr, wr_data[cpu]);
      do_cpu_read (cpu, test_addr, rd_data);
      assert (rd_data == wr_data[cpu])
        else $error("CPU%0d verify read expected %h, got %h",
                    cpu, wr_data[cpu], rd_data);
    end

    // -------------------- Final consistency check ---------
    do_cpu_read(0, test_addr, rd_data);
    assert (rd_data == wr_data[`CPU_CORES-1])
      else  $error("CPU0 final read expected %h, got %h",
                  wr_data[`CPU_CORES-1], rd_data);

    $display("--- Chained-CPU test completed @ %0t ---\n", $time);
  endtask

  //--------------------------------------------------------------------------
  // Task: run_parallel_cpu_test
  // Executes a 4‑core parallel read‑write test:
  //  1) Each core picks its own random address & data, writes it, and reads it back.
  //  2) Then each core "switches" to the next core's address, reads the original data,
  //     writes a new random value there, and reads it back to verify.
  //--------------------------------------------------------------------------
  task automatic run_parallel_cpu_test;
    // Arrays of random test addresses and two sets of per-core data
    logic [(`ADDR_BITS-`OFFSET_BITS-1):0] addrs     [4];
    logic [(`CACHELINE_BITS-1):0]         wr_data1  [4];
    logic [(`CACHELINE_BITS-1):0]         wr_data2  [4];

    // Per-core scratchpads for reads
    logic [(`CACHELINE_BITS-1):0] rd_phase1 [4];
    logic [(`CACHELINE_BITS-1):0] rd_phase3 [4];

    begin
      // --- Unique Randomisation ---
      for (int i = 0; i < 4; i++) begin
        logic [(`ADDR_BITS-`OFFSET_BITS-1):0] candidate;
        logic                                is_unique;
        do begin
          candidate = $urandom() & {(`ADDR_BITS-`OFFSET_BITS){1'b1}};
          is_unique = 1;
          for (int j = 0; j < i; j++) begin
            if (addrs[j] == candidate) begin
              is_unique = 0;
              break;
            end
          end
        end while (!is_unique);

        addrs[i]    = candidate;
        wr_data1[i] = $urandom() & {`CACHELINE_BITS{1'b1}};
        wr_data2[i] = $urandom() & {`CACHELINE_BITS{1'b1}};
      end

      $display("\n--- Parallel-CPU test starting @ %0t ---", $time);
      for (int i = 0; i < 4; i++) begin
        $display(" Core %0d: addr = 0x%0h, init_data = 0x%0h, next_data = 0x%0h",
                i, addrs[i], wr_data1[i], wr_data2[i]);
      end

      // --- Phase 1: Parallel initial write ---
      fork
        do_cpu_write(0, addrs[0], wr_data1[0]);
        do_cpu_write(1, addrs[1], wr_data1[1]);
        do_cpu_write(2, addrs[2], wr_data1[2]);
        do_cpu_write(3, addrs[3], wr_data1[3]);
      join

      // --- Phase 2: Parallel initial read/verify ---
      fork
        do_cpu_read(0, addrs[0], rd_phase1[0]);
        do_cpu_read(1, addrs[1], rd_phase1[1]);
        do_cpu_read(2, addrs[2], rd_phase1[2]);
        do_cpu_read(3, addrs[3], rd_phase1[3]);
      join
      // Verify phase-1 reads
      for (int i = 0; i < 4; i++) begin
        assert (rd_phase1[i] == wr_data1[i])
          else $error("Core%0d Phase1 verify: expected %h, got %h",
                      i, wr_data1[i], rd_phase1[i]);
      end

      // --- Phase 3: Switch to neighbor's line, read old, write new, verify ---
      fork
        // Core 0
        begin
          int i = 0, next = 1;
          do_cpu_read (i, addrs[next], rd_phase3[i]);
          assert (rd_phase3[i] == wr_data1[next])
            else $error("Core0 switch-read: expected %h, got %h",
                        wr_data1[next], rd_phase3[i]);
          do_cpu_write(i, addrs[next], wr_data2[i]);
          do_cpu_read (i, addrs[next], rd_phase3[i]);
          assert (rd_phase3[i] == wr_data2[i])
            else $error("Core0 switch-verify: expected %h, got %h",
                        wr_data2[i], rd_phase3[i]);
        end

        // Core 1
        begin
          int i = 1, next = 2;
          do_cpu_read (i, addrs[next], rd_phase3[i]);
          assert (rd_phase3[i] == wr_data1[next])
            else $error("Core1 switch-read: expected %h, got %h",
                        wr_data1[next], rd_phase3[i]);
          do_cpu_write(i, addrs[next], wr_data2[i]);
          do_cpu_read (i, addrs[next], rd_phase3[i]);
          assert (rd_phase3[i] == wr_data2[i])
            else $error("Core1 switch-verify: expected %h, got %h",
                        wr_data2[i], rd_phase3[i]);
        end

        // Core 2
        begin
          int i = 2, next = 3;
          do_cpu_read (i, addrs[next], rd_phase3[i]);
          assert (rd_phase3[i] == wr_data1[next])
            else $error("Core2 switch-read: expected %h, got %h",
                        wr_data1[next], rd_phase3[i]);
          do_cpu_write(i, addrs[next], wr_data2[i]);
          do_cpu_read (i, addrs[next], rd_phase3[i]);
          assert (rd_phase3[i] == wr_data2[i])
            else $error("Core2 switch-verify: expected %h, got %h",
                        wr_data2[i], rd_phase3[i]);
        end

        // Core 3
        begin
          int i = 3, next = 0;
          do_cpu_read (i, addrs[next], rd_phase3[i]);
          assert (rd_phase3[i] == wr_data1[next])
            else $error("Core3 switch-read: expected %h, got %h",
                        wr_data1[next], rd_phase3[i]);
          do_cpu_write(i, addrs[next], wr_data2[i]);
          do_cpu_read (i, addrs[next], rd_phase3[i]);
          assert (rd_phase3[i] == wr_data2[i])
            else $error("Core3 switch-verify: expected %h, got %h",
                        wr_data2[i], rd_phase3[i]);
        end
      join

      $display("--- Parallel-CPU test completed @ %0t ---\n", $time);
    end
  endtask

  initial begin
    cpu_valid      <= '0;
    cpu_command    <= '0;
    cpu_addr       <= '0;
    cpu_write_data <= '0;

    @(posedge reset_n);

    repeat (10) run_chained_cpu_test();
    repeat (10) run_parallel_cpu_test();

    repeat (10) @(posedge clk);
    $finish;
  end

endmodule : tb
