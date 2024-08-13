module cpu (
  input wire clock,
  input wire reset
);

  parameter [31:0] BASE_ADDRESS = 32'h01000000; //BASE ADDRESS for memories
  parameter [31:0] nop          = 32'b10011;    //ADDI x0,x0,0
  parameter [6:2]  JALR         =  5'b11001;    //JALR opcode

  //FETCH stage signals:
  reg  [31:0] F_PC;
  wire [31:0] F_INSN;
  wire        PC_SEL;         //E_BR_TAKEN in signals.h - jumps taken from EXE only
  wire        PC_JUMPSEL;     //jumps taken from DEC stage (only JAL)
  wire        stall;          //control signal for stalls

  //DECODE stage signals:
  reg  [31:0] D_PC;
  reg  [31:0] D_INSN;
  wire [6:0]  D_OPCODE;
  wire [4:0]  D_RD;
  wire [4:0]  D_RS1;
  wire [4:0]  D_RS2;
  wire [2:0]  D_FUNCT3;
  wire [6:0]  D_FUNCT7;
  wire [31:0] D_IMM;
  wire [31:0] D_ADD_RES;      //adder result for jumps = PC + IGEN(imm, J)

  //Register file signals:
  wire        R_WRITE_ENABLE;
  wire [4:0]  R_WRITE_DESTINATION;
  wire [31:0] R_WRITE_DATA;
  wire [31:0] R_READ_RS1_DATA;
  wire [31:0] R_READ_RS2_DATA;

  //EXECUTE stage signals:
  reg  [31:0] E_PC;
  reg  [31:0] E_INSN;
  reg  [31:0] E_IMM;          //registered immediate value of D_IMM generated in DEC stage
  reg  [31:0] E_DATA_IN_A;    //registered rs1 output data from register file
  reg  [31:0] E_DATA_IN_B;    //registered rs2 output data from register file
  wire [31:0] E_DATA_A;       //rs1 bypass mux output
  wire [31:0] E_DATA_B;       //rs2 bypass mux output
  wire [31:0] ALU_DATA_A;
  wire [31:0] ALU_DATA_B;
  wire [31:0] ALU_OUT;
  wire [31:0] E_ALU_RES;
  wire        BR_UN;
  wire        BR_EQ;
  wire        BR_LT;
  wire        A_SEL;
  wire        B_SEL;
  wire [1:0]  RS1_SEL;        //rs1 bypass mux select
  wire [1:0]  RS2_SEL;        //rs2 bypass mux select
  wire [3:0]  ALU_SEL;
  wire [2:0]  IMM_SEL;

  //MEMORY stage signals:
  reg  [31:0] M_PC;
  reg  [31:0] M_INSN;
  reg  [31:0] M_ADDRESS;
  reg  [31:0] M_DATA_IN;      //registered rs2 data from EXE stage
  wire [31:0] M_DATA_W;       //rs2 bypass mux output - fed into dataw of dmem
  wire [31:0] M_DATA;         //dmem output
  wire [31:0] MW_DATA;        //mux output to Writeback stage
  reg  [31:0] DATA_EXT;       //extended data for LOAD insns
  wire        DATAW_SEL;      //rs2 bypass mux select
  wire        M_RW;
  wire [1:0]  M_SIZE;         //access size for dmem
  wire [1:0]  WB_SEL;

  //WRITEBACK stage signals:
  reg  [31:0] W_PC;
  reg  [31:0] W_INSN;
  reg  [31:0] W_DATA;
  wire        W_ENABLE;

  imemory #(.BASE_ADDR(BASE_ADDRESS)) imem(
    .clock(clock),
    .read_write(0),
    .address(F_PC),
    .data_in(0),
    .data_out(F_INSN)
  );

  decoder dec(
    .d_insn(D_INSN),
    .opcode(D_OPCODE),
    .rd(D_RD),
    .rs1(D_RS1),
    .rs2(D_RS2),
    .funct3(D_FUNCT3),
    .funct7(D_FUNCT7)
  );

  register_file reg_file(
    .clock(clock),
    .reset(reset),
    .write_enable(R_WRITE_ENABLE),
    .addr_rd(R_WRITE_DESTINATION),
    .addr_rs1(D_RS1),
    .addr_rs2(D_RS2),
    .data_rd(R_WRITE_DATA),
    .data_rs1(R_READ_RS1_DATA),
    .data_rs2(R_READ_RS2_DATA)
  );

  immgen igen(
    .insn(D_INSN[31:7]),      //IGEN is placed in DEC stage
    .imm_sel(IMM_SEL),        //for the purpose of calculating offset for JAL
    .imm_val(D_IMM)           //it's then registered into EXE stage
  );

  branch_comp bcomp_unit(
    .data_a(E_DATA_A),        //gets input from bypass mux output in EXE stage
    .data_b(E_DATA_B),
    .br_un(BR_UN),
    .br_eq(BR_EQ),
    .br_lt(BR_LT)
  );

  alu alu_unit(
    .alu_sel(ALU_SEL),
    .data_a(ALU_DATA_A),
    .data_b(ALU_DATA_B),
    .alu_res(ALU_OUT)
  );

  dmemory #(.BASE_ADDR(BASE_ADDRESS)) dmem(
    .clock(clock),
    .read_write(M_RW),
    .access_size(M_SIZE),
    .address(M_ADDRESS),
    .data_in(M_DATA_W),
    .data_out(M_DATA)
  );

  controller control_unit(
    .d_insn(D_INSN),
    .e_insn(E_INSN),
    .m_insn(M_INSN),
    .w_insn(W_INSN),
    .br_eq(BR_EQ),
    .br_lt(BR_LT),
    .pc_sel(PC_SEL),
    .pc_jumpsel(PC_JUMPSEL),
    .reg_wen(W_ENABLE),
    .imm_sel(IMM_SEL),
    .rs1_sel(RS1_SEL),
    .rs2_sel(RS2_SEL),
    .a_sel(A_SEL),
    .b_sel(B_SEL),
    .br_un(BR_UN),
    .alu_sel(ALU_SEL),
    .mem_rw(M_RW),
    .dataw_sel(DATAW_SEL),
    .acc_size(M_SIZE),
    .wb_sel(WB_SEL),
    .stall(stall)
  );
  
  //FETCH
  always @(posedge clock) begin
    if (reset) begin
      F_PC <= BASE_ADDRESS;
    end else begin
      F_PC <= PC_SEL     ? E_ALU_RES :                //branches/jumps taken from EXE stage
              PC_JUMPSEL ? D_ADD_RES :                //jumps taken from DEC stage
              stall      ? F_PC      : (F_PC + 4);    //keep value when there is a stall
    end
  end
  
  //DEC
  assign D_ADD_RES = D_PC + D_IMM;                    //for jumps from DEC stage

  always @(posedge clock) begin
    if (reset) begin
      D_PC   <= 0;
      D_INSN <= 0;
    end else if (PC_SEL | PC_JUMPSEL) begin
      D_INSN <= nop;                                  //place nop if jumps are taken
    end else if (!stall) begin
      D_PC   <= F_PC;                                 //keep value if stall
      D_INSN <= F_INSN;
    end
  end

  //EXE
  assign E_DATA_A   = (RS1_SEL == 0) ? M_ADDRESS :                //0: bypass M -> X
                      (RS1_SEL == 1) ? W_DATA    : E_DATA_IN_A;   //1: bypass W -> X
  assign E_DATA_B   = (RS2_SEL == 0) ? M_ADDRESS :                //0: bypass M -> X
                      (RS2_SEL == 1) ? W_DATA    : E_DATA_IN_B;   //1: bypass W -> X
  assign ALU_DATA_A = (A_SEL) ? E_PC  : E_DATA_A;
  assign ALU_DATA_B = (B_SEL) ? E_IMM : E_DATA_B;
  assign E_ALU_RES  = (E_INSN[6:2] == JALR) ? (ALU_OUT & 32'hfffffffe) : ALU_OUT;
  
  always @(posedge clock) begin
    if (reset) begin
      E_PC        <= 0;
      E_INSN      <= 0;
      E_IMM       <= 0;
      E_DATA_IN_A <= 0;
      E_DATA_IN_B <= 0;
    end else if (stall | PC_SEL) begin
      E_INSN      <= nop;                             //place nop if (stall) or (jump from EXE)
    end else begin
      E_PC        <= D_PC;
      E_INSN      <= D_INSN;
      E_IMM       <= D_IMM;
      E_DATA_IN_A <= R_READ_RS1_DATA;
      E_DATA_IN_B <= R_READ_RS2_DATA;
    end
  end

  //MEM
  always @(*) begin                                          
    case ({M_INSN[6:2], M_INSN[13:12]})                                 //LOAD extension
      0: DATA_EXT = {{24{~M_INSN[14] & M_DATA[7]}},  M_DATA[7:0]};      //byte
      1: DATA_EXT = {{16{~M_INSN[14] & M_DATA[15]}}, M_DATA[15:0]};     //half-word
      default: 
         DATA_EXT = M_DATA;                                             //word
    endcase 
  end

  assign M_DATA_W = DATAW_SEL ? W_DATA : M_DATA_IN;   //1: bypass W -> M
  assign MW_DATA  = (WB_SEL == 1) ?  M_ADDRESS :
                    (WB_SEL == 2) ? (M_PC + 4) : DATA_EXT;
  
  always @(posedge clock) begin
    if (reset) begin
      M_PC      <= 0;
      M_ADDRESS <= 0;
      M_DATA_IN <= 0;
      M_INSN    <= 0;
    end else begin
      M_PC      <= E_PC;
      M_ADDRESS <= E_ALU_RES;
      M_DATA_IN <= E_DATA_B;
      M_INSN    <= E_INSN;
    end
  end

  //WB
  assign R_WRITE_DESTINATION = W_INSN[11:7];
  assign R_WRITE_DATA        = W_DATA;
  assign R_WRITE_ENABLE      = W_ENABLE;

  always @(posedge clock) begin
    if (reset) begin
      W_PC   <= 0;
      W_INSN <= 0;
      W_DATA <= 0;
    end else begin
      W_PC   <= M_PC;
      W_INSN <= M_INSN;
      W_DATA <= MW_DATA;
    end
  end

endmodule
