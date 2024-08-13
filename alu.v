module alu (
    input wire        [3:0]  alu_sel,
    input wire signed [31:0] data_a,
    input wire signed [31:0] data_b,
    output reg signed [31:0] alu_res
);

    //ALU module

    always @(*) begin
        case (alu_sel[2:0])
            3'b000:     alu_res = alu_sel[3] ? (data_a - data_b) : (data_a + data_b);               //SUB:ADD
            3'b001:     alu_res = data_a << data_b[4:0];                                            //SLL
            3'b010:     alu_res = (data_a < data_b) ? 1:0;                                          //SLT
            3'b011:     alu_res = $unsigned(data_a) < $unsigned(data_b) ? 1:0;                      //SLTU
            3'b100:     alu_res = data_a ^ data_b;                                                  //XOR
            3'b101:     alu_res = alu_sel[3] ? (data_a >>> data_b[4:0]) : (data_a >> data_b[4:0]);  //SRA:SRL
            3'b110:     alu_res = data_a | data_b;                                                  //OR
            3'b111:     alu_res = data_a & data_b;                                                  //AND
            default:    alu_res = 0;
        endcase
    end

endmodule