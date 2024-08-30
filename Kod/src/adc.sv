
module adc(
    input clk,
    input [1:0] channel,
    output reg [15:0] outputData,
    output reg dataReady,
    input enable,
    output reg scl,
    output reg isSending,
    output reg sdaOutReg,
    input sdaIn
);

reg completeI2C;
reg [7:0] byteReceivedI2C;
reg [7:0] byteToSendI2C;
reg enableI2C;
reg [1:0] instructionI2C;

parameter address = 7'b1001001;

// setup config
reg [15:0] setupRegister = {
    1'b1, // Start Conversion
    3'b100, // Channel 0 Single ended
    3'b001, // FSR +- 4.096v
    1'b1, // Single shot mode
    3'b111, // 128 SPS
    1'b0, // Traditional Comparator
    1'b0, // Active low alert
    1'b0, // Non latching
    2'b11 // Disable comparator
};


initial begin
outputData = 16'b0000000000000000;
dataReady = 1'b1;
instructionI2C = 2'b00;
enableI2C = 1'b0;
byteToSendI2C = 8'b00000000;

isSending = 1'b0;
sdaOutReg = 1'b1;
scl = 1'b1;
byteReceivedI2C = 8'b00000001;
end


localparam CONFIG_REGISTER = 8'b00000001;
localparam CONVERSION_REGISTER = 8'b00000000;


localparam INST_START_TX = 0;
localparam INST_STOP_TX = 1;
localparam INST_READ_BYTE = 2;
localparam INST_WRITE_BYTE = 3;

localparam STATE_IDLE = 0;
localparam STATE_RUN_TASK = 1;
localparam STATE_WAIT_FOR_I2C = 2;
localparam STATE_INC_SUB_TASK = 3;
localparam STATE_DONE = 4;
localparam STATE_DELAY = 5;

reg [1:0] taskIndex = 0;
reg [2:0] subTaskIndex = 0;
reg [4:0] state = STATE_IDLE;
reg [7:0] counter = 0;
reg processStarted = 0;

reg [5:0] NESTO = 0;

always @(posedge clk) begin
    case (state)
        STATE_IDLE: begin
            if (enable) begin
                state <= STATE_RUN_TASK;
                taskIndex <= 0;
                subTaskIndex <= 0;
                dataReady <= 0;
                counter <= 0;
                NESTO <= 0;
            end
        end
        STATE_RUN_TASK: begin
            case (NESTO)
                0: begin // TASK_SETUP
                    instructionI2C <= INST_START_TX;
                    enableI2C <= 1;
                    NESTO <= 6'(NESTO + 6'b1);
                   end
                1: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                2: begin
                    instructionI2C <= INST_WRITE_BYTE;
                    byteToSendI2C <= {address, 1'b0};
                    enableI2C <= 1;
                    NESTO <= 6'(NESTO + 6'b1);
                   end
                3: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                4: begin
                    instructionI2C <= INST_WRITE_BYTE;
                    byteToSendI2C <= CONFIG_REGISTER;
                    enableI2C <= 1;
                    NESTO <= 6'(NESTO + 6'b1);
                   end 
                5: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                6: begin
                    instructionI2C <= INST_WRITE_BYTE;
                    byteToSendI2C <= {
                        setupRegister[15] ? 1'b1 : 1'b0,
                        1'b1, channel,
                        setupRegister[11:8]
                    };
                    enableI2C <= 1;
                    NESTO <= 6'(NESTO + 6'b1);
                   end
                7: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                8: begin
                    instructionI2C <= INST_WRITE_BYTE;
                    byteToSendI2C <= setupRegister[7:0];
                    enableI2C <= 1;
                    NESTO <= 6'(NESTO + 6'b1);
                  end
                9:  begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                10: begin
                    instructionI2C <= INST_STOP_TX;
                    enableI2C <= 1;
                    NESTO <= 6'(NESTO + 6'b1);
                   end
                11: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                12: begin
                     counter <= 8'(counter + 8'b1); //VRATI NA OVAJ
                     if (counter == 8'b11111111) begin
                       NESTO <= 6'(NESTO + 6'b1);
                      end
                    end
                13: begin
                     instructionI2C <= INST_START_TX;
                     enableI2C <= 1;
                     NESTO <= 6'(NESTO + 6'b1);
                    end
                14: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                15: begin
                        instructionI2C <= INST_WRITE_BYTE;
                        byteToSendI2C <= {address, 1'b1};
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                16:  begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                17: begin
                        instructionI2C <= INST_READ_BYTE;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                18:  begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                19: begin
                        instructionI2C <= INST_READ_BYTE;
                        outputData[15:8] <= byteReceivedI2C;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                20:  begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                21:  begin
                        instructionI2C <= INST_STOP_TX;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                22: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                23: begin
                    if (outputData[15])
                        NESTO <= 6'(NESTO + 6'b1);
                    else begin
                        NESTO <= 6'b1100; // TELEPORTIRAJUCII
                        end
                    end
                24: begin
                        instructionI2C <= INST_START_TX;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                25: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                26: begin
                        instructionI2C <= INST_WRITE_BYTE;
                        byteToSendI2C <= {address, 1'b0};
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                27: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                28: begin
                        instructionI2C <= INST_WRITE_BYTE;
                        byteToSendI2C <= CONVERSION_REGISTER;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end 
                29: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                30: begin
                        instructionI2C <= INST_STOP_TX;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end 
                31: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                32: begin
                        instructionI2C <= INST_START_TX;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                33: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                34: begin
                        instructionI2C <= INST_WRITE_BYTE;
                        byteToSendI2C <= {address, 1'b1 };
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                35: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                36: begin
                        instructionI2C <= INST_READ_BYTE;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                37: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                38:  begin
                    instructionI2C <= INST_READ_BYTE;
                    outputData[15:8] <= byteReceivedI2C;
                    enableI2C <= 1;
                    NESTO <= 6'(NESTO + 6'b1);
                    end
                39: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end
                40: begin
                        NESTO <= 6'(NESTO + 6'b1);
                        outputData[7:0] <= byteReceivedI2C;
                    end               
                41: begin
                        instructionI2C <= INST_STOP_TX;
                        enableI2C <= 1;
                        NESTO <= 6'(NESTO + 6'b1);
                    end
                42: begin // STATE_WAIT_FOR_I2C
                    if (~processStarted && ~completeI2C)
                        processStarted <= 1;
                    else if (completeI2C && processStarted) begin
                        NESTO <= 6'(NESTO + 6'b1);
                        processStarted <= 0;
                        enableI2C <= 0;
                        end
                    end               
                43: begin
                    state <= STATE_DONE;
                    NESTO <= 6'b000000;
                    end
                default:
                 NESTO <= 6'(NESTO + 6'b1); 
            endcase
        end

        STATE_DONE: begin
            dataReady <= 1;
            if (~enable)
                state <= STATE_IDLE;
        end
    endcase
end


    localparam INST_START_TX1 = 0;
    localparam INST_STOP_TX1 = 1;
    localparam INST_READ_BYTE1 = 2;
    localparam INST_WRITE_BYTE1 = 3;
    localparam STATE_IDLE1 = 4;
    localparam STATE_DONE1 = 5;
    localparam STATE_SEND_ACK = 6;
    localparam STATE_RCV_ACK = 7;

    reg [6:0] clockDivider = 0;

    reg [2:0] stanje = STATE_IDLE1;
    reg [2:0] bitToSend = 0;

    always @(posedge clk) begin
        case (stanje)
            STATE_IDLE1: begin
                if (enableI2C) begin
                    completeI2C <= 0;
                    clockDivider <= 0;
                    bitToSend <= 0;
                    stanje <= {1'b0,instructionI2C};
                end
            end
            INST_START_TX1: begin
                isSending <= 1;
                clockDivider <= 7'(clockDivider + 7'b1);
                if (clockDivider[6:5] == 2'b00) begin
                    scl <= 1;
                    sdaOutReg <= 1;
                end else if (clockDivider[6:5] == 2'b01) begin
                    sdaOutReg <= 0;
                end else if (clockDivider[6:5] == 2'b10) begin
                    scl <= 0;
                end else if (clockDivider[6:5] == 2'b11) begin
                    stanje <= STATE_DONE1;
                end
            end
            INST_STOP_TX1: begin
                isSending <= 1;
                clockDivider <= 7'(clockDivider + 7'b1);
                if (clockDivider[6:5] == 2'b00) begin
                    scl <= 0;
                    sdaOutReg <= 0;
                end else if (clockDivider[6:5] == 2'b01) begin
                    scl <= 1;
                end else if (clockDivider[6:5] == 2'b10) begin
                    sdaOutReg <= 1;
                end else if (clockDivider[6:5] == 2'b11) begin
                    stanje <= STATE_DONE1;
                end
            end
            INST_READ_BYTE1: begin
                isSending <= 0;
                clockDivider <= 7'(clockDivider + 7'b1);
                if (clockDivider[6:5] == 2'b00) begin
                    scl <= 0;
                end else if (clockDivider[6:5] == 2'b01) begin
                    scl <= 1;
                end else if (clockDivider == 7'b1000000) begin
                    byteReceivedI2C <= {byteReceivedI2C[6:0], sdaIn ? 1'b1 : 1'b0};
                end else if (clockDivider == 7'b1111111) begin
                    bitToSend <= 3'(bitToSend + 3'b1);
                    if (bitToSend == 3'b111) begin
                        stanje <= STATE_SEND_ACK;
                    end
                end else if (clockDivider[6:5] == 2'b11) begin
                    scl <= 0;
                end
            end
            STATE_SEND_ACK: begin
                isSending <= 1;
                sdaOutReg <= 0;
                clockDivider <= 7'(clockDivider + 7'b1);
                if (clockDivider[6:5] == 2'b01) begin
                    scl <= 1;
                end else if (clockDivider == 7'b1111111) begin
                    stanje <= STATE_DONE1;
                end else if (clockDivider[6:5] == 2'b11) begin
                    scl <= 0;
                end
            end
            INST_WRITE_BYTE1: begin
                isSending <= 1;
                clockDivider <= 7'(clockDivider + 7'b1);
                sdaOutReg <= byteToSendI2C[3'd7-bitToSend] ? 1'b1 : 1'b0;

                if (clockDivider[6:5] == 2'b00) begin
                    scl <= 0;
                end else if (clockDivider[6:5] == 2'b01) begin
                    scl <= 1;
                end else if (clockDivider == 7'b1111111) begin
                    bitToSend <= 3'(bitToSend + 3'b1);
                    if (bitToSend == 3'b111) begin
                        stanje <= STATE_RCV_ACK;
                    end
                end else if (clockDivider[6:5] == 2'b11) begin
                    scl <= 0;
                end
            end
            STATE_RCV_ACK: begin
                isSending <= 0;
                clockDivider <= 7'(clockDivider + 7'b1);

                if (clockDivider[6:5] == 2'b01) begin
                    scl <= 1;
                end else if (clockDivider == 7'b1111111) begin
                    stanje <= STATE_DONE1;
                end else if (clockDivider[6:5] == 2'b11) begin
                    scl <= 0;
                end
            end
            STATE_DONE1: begin
                completeI2C <= 1;
                if (~enableI2C)
                    stanje <= STATE_IDLE1;
            end
        endcase
    end

endmodule