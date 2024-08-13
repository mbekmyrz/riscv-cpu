module register_file #(parameter [31:0] BASE_ADDR = 32'h01000000) (
    input  wire        clock,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [4:0]  addr_rd,
    input  wire [4:0]  addr_rs1,
    input  wire [4:0]  addr_rs2,
    input  wire [31:0] data_rd,
    output wire [31:0] data_rs1,
    output wire [31:0] data_rs2
);

    //register file module

    reg [31:0] reg_mem[0:31];
    assign data_rs1 = reg_mem[addr_rs1];
    assign data_rs2 = reg_mem[addr_rs2];

    integer i;
    always @(posedge clock) begin
        if (reset) begin
            reg_mem[0] <= 0;                            //zero register
            reg_mem[1] <= 0;
            reg_mem[2] <= BASE_ADDR + `MEM_DEPTH;       //stack pointer
            for (i=3; i<32; i=i+1) begin
                reg_mem[i] <= 0;
            end
        end else begin
            if (write_enable && (addr_rd != 0)) begin   //no writes into x0
                reg_mem[addr_rd] <= data_rd;
            end
        end
    end
    
endmodule