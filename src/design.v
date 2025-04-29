module bus (
	clk,
	reset_n,
	l1_req_valid,
	l1_req_ready,
	l1_req_addr,
	l1_req,
	l1_req_data,
	l1_resp_valid,
	l1_resp_data,
	l1_resp_shared,
	l1_snoop_valid,
	l1_snoop_addr,
	l1_snoop_req,
	l1_snoop_shared,
	l1_snoop_data,
	l2_req_valid,
	l2_req_ready,
	l2_req_addr,
	l2_req_rw,
	l2_req_data,
	l2_resp_valid,
	l2_resp_data
);
	reg _sv2v_0;
	input wire clk;
	input wire reset_n;
	input wire [3:0] l1_req_valid;
	output reg [3:0] l1_req_ready;
	input wire [23:0] l1_req_addr;
	input wire [7:0] l1_req;
	input wire [3:0] l1_req_data;
	output reg l1_resp_valid;
	output reg [0:0] l1_resp_data;
	output wire l1_resp_shared;
	output reg [3:0] l1_snoop_valid;
	output wire [5:0] l1_snoop_addr;
	output wire [1:0] l1_snoop_req;
	input wire [3:0] l1_snoop_shared;
	input wire [3:0] l1_snoop_data;
	output wire l2_req_valid;
	input wire l2_req_ready;
	output wire [5:0] l2_req_addr;
	output wire l2_req_rw;
	output wire [0:0] l2_req_data;
	input wire l2_resp_valid;
	input wire [0:0] l2_resp_data;
	reg [2:0] cur_state;
	reg [2:0] next_state;
	reg [1:0] req_reg;
	reg [1:0] next_req;
	reg [5:0] addr_reg;
	reg [5:0] next_addr;
	reg [0:0] data_reg;
	reg [0:0] next_data;
	reg [1:0] cpu_reg;
	reg [1:0] next_cpu;
	always @(posedge clk or negedge reset_n)
		if (!reset_n) begin
			cur_state <= 3'd0;
			req_reg <= 2'd0;
			addr_reg <= 1'sb0;
			data_reg <= 1'sb0;
			cpu_reg <= 0;
		end
		else begin
			cur_state <= next_state;
			req_reg <= next_req;
			addr_reg <= next_addr;
			data_reg <= next_data;
			cpu_reg <= next_cpu;
		end
	always @(*) begin : sv2v_autoblock_1
		reg [0:1] _sv2v_jump;
		_sv2v_jump = 2'b00;
		if (_sv2v_0)
			;
		next_state = cur_state;
		next_req = req_reg;
		next_addr = addr_reg;
		next_data = data_reg;
		next_cpu = cpu_reg;
		l1_req_ready = 1'sb0;
		l1_resp_valid = 1'b0;
		l1_resp_data = 1'sb0;
		l1_snoop_valid = 1'sb0;
		case (cur_state)
			3'd0: begin : sv2v_autoblock_2
				reg signed [31:0] i;
				begin : sv2v_autoblock_3
					reg signed [31:0] _sv2v_value_on_break;
					for (i = 0; i < 4; i = i + 1)
						if (_sv2v_jump < 2'b10) begin
							_sv2v_jump = 2'b00;
							if (l1_req_valid[i]) begin
								l1_req_ready[i] = 1'b1;
								next_req = l1_req[i * 2+:2];
								next_addr = l1_req_addr[i * 6+:6];
								next_data = l1_req_data[i+:1];
								next_cpu = i;
								next_state = 3'd1;
								_sv2v_jump = 2'b10;
							end
							_sv2v_value_on_break = i;
						end
					if (!(_sv2v_jump < 2'b10))
						i = _sv2v_value_on_break;
					if (_sv2v_jump != 2'b11)
						_sv2v_jump = 2'b00;
				end
			end
			3'd1: begin
				begin : sv2v_autoblock_4
					reg signed [31:0] i;
					for (i = 0; i < 4; i = i + 1)
						if (i != cpu_reg)
							l1_snoop_valid[i] = 1'b1;
				end
				if (req_reg == 2'd2)
					next_state = 3'd0;
				else if (req_reg == 2'd3)
					next_state = 3'd3;
				else
					next_state = 3'd2;
			end
			3'd2: begin
				next_state = 3'd3;
				begin : sv2v_autoblock_5
					reg signed [31:0] i;
					begin : sv2v_autoblock_6
						reg signed [31:0] _sv2v_value_on_break;
						for (i = 0; i < 4; i = i + 1)
							if (_sv2v_jump < 2'b10) begin
								_sv2v_jump = 2'b00;
								if (l1_snoop_shared[i]) begin
									l1_resp_valid = 1'b1;
									l1_resp_data = l1_snoop_data[i+:1];
									next_state = 3'd0;
									_sv2v_jump = 2'b10;
								end
								_sv2v_value_on_break = i;
							end
						if (!(_sv2v_jump < 2'b10))
							i = _sv2v_value_on_break;
						if (_sv2v_jump != 2'b11)
							_sv2v_jump = 2'b00;
					end
				end
			end
			3'd3:
				if (l2_req_ready) begin
					if (req_reg == 2'd3)
						next_state = 3'd0;
					else
						next_state = 3'd4;
				end
			3'd4:
				if (l2_resp_valid) begin
					next_state = 3'd5;
					next_data = l2_resp_data;
				end
			3'd5: begin
				l1_resp_valid = 1'b1;
				l1_resp_data = data_reg;
				next_state = 3'd0;
			end
			default:
				;
		endcase
	end
	assign l1_resp_shared = |l1_snoop_shared;
	assign l1_snoop_addr = addr_reg;
	assign l1_snoop_req = req_reg;
	assign l2_req_valid = cur_state == 3'd3;
	assign l2_req_addr = addr_reg;
	assign l2_req_rw = req_reg == 2'd3;
	assign l2_req_data = data_reg;
	initial _sv2v_0 = 0;
endmodule
module L1 (
	clk,
	reset_n,
	cpu_valid,
	cpu_command,
	cpu_addr,
	cpu_write_data,
	cpu_ready,
	cpu_read_valid,
	cpu_read_data,
	bus_req_valid,
	bus_req_ready,
	bus_req_addr,
	bus_req,
	bus_req_data,
	bus_resp_valid,
	bus_resp_data,
	bus_resp_shared,
	snoop_valid,
	snoop_addr,
	snoop_req,
	snoop_shared,
	snoop_data
);
	input wire clk;
	input wire reset_n;
	input wire cpu_valid;
	input wire cpu_command;
	input wire [5:0] cpu_addr;
	input wire [0:0] cpu_write_data;
	output wire cpu_ready;
	output wire cpu_read_valid;
	output wire [0:0] cpu_read_data;
	output wire bus_req_valid;
	input wire bus_req_ready;
	output wire [5:0] bus_req_addr;
	output wire [1:0] bus_req;
	output wire [0:0] bus_req_data;
	input wire bus_resp_valid;
	input wire [0:0] bus_resp_data;
	input wire bus_resp_shared;
	input wire snoop_valid;
	input wire [5:0] snoop_addr;
	input wire [1:0] snoop_req;
	output wire snoop_shared;
	output wire [0:0] snoop_data;
	wire [5:0] ctrl_cache_addr;
	wire [7:0] cache_ctrl_line;
	wire [7:0] ctrl_cacheline_update;
	wire ctrl_update_valid;
	wire [5:0] snoop_cache_addr;
	wire [7:0] cache_snoop_line;
	wire [7:0] snoop_cacheline_update;
	wire snoop_update_valid;
	L1cache cache_inst(
		.addr_ctrl(ctrl_cache_addr),
		.addr_snoop(snoop_cache_addr),
		.clk(clk),
		.reset_n(reset_n),
		.cacheline_ctrl_in(ctrl_cacheline_update),
		.ctrl_valid(ctrl_update_valid),
		.cacheline_snoop_in(snoop_cacheline_update),
		.snoop_valid(snoop_update_valid),
		.cacheline_ctrl_out(cache_ctrl_line),
		.cacheline_snoop_out(cache_snoop_line)
	);
	L1controller ctrl_inst(
		.clk(clk),
		.reset_n(reset_n),
		.cpu_valid(cpu_valid),
		.cpu_command(cpu_command),
		.cpu_addr(cpu_addr),
		.cpu_write_data(cpu_write_data),
		.cpu_ready(cpu_ready),
		.cpu_read_valid(cpu_read_valid),
		.cpu_read_data(cpu_read_data),
		.bus_req_valid(bus_req_valid),
		.bus_req_ready(bus_req_ready),
		.bus_req_addr(bus_req_addr),
		.bus_req(bus_req),
		.bus_req_data(bus_req_data),
		.bus_resp_valid(bus_resp_valid),
		.bus_resp_data(bus_resp_data),
		.bus_resp_shared(bus_resp_shared),
		.cache_addr(ctrl_cache_addr),
		.cacheline_lookup(cache_ctrl_line),
		.cacheline_update(ctrl_cacheline_update),
		.update_valid(ctrl_update_valid)
	);
	L1snooper snoop_inst(
		.clk(clk),
		.reset_n(reset_n),
		.valid(snoop_valid),
		.addr(snoop_addr),
		.req(snoop_req),
		.shared(snoop_shared),
		.data(snoop_data),
		.cache_addr(snoop_cache_addr),
		.cacheline_lookup(cache_snoop_line),
		.cacheline_update(snoop_cacheline_update),
		.update_valid(snoop_update_valid)
	);
endmodule
module L1cache (
	addr_ctrl,
	addr_snoop,
	clk,
	reset_n,
	cacheline_ctrl_in,
	ctrl_valid,
	cacheline_snoop_in,
	snoop_valid,
	cacheline_ctrl_out,
	cacheline_snoop_out
);
	reg _sv2v_0;
	input wire [5:0] addr_ctrl;
	input wire [5:0] addr_snoop;
	input wire clk;
	input wire reset_n;
	input wire [7:0] cacheline_ctrl_in;
	input wire ctrl_valid;
	input wire [7:0] cacheline_snoop_in;
	input wire snoop_valid;
	output reg [7:0] cacheline_ctrl_out;
	output reg [7:0] cacheline_snoop_out;
	localparam signed [31:0] NUM_LINES = 4;
	reg [31:0] cache_mem;
	reg [31:0] cache_next;
	always @(posedge clk or negedge reset_n)
		if (!reset_n) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_LINES; i = i + 1)
				begin
					cache_mem[((3 - i) * 8) + 7-:3] <= 3'd0;
					cache_mem[((3 - i) * 8) + 4-:4] <= 1'sb0;
					cache_mem[(3 - i) * 8] <= 1'sb0;
				end
		end
		else
			cache_mem <= cache_next;
	reg [1:0] idx_ctrl;
	reg [1:0] idx_snoop;
	always @(*) begin
		if (_sv2v_0)
			;
		cache_next = cache_mem;
		idx_ctrl = addr_ctrl[1:0];
		idx_snoop = addr_snoop[1:0];
		cacheline_snoop_out = cache_mem[(3 - idx_snoop) * 8+:8];
		if (snoop_valid)
			cache_next[(3 - idx_snoop) * 8+:8] = cacheline_snoop_in;
		cacheline_ctrl_out = cache_next[(3 - idx_ctrl) * 8+:8];
		if (ctrl_valid)
			cache_next[(3 - idx_ctrl) * 8+:8] = cacheline_ctrl_in;
	end
	initial _sv2v_0 = 0;
endmodule
module L1controller (
	clk,
	reset_n,
	cpu_valid,
	cpu_command,
	cpu_addr,
	cpu_write_data,
	cpu_ready,
	cpu_read_valid,
	cpu_read_data,
	bus_req_valid,
	bus_req_ready,
	bus_req_addr,
	bus_req,
	bus_req_data,
	bus_resp_valid,
	bus_resp_data,
	bus_resp_shared,
	cache_addr,
	cacheline_lookup,
	cacheline_update,
	update_valid
);
	reg _sv2v_0;
	input wire clk;
	input wire reset_n;
	input wire cpu_valid;
	input wire cpu_command;
	input wire [5:0] cpu_addr;
	input wire [0:0] cpu_write_data;
	output wire cpu_ready;
	output wire cpu_read_valid;
	output wire [0:0] cpu_read_data;
	output reg bus_req_valid;
	input wire bus_req_ready;
	output reg [5:0] bus_req_addr;
	output reg [1:0] bus_req;
	output wire [0:0] bus_req_data;
	input wire bus_resp_valid;
	input wire [0:0] bus_resp_data;
	input wire bus_resp_shared;
	output wire [5:0] cache_addr;
	input wire [7:0] cacheline_lookup;
	output reg [7:0] cacheline_update;
	output reg update_valid;
	reg [2:0] cur_state;
	reg [2:0] next_state;
	reg command_reg;
	reg next_command;
	reg [5:0] addr_reg;
	reg [5:0] next_addr;
	reg [0:0] data_reg;
	reg [0:0] next_data;
	always @(posedge clk or negedge reset_n)
		if (!reset_n) begin
			cur_state <= 3'd0;
			command_reg <= 1'b0;
			addr_reg <= 1'sb0;
			data_reg <= 1'sb0;
		end
		else begin
			cur_state <= next_state;
			command_reg <= next_command;
			addr_reg <= next_addr;
			data_reg <= next_data;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = cur_state;
		next_command = command_reg;
		next_addr = addr_reg;
		next_data = data_reg;
		bus_req_valid = 0;
		bus_req_addr = 1'sb0;
		bus_req = 2'd0;
		cacheline_update = cacheline_lookup;
		update_valid = 0;
		case (cur_state)
			3'd0:
				if (cpu_valid) begin
					next_command = cpu_command;
					next_addr = cpu_addr;
					next_data = cpu_write_data;
					if ((cacheline_lookup[4-:4] != cpu_addr[5:2]) && (cacheline_lookup[7-:3] != 3'd0))
						next_state = 3'd1;
					else if (((cpu_command == 0) && (cacheline_lookup[7-:3] == 3'd0)) || ((cpu_command == 1) && (((cacheline_lookup[7-:3] == 3'd0) || (cacheline_lookup[7-:3] == 3'd1)) || (cacheline_lookup[7-:3] == 3'd3))))
						next_state = 3'd2;
					else begin
						next_state = 3'd4;
						if (cpu_command == 0)
							next_data = cacheline_lookup[0];
						else begin
							cacheline_update[0] = cpu_write_data;
							cacheline_update[7-:3] = 3'd4;
							update_valid = 1;
						end
					end
				end
			3'd1:
				if (((cacheline_lookup[7-:3] == 3'd0) || (cacheline_lookup[7-:3] == 3'd1)) || (cacheline_lookup[7-:3] == 3'd2)) begin
					next_state = 3'd2;
					cacheline_update[7-:3] = 3'd0;
					update_valid = 1;
				end
				else if ((cacheline_lookup[7-:3] == 3'd3) || (cacheline_lookup[7-:3] == 3'd4)) begin
					bus_req_valid = 1;
					bus_req_addr = {cacheline_lookup[4-:4], addr_reg[1:0]};
					bus_req = 2'd3;
					if (bus_req_ready) begin
						next_state = 3'd2;
						cacheline_update[7-:3] = 3'd0;
						update_valid = 1;
					end
				end
			3'd2: begin
				bus_req_valid = 1;
				bus_req_addr = addr_reg;
				if (cacheline_lookup[7-:3] == 3'd0) begin
					if (command_reg == 0)
						bus_req = 2'd0;
					else
						bus_req = 2'd1;
				end
				else
					bus_req = 2'd2;
				if (bus_req_ready) begin
					if (bus_req == 2'd2) begin
						next_state = 3'd4;
						cacheline_update[7-:3] = 3'd4;
						cacheline_update[0] = data_reg;
						update_valid = 1;
					end
					else
						next_state = 3'd3;
				end
			end
			3'd3:
				if (bus_resp_valid) begin
					next_state = 3'd4;
					next_data = bus_resp_data;
					if (command_reg == 0) begin
						if (bus_resp_shared)
							cacheline_update[7-:3] = 3'd1;
						else
							cacheline_update[7-:3] = 3'd2;
						cacheline_update[0] = bus_resp_data;
						cacheline_update[4-:4] = addr_reg[5:2];
						update_valid = 1;
					end
					else begin
						cacheline_update[0] = data_reg;
						cacheline_update[4-:4] = addr_reg[5:2];
						cacheline_update[7-:3] = 3'd4;
						update_valid = 1;
					end
				end
			3'd4: next_state = 3'd0;
			default: next_state = 3'd0;
		endcase
	end
	assign cpu_ready = cur_state == 3'd0;
	assign cpu_read_valid = cur_state == 3'd4;
	assign cpu_read_data = data_reg;
	assign bus_req_data = cacheline_lookup[0];
	assign cache_addr = (cur_state == 3'd0 ? cpu_addr : addr_reg);
	initial _sv2v_0 = 0;
endmodule
module L1snooper (
	clk,
	reset_n,
	valid,
	addr,
	req,
	shared,
	data,
	cache_addr,
	cacheline_lookup,
	cacheline_update,
	update_valid
);
	reg _sv2v_0;
	input wire clk;
	input wire reset_n;
	input wire valid;
	input wire [5:0] addr;
	input wire [1:0] req;
	output wire shared;
	output reg [0:0] data;
	output wire [5:0] cache_addr;
	input wire [7:0] cacheline_lookup;
	output reg [7:0] cacheline_update;
	output reg update_valid;
	reg cur_state;
	reg next_state;
	reg [0:0] next_data;
	always @(posedge clk or negedge reset_n)
		if (!reset_n) begin
			cur_state <= 1'd0;
			data <= 1'sb0;
		end
		else begin
			cur_state <= next_state;
			data <= next_data;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = cur_state;
		next_data = data;
		cacheline_update = cacheline_lookup;
		update_valid = 0;
		if (cur_state == 1'd0) begin
			if ((valid && (cacheline_lookup[4-:4] == addr[5:2])) && (cacheline_lookup[7-:3] != 3'd0))
				case (req)
					2'd3: next_state = 1'd0;
					2'd2: begin
						cacheline_update[7-:3] = 3'd0;
						update_valid = 1;
						next_state = 1'd0;
					end
					2'd0: begin
						next_data = cacheline_lookup[0];
						next_state = 1'd1;
						if (cacheline_lookup[7-:3] == 3'd2) begin
							cacheline_update[7-:3] = 3'd1;
							update_valid = 1;
						end
						else if (cacheline_lookup[7-:3] == 3'd4) begin
							cacheline_update[7-:3] = 3'd3;
							update_valid = 1;
						end
					end
					2'd1: begin
						cacheline_update[7-:3] = 3'd0;
						update_valid = 1;
						if (cacheline_lookup[7-:3] == 3'd1)
							next_state = 1'd0;
						else begin
							next_data = cacheline_lookup[0];
							next_state = 1'd1;
						end
					end
					default: next_state = 1'd0;
				endcase
			else
				next_state = 1'd0;
		end
		else
			next_state = 1'd0;
	end
	assign cache_addr = addr;
	assign shared = cur_state == 1'd1;
	initial _sv2v_0 = 0;
endmodule
module L2 (
	clk,
	reset_n,
	l2_req_valid,
	l2_req_ready,
	l2_req_addr,
	l2_req_rw,
	l2_req_data,
	l2_resp_valid,
	l2_resp_data,
	mem_req_valid,
	mem_req_rw,
	mem_req_addr,
	mem_req_data,
	mem_req_ready,
	mem_resp_valid,
	mem_resp_data
);
	input wire clk;
	input wire reset_n;
	input wire l2_req_valid;
	output wire l2_req_ready;
	input wire [5:0] l2_req_addr;
	input wire l2_req_rw;
	input wire [0:0] l2_req_data;
	output wire l2_resp_valid;
	output wire [0:0] l2_resp_data;
	output wire mem_req_valid;
	output wire mem_req_rw;
	output wire [5:0] mem_req_addr;
	output wire [0:0] mem_req_data;
	input wire mem_req_ready;
	input wire mem_resp_valid;
	input wire [0:0] mem_resp_data;
	wire [5:0] cache_addr;
	wire [4:0] cacheline_update;
	wire cache_valid;
	wire [4:0] cacheline_lookup;
	L2cache cache_inst(
		.addr(cache_addr),
		.clk(clk),
		.reset_n(reset_n),
		.cacheline_update(cacheline_update),
		.valid(cache_valid),
		.cacheline_lookup(cacheline_lookup)
	);
	L2controller ctrl_inst(
		.clk(clk),
		.reset_n(reset_n),
		.cache_addr(cache_addr),
		.cacheline_update(cacheline_update),
		.cache_valid(cache_valid),
		.cacheline_lookup(cacheline_lookup),
		.l2_req_valid(l2_req_valid),
		.l2_req_ready(l2_req_ready),
		.l2_req_addr(l2_req_addr),
		.l2_req_rw(l2_req_rw),
		.l2_req_data(l2_req_data),
		.l2_resp_valid(l2_resp_valid),
		.l2_resp_data(l2_resp_data),
		.mem_req_valid(mem_req_valid),
		.mem_req_rw(mem_req_rw),
		.mem_req_addr(mem_req_addr),
		.mem_req_data(mem_req_data),
		.mem_req_ready(mem_req_ready),
		.mem_resp_valid(mem_resp_valid),
		.mem_resp_data(mem_resp_data)
	);
endmodule
module L2cache (
	addr,
	clk,
	reset_n,
	cacheline_update,
	valid,
	cacheline_lookup
);
	reg _sv2v_0;
	input wire [5:0] addr;
	input wire clk;
	input wire reset_n;
	input wire [4:0] cacheline_update;
	input wire valid;
	output wire [4:0] cacheline_lookup;
	localparam signed [31:0] NUM_LINES = 16;
	reg [79:0] cache_mem;
	reg [79:0] cache_next;
	always @(posedge clk or negedge reset_n)
		if (!reset_n) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_LINES; i = i + 1)
				begin
					cache_mem[((15 - i) * 5) + 4-:2] <= 2'd0;
					cache_mem[((15 - i) * 5) + 2-:2] <= 1'sb0;
					cache_mem[(15 - i) * 5] <= 1'sb0;
				end
		end
		else
			cache_mem <= cache_next;
	always @(*) begin
		if (_sv2v_0)
			;
		cache_next = cache_mem;
		if (valid)
			cache_next[(15 - addr[3:0]) * 5+:5] = cacheline_update;
	end
	assign cacheline_lookup = cache_mem[(15 - addr[3:0]) * 5+:5];
	initial _sv2v_0 = 0;
endmodule
module L2controller (
	clk,
	reset_n,
	cache_addr,
	cacheline_update,
	cache_valid,
	cacheline_lookup,
	l2_req_valid,
	l2_req_ready,
	l2_req_addr,
	l2_req_rw,
	l2_req_data,
	l2_resp_valid,
	l2_resp_data,
	mem_req_valid,
	mem_req_rw,
	mem_req_addr,
	mem_req_data,
	mem_req_ready,
	mem_resp_valid,
	mem_resp_data
);
	reg _sv2v_0;
	input wire clk;
	input wire reset_n;
	output wire [5:0] cache_addr;
	output reg [4:0] cacheline_update;
	output reg cache_valid;
	input wire [4:0] cacheline_lookup;
	input wire l2_req_valid;
	output wire l2_req_ready;
	input wire [5:0] l2_req_addr;
	input wire l2_req_rw;
	input wire [0:0] l2_req_data;
	output wire l2_resp_valid;
	output wire [0:0] l2_resp_data;
	output wire mem_req_valid;
	output wire mem_req_rw;
	output wire [5:0] mem_req_addr;
	output wire [0:0] mem_req_data;
	input wire mem_req_ready;
	input wire mem_resp_valid;
	input wire [0:0] mem_resp_data;
	reg [2:0] cur_state;
	reg [2:0] next_state;
	reg rw_reg;
	reg next_rw;
	reg [5:0] addr_reg;
	reg [5:0] next_addr;
	reg [0:0] data_reg;
	reg [0:0] next_data;
	always @(posedge clk or negedge reset_n)
		if (!reset_n) begin
			cur_state <= 3'd0;
			rw_reg <= 1'b0;
			addr_reg <= 1'sb0;
			data_reg <= 1'sb0;
		end
		else begin
			cur_state <= next_state;
			rw_reg <= next_rw;
			addr_reg <= next_addr;
			data_reg <= next_data;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = cur_state;
		next_rw = rw_reg;
		next_addr = addr_reg;
		next_data = data_reg;
		cache_valid = 1'b0;
		cacheline_update = cacheline_lookup;
		case (cur_state)
			3'd0:
				if (l2_req_valid) begin : sv2v_autoblock_1
					reg [1:0] req_tag;
					req_tag = l2_req_addr[5-:2];
					if (l2_req_rw && ((cacheline_lookup[2-:2] == req_tag) || (cacheline_lookup[4-:2] != 2'd2))) begin
						next_state = 3'd0;
						cacheline_update[4-:2] = 2'd2;
						cacheline_update[2-:2] = req_tag;
						cacheline_update[0] = l2_req_data;
						cache_valid = 1'b1;
					end
					else if ((!l2_req_rw && ((cacheline_lookup[4-:2] == 2'd1) || (cacheline_lookup[4-:2] == 2'd2))) && (cacheline_lookup[2-:2] == req_tag)) begin
						next_state = 3'd4;
						next_data = cacheline_lookup[0];
					end
					else if ((cacheline_lookup[4-:2] == 2'd2) && (cacheline_lookup[2-:2] != req_tag)) begin
						next_state = 3'd1;
						next_rw = l2_req_rw;
						next_addr = l2_req_addr;
						next_data = l2_req_data;
					end
					else begin
						next_state = 3'd2;
						next_rw = l2_req_rw;
						next_addr = l2_req_addr;
						next_data = l2_req_data;
					end
				end
			3'd1:
				if (mem_req_ready) begin
					if (rw_reg) begin
						next_state = 3'd0;
						cacheline_update[4-:2] = 2'd2;
						cacheline_update[2-:2] = addr_reg[5-:2];
						cacheline_update[0] = data_reg;
						cache_valid = 1'b1;
					end
					else begin
						next_state = 3'd2;
						cacheline_update[4-:2] = 2'd0;
						cache_valid = 1'b1;
					end
				end
			3'd2:
				if (mem_req_ready)
					next_state = 3'd3;
			3'd3:
				if (mem_resp_valid) begin
					next_state = 3'd4;
					cacheline_update[4-:2] = 2'd1;
					cacheline_update[2-:2] = addr_reg[5-:2];
					cacheline_update[0] = mem_resp_data;
					cache_valid = 1'b1;
					next_data = mem_resp_data;
				end
				else
					next_state = 3'd3;
			3'd4: next_state = 3'd0;
			default: next_state = 3'd0;
		endcase
	end
	assign cache_addr = (cur_state == 3'd0 ? l2_req_addr : addr_reg);
	assign l2_req_ready = cur_state == 3'd0;
	assign l2_resp_valid = cur_state == 3'd4;
	assign l2_resp_data = data_reg;
	assign mem_req_valid = (cur_state == 3'd2) || (cur_state == 3'd1);
	assign mem_req_rw = cur_state == 3'd1;
	assign mem_req_addr = (cur_state == 3'd1 ? {cacheline_lookup[2-:2], addr_reg[3:0]} : addr_reg);
	assign mem_req_data = (cur_state == 3'd1 ? cacheline_lookup[0] : data_reg);
	initial _sv2v_0 = 0;
endmodule
module top (
	clk,
	reset_n,
	cpu_valid,
	cpu_command,
	cpu_addr,
	cpu_write_data,
	cpu_ready,
	cpu_read_valid,
	cpu_read_data,
	mem_req_valid,
	mem_req_rw,
	mem_req_addr,
	mem_req_data,
	mem_req_ready,
	mem_resp_valid,
	mem_resp_data
);
	input wire clk;
	input wire reset_n;
	input wire [3:0] cpu_valid;
	input wire [3:0] cpu_command;
	input wire [23:0] cpu_addr;
	input wire [3:0] cpu_write_data;
	output wire [3:0] cpu_ready;
	output wire [3:0] cpu_read_valid;
	output wire [3:0] cpu_read_data;
	output wire mem_req_valid;
	output wire mem_req_rw;
	output wire [5:0] mem_req_addr;
	output wire [0:0] mem_req_data;
	input wire mem_req_ready;
	input wire mem_resp_valid;
	input wire [0:0] mem_resp_data;
	wire [3:0] l1_req_valid;
	wire [3:0] l1_req_ready;
	wire [23:0] l1_req_addr;
	wire [7:0] l1_req;
	wire [3:0] l1_req_data;
	wire l1_resp_valid;
	wire [0:0] l1_resp_data;
	wire l1_resp_shared;
	wire [3:0] l1_snoop_valid;
	wire [5:0] l1_snoop_addr;
	wire [1:0] l1_snoop_req;
	wire [3:0] l1_snoop_shared;
	wire [3:0] l1_snoop_data;
	wire l2_req_valid;
	wire l2_req_ready;
	wire [5:0] l2_req_addr;
	wire l2_req_rw;
	wire [0:0] l2_req_data;
	wire l2_resp_valid;
	wire [0:0] l2_resp_data;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 4; _gv_i_1 = _gv_i_1 + 1) begin : L1_ARRAY
			localparam i = _gv_i_1;
			L1 l1_inst(
				.clk(clk),
				.reset_n(reset_n),
				.cpu_valid(cpu_valid[i]),
				.cpu_command(cpu_command[i]),
				.cpu_addr(cpu_addr[i * 6+:6]),
				.cpu_write_data(cpu_write_data[i+:1]),
				.cpu_ready(cpu_ready[i]),
				.cpu_read_valid(cpu_read_valid[i]),
				.cpu_read_data(cpu_read_data[i+:1]),
				.bus_req_valid(l1_req_valid[i]),
				.bus_req_ready(l1_req_ready[i]),
				.bus_req_addr(l1_req_addr[i * 6+:6]),
				.bus_req(l1_req[i * 2+:2]),
				.bus_req_data(l1_req_data[i+:1]),
				.bus_resp_valid(l1_resp_valid),
				.bus_resp_data(l1_resp_data),
				.bus_resp_shared(l1_resp_shared),
				.snoop_valid(l1_snoop_valid[i]),
				.snoop_addr(l1_snoop_addr),
				.snoop_req(l1_snoop_req),
				.snoop_shared(l1_snoop_shared[i]),
				.snoop_data(l1_snoop_data[i+:1])
			);
		end
	endgenerate
	bus bus_inst(
		.clk(clk),
		.reset_n(reset_n),
		.l1_req_valid(l1_req_valid),
		.l1_req_ready(l1_req_ready),
		.l1_req_addr(l1_req_addr),
		.l1_req(l1_req),
		.l1_req_data(l1_req_data),
		.l1_resp_valid(l1_resp_valid),
		.l1_resp_data(l1_resp_data),
		.l1_resp_shared(l1_resp_shared),
		.l1_snoop_valid(l1_snoop_valid),
		.l1_snoop_addr(l1_snoop_addr),
		.l1_snoop_req(l1_snoop_req),
		.l1_snoop_shared(l1_snoop_shared),
		.l1_snoop_data(l1_snoop_data),
		.l2_req_valid(l2_req_valid),
		.l2_req_ready(l2_req_ready),
		.l2_req_addr(l2_req_addr),
		.l2_req_rw(l2_req_rw),
		.l2_req_data(l2_req_data),
		.l2_resp_valid(l2_resp_valid),
		.l2_resp_data(l2_resp_data)
	);
	L2 l2_inst(
		.clk(clk),
		.reset_n(reset_n),
		.l2_req_valid(l2_req_valid),
		.l2_req_ready(l2_req_ready),
		.l2_req_addr(l2_req_addr),
		.l2_req_rw(l2_req_rw),
		.l2_req_data(l2_req_data),
		.l2_resp_valid(l2_resp_valid),
		.l2_resp_data(l2_resp_data),
		.mem_req_valid(mem_req_valid),
		.mem_req_rw(mem_req_rw),
		.mem_req_addr(mem_req_addr),
		.mem_req_data(mem_req_data),
		.mem_req_ready(mem_req_ready),
		.mem_resp_valid(mem_resp_valid),
		.mem_resp_data(mem_resp_data)
	);
endmodule
module wrapper (
	clk,
	reset_n,
	in_bits,
	out_bits
);
	input wire clk;
	input wire reset_n;
	input wire [11:0] in_bits;
	output wire [11:0] out_bits;
	reg [2:0] phase;
	always @(posedge clk or negedge reset_n)
		if (!reset_n)
			phase <= 3'd0;
		else
			phase <= (phase == 3'd5 ? 3'd0 : phase + 3'd1);
	reg top_clk = ((phase == 3'd4) || (phase == 3'd5)) || (phase == 3'd0);
	reg [35:0] cap;
	always @(posedge clk or negedge reset_n)
		if (!reset_n)
			cap <= 1'sb0;
		else
			case (phase)
				3'd0: cap[11:0] <= in_bits;
				3'd1: cap[23:12] <= in_bits;
				3'd2: cap[35:24] <= in_bits;
				default:
					;
			endcase
	reg [3:0] cpu_valid = cap[11:8];
	reg [3:0] cpu_command = cap[7:4];
	reg [3:0] cpu_wr_data = cap[3:0];
	wire [23:0] cpu_addr;
	assign {cpu_addr[6+:6], cpu_addr[0+:6]} = cap[23:12];
	assign {cpu_addr[18+:6], cpu_addr[12+:6]} = cap[35:24];
	reg mem_req_ready = in_bits[2];
	reg mem_resp_valid = in_bits[1];
	reg mem_resp_data = in_bits[0];
	wire [3:0] cpu_ready;
	wire [3:0] cpu_read_valid;
	wire [3:0] cpu_read_data;
	wire mem_req_valid;
	wire mem_req_rw;
	wire mem_req_data;
	wire [5:0] mem_req_addr;
	wire [23:0] par_out;
	assign par_out = {3'b000, cpu_ready, cpu_read_valid, cpu_read_data, mem_req_valid, mem_req_rw, mem_req_addr, mem_req_data};
	assign out_bits = (phase == 3'd4 ? par_out[11:0] : par_out[23:12]);
	top top_inst(
		.clk(top_clk),
		.reset_n(reset_n),
		.cpu_valid(cpu_valid),
		.cpu_command(cpu_command),
		.cpu_addr(cpu_addr),
		.cpu_write_data(cpu_wr_data),
		.cpu_ready(cpu_ready),
		.cpu_read_valid(cpu_read_valid),
		.cpu_read_data(cpu_read_data),
		.mem_req_valid(mem_req_valid),
		.mem_req_rw(mem_req_rw),
		.mem_req_addr(mem_req_addr),
		.mem_req_data(mem_req_data),
		.mem_req_ready(mem_req_ready),
		.mem_resp_valid(mem_resp_valid),
		.mem_resp_data(mem_resp_data)
	);
endmodule
