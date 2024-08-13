module immgen (
    input wire [31:7] insn,
    input wire [2:0]  imm_sel,
    output reg [31:0] imm_val
);

    //immediate generator depending on the insn type

    parameter [2:0]     //insn type
        I = 1,
        S = 2,
        B = 3,
        U = 4,
        J = 5;

    always @(*) begin
        case(imm_sel)
            I:  imm_val = {{21{insn[31]}}, insn[30:20]};
            S:  imm_val = {{21{insn[31]}}, insn[30:25], insn[11:7]};
            B:  imm_val = {{20{insn[31]}}, insn[7], insn[30:25], insn[11:8], 1'b0};
            U:  imm_val = {insn[31], insn[30:12], {12{1'b0}}};
            J:  imm_val = {{12{insn[31]}}, insn[19:12], insn[20], insn[30:21], 1'b0};
            default: imm_val = 0;
        endcase
    end
    
endmodule