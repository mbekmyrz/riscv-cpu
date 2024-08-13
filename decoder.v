module decoder (
    input  wire [31:0] d_insn,
    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7
);

    //decoder module

    parameter [6:2] LUI = 5'b01101;
    assign opcode       = d_insn[6:0];
    assign rd           = d_insn[11:7];
    assign rs1          = (d_insn[6:2] == LUI) ? 0 : d_insn[19:15];     //if LUI insn, rs1 = x0
    assign rs2          = d_insn[24:20];
    assign funct3       = d_insn[14:12];
    assign funct7       = d_insn[31:25];

endmodule
