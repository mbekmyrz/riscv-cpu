module imemory #(parameter [31:0] BASE_ADDR = 32'h01000000) (
  input  wire        clock,
  input  wire        read_write,
  input  wire [31:0] address,
  input  wire [31:0] data_in,
  output wire [31:0] data_out
);

  //byte addressable memory (for storing instructions)
  //addresses start from BASE_ADDR
  //reads are combinational
  //writes are sequential

  reg [7:0]  mem[BASE_ADDR:BASE_ADDR+`MEM_DEPTH-1];
  reg [31:0] temp[0:`LINE_COUNT-1];

  integer i;
  initial begin
    $readmemh(`MEM_PATH, temp);
    for (i=0; i<`LINE_COUNT; i=i+1) begin
      {mem[BASE_ADDR+4*i+3], mem[BASE_ADDR+4*i+2], mem[BASE_ADDR+4*i+1], mem[BASE_ADDR+4*i]} = temp[i];
    end
  end

  assign data_out = {mem[address+3], mem[address+2], mem[address+1], mem[address]};
  always @(posedge clock) begin
    if (read_write)
      {mem[address+3], mem[address+2], mem[address+1], mem[address]} <= data_in;
  end

endmodule
