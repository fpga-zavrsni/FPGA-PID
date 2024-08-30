
module uart(
 input clk,
 output uart_tx,
 input [14:0] voltageCh1,
 input [14:0] voltageCh2
);


reg [19:0] sekunda = 0;

parameter DELAY_FRAMES = 234; // 27,000,000 (27Mhz) / 115200 Baud rate

always @(posedge clk) begin
  sekunda <= 20'(sekunda + 20'b1);
  if (sekunda == 20'b11111111111111111111) begin
        sekunda <= ~(sekunda);
       end
end



reg [3:0] txState = 0;
reg [24:0] txCounter = 0;
reg [7:0] dataOut = 0;
reg txPinRegister = 1;
reg [2:0] txBitNumber = 0;
reg [4:0] txByteCounter = 0;

assign uart_tx = txPinRegister;

localparam MEMORY_LENGTH = 5; // evo za prosli slucaj sam ima ood 0 do 30 i 30 je bio \n
reg [7:0] testMemory [MEMORY_LENGTH-1:0];
localparam TX_STATE_IDLE = 0;
localparam TX_STATE_START_BIT = 1;
localparam TX_STATE_WRITE = 2;
localparam TX_STATE_STOP_BIT = 3;
localparam TX_STATE_DEBOUNCE = 4;


always @(posedge clk) begin
    case (txState)
        TX_STATE_IDLE: begin
            if (sekunda == 0) begin
                txState <= TX_STATE_START_BIT;
                txCounter <= 0;
                txByteCounter <= 0;
                    testMemory[0] = {1'b0, voltageCh1[14:8]}; 
                    testMemory[1] = voltageCh1[7:0]; 
                    testMemory[2] = {1'b0, voltageCh2[14:8]}; 
                    testMemory[3] = voltageCh2[7:0]; 
                    testMemory[4] = 8'b00001010;
            end
            else begin
                txPinRegister <= 1;
            end
        end 
        TX_STATE_START_BIT: begin
            txPinRegister <= 0;
            if ((txCounter + 1) == DELAY_FRAMES) begin
                txState <= TX_STATE_WRITE;
                dataOut <= testMemory[txByteCounter];
                txBitNumber <= 0;
                txCounter <= 0;
            end else 
                txCounter <= 25'(txCounter + 25'b1);
        end
        TX_STATE_WRITE: begin
            txPinRegister <= dataOut[txBitNumber];
            if ((txCounter + 1) == DELAY_FRAMES) begin
                if (txBitNumber == 3'b111) begin
                    txState <= TX_STATE_STOP_BIT;
                end else begin
                    txState <= TX_STATE_WRITE;
                    txBitNumber <= 3'(txBitNumber + 3'b1);
                end
                txCounter <= 0;
            end else 
                txCounter <= 25'(txCounter + 25'b1);
        end
        TX_STATE_STOP_BIT: begin
            txPinRegister <= 1;
            if ((txCounter + 1) == DELAY_FRAMES) begin
                if (txByteCounter == MEMORY_LENGTH - 1) begin
                    //txState <= TX_STATE_DEBOUNCE;
                    txState <= TX_STATE_IDLE;
                end else begin
                    txByteCounter <= 5'(txByteCounter + 5'b1);
                    txState <= TX_STATE_START_BIT;
                end
                txCounter <= 0;
            end else 
                txCounter <= 25'(txCounter + 25'b1);
        end
        TX_STATE_DEBOUNCE: begin
            if (txCounter == 23'b111111111111111111) begin
                    txState <= TX_STATE_IDLE;
            end else
                txCounter <= 25'(txCounter + 25'b1);
        end
    endcase      
end

endmodule