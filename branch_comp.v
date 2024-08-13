module branch_comp (
    input  wire signed [31:0] data_a,
    input  wire signed [31:0] data_b,
    input  wire               br_un,
    output wire               br_eq,
    output wire               br_lt
);

    //branch compare unit

    assign br_eq = (data_a == data_b);
    assign br_lt = br_un ? ($unsigned(data_a) < $unsigned(data_b)) : (data_a < data_b);
    
endmodule