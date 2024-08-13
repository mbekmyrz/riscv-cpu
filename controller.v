module controller (
    input  wire [31:0] d_insn,      //insn from DEC stage
    input  wire [31:0] e_insn,      //insn from EXE stage
    input  wire [31:0] m_insn,      //insn from MEM stage
    input  wire [31:0] w_insn,      //insn from WB  stage
    input  wire        br_eq,       //branch equal control signal from bcomp unit
    input  wire        br_lt,       //branch less than control signal from bcomp unit
    output wire        pc_sel,      //jumps taken from EXE
    output wire        pc_jumpsel,  //jumps taken from DEC
    output wire        reg_wen,     //write enable for register file (by WB stage insn)
    output reg  [2:0]  imm_sel,     //immediate type select for IGEN
    output wire [1:0]  rs1_sel,     //rs1 bypass mux select in EXE
    output wire [1:0]  rs2_sel,     //rs2 bypass mux select in EXE
    output wire        a_sel,       //ALU A input mux select
    output wire        b_sel,       //ALU B input mux select
    output wire        br_un,       //branch unsigned control signal send to bcomp unit
    output wire [3:0]  alu_sel,     //ALU operation select
    output wire        mem_rw,      //write enable for dmem
    output wire        dataw_sel,   //bypass mux select in MEM
    output wire [1:0]  acc_size,    //access size for dmem
    output wire [1:0]  wb_sel,      //mux select for MEM stage output
    output wire        stall        //control signal for stall
);

    //controller unit
    //generates all the necessary control signals for each stage
    //by looking at their corresponding insn bits

    parameter [6:2]             //opcode types (upper 5 bits)
        R       = 5'b01100,
        I       = 5'b00100,
        JALR    = 5'b11001,
        LOAD    = 5'b00000,
        S       = 5'b01000,
        B       = 5'b11000,
        LUI     = 5'b01101,
        AUI     = 5'b00101,
        J       = 5'b11011;

    //DEC signals:
    wire [6:2] d_op;
    wire [4:0] d_rs1;
    wire [4:0] d_rs2;
    wire       d_rr1;         //rs1 in DEC is register addr, not immediate bits
    wire       d_rr2;         //rs2

    //EXE signals:
    wire [6:2] e_op;  
    wire [2:0] e_fun3;
    wire       e_fun7;
    wire [4:0] e_rs1;
    wire [4:0] e_rs2;
    wire [4:0] e_rd;
    wire       e_rr1;         //rs1 in EXE is register addr, not immediate bits
    wire       e_rr2;         //rs2

    //MEM signals:
    wire [6:2] m_op;
    wire [2:0] m_fun3;
    wire [4:0] m_rs2;
    wire [4:0] m_rd;
    wire       m_reg_wen;     //rd  in MEM is register addr, i.e. reg_write is enabled

    //WB signals:
    wire [6:2] w_op;
    wire [4:0] w_rd;
    
    //DEC
    always @(*) begin
        case(d_op)
            R:          imm_sel = 0;      //R-type
            I:          imm_sel = 1;      //I-type
            JALR:       imm_sel = 1;      //I-type
            LOAD:       imm_sel = 1;      //I-type
            S:          imm_sel = 2;      //S-type
            B:          imm_sel = 3;      //B-type
            LUI:        imm_sel = 4;      //U-type
            AUI:        imm_sel = 4;      //U-type
            J:          imm_sel = 5;      //J-type
            default:    imm_sel = 0;
        endcase
    end

    assign d_op       = d_insn[6:2];    //decoding of the registered insn bits for readability
    assign d_rs1      = d_insn[19:15];
    assign d_rs2      = d_insn[24:20];
    assign pc_jumpsel = (d_op == J);    //take jump if insn is JAL
    assign d_rr1      = (d_rs1 != 0) & (d_op != LUI) & (d_op != AUI) & (d_op != J);          //reading from x0 is ignored
    assign d_rr2      = (d_rs2 != 0) & ((d_op == B) | (d_op == S) | (d_op == R));
    assign stall      = (e_insn[6:0] == 7'b11) & (d_rr1 & (d_rs1 == e_rd) |                  //stall if load-use situation
                                                 (d_rr2 & (d_rs2 == e_rd) & (d_op != S))) |  //or
                        (reg_wen               & (d_rr1 & (d_rs1 == w_rd) |                  //stall if reading from register which
                                                  d_rr2 & (d_rs2 == w_rd)));                 //would be written in this cycle, WD situation                                                               

    //EXE
    assign e_op         = e_insn[6:2];
    assign e_fun3       = e_insn[14:12];
    assign e_fun7       = e_insn[30];
    assign e_rs1        = e_insn[19:15];
    assign e_rs2        = e_insn[24:20];
    assign e_rd         = e_insn[11:7];
    assign pc_sel       = (e_op == B) ? ((!e_fun3[2] & (e_fun3[0] ^ br_eq)) |           //take branch if insn is BRANCH and
                                    (e_fun3[2] & (e_fun3[0] ^ br_lt))) :                //corresponding output is generated by bcomp
                                    (e_op == JALR);                                     //or if insn is JALR
    assign a_sel        = ((e_op == B)| (e_op == AUI) | (e_op == J));                   //if (B or AUI or J)            ? E_PC  : E_DATA_A
    assign b_sel        = (e_op != R);                                                  //if (not R)                    ? E_IMM : E_DATA_B
    assign e_rr1        = (e_rs1 != 0) & (e_op != LUI) & (e_op != AUI) & (e_op != J);   //rs1 in e_insn is register addr
    assign e_rr2        = (e_rs2 != 0) & ((e_op == B) | (e_op == S) | (e_op == R));     //rs2 in e_insn is register addr
    assign rs1_sel      = !e_rr1                        ? 2 :                           //not reading from rs1, no bypass
                          ((e_rs1 == m_rd) & m_reg_wen) ? 0 :                           //0: M->X bypass
                          ((e_rs1 == w_rd) & reg_wen)   ? 1 : 2;                        //1: W->X bypass 
    assign rs2_sel      = !e_rr2                        ? 2 :                           //not reading from rs2, no bypass
                          ((e_rs2 == m_rd) & m_reg_wen) ? 0 :                           //0: M->X bypass 
                          ((e_rs2 == w_rd) & reg_wen)   ? 1 : 2;                        //1: W->X bypass 
    assign br_un        = e_fun3[1];                                                    //if (bltu or bgeu)             ? 1:x
    assign alu_sel[2:0] = ((e_op == R) | (e_op == I)) ? e_fun3 : 0;                     //if (R or I)                   ? fun3:0
    assign alu_sel[3]   = (((e_op == I) & (e_fun3 != 0)) | (e_op == R)) ? e_fun7 : 0;   //if ((I and not ADDI) or R)    ? fun7:0

    //MEM
    assign m_op      = m_insn[6:2];
    assign m_fun3    = m_insn[14:12];
    assign m_rs2     = m_insn[24:20];
    assign m_rd      = m_insn[11:7];
    assign mem_rw    = (m_op == S);                                                     //if (S)                        ? 1:0
    assign acc_size  = m_fun3[1:0];
    assign wb_sel    = (m_op == LOAD) ? 0 : ((m_op == J) | (m_op == JALR)) ? 2 : 1;     //LOAD: M_ADDRESS, (J or JALR): M_PC + 4, else: DATA_EXT
    assign dataw_sel = (m_rs2 == w_rd) & reg_wen;                                       //W->M bypass: if (STORE_rs2 == w_rd)       ? 1:0
    assign m_reg_wen = (m_op != S) & (m_op != B) & (m_rd != 0);                         //if (!S and !B and !(write to x0))         ? 1:0
                                                                                        //disabled also for nop, since it writes to x0

    //WB
    assign w_op      = w_insn[6:2];
    assign w_rd      = w_insn[11:7];
    assign reg_wen   = (w_op != S) & (w_op != B) & (w_rd != 0);                         //if (!S and !B and !(write to x0))          ? 1:0

endmodule