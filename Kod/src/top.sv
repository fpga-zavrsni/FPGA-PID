module top (
    input clk,
    inout i2cSda,
    output i2cScl,
    output logic ledica,
    input arst_n,
    output uart_tx
);

    // Dio koda za A/D konverziju
    wire sdaIn;
    wire sdaOut;
    wire isSending;
    assign i2cSda = (isSending & ~sdaOut) ? 1'b0 : 1'bz;
    assign sdaIn = i2cSda ? 1'b1 : 1'b0;

    reg [1:0] adcChannel = 0;
    wire [15:0] adcOutputData;
    wire adcDataReady;
    reg adcEnable = 0;

    adc a(
        clk,
        adcChannel,
        adcOutputData,
        adcDataReady,
        adcEnable,
        i2cScl,
        isSending,
        sdaOut,
        sdaIn
    );

    reg [14:0] voltageCh1 = 0;
    reg [14:0] voltageCh2 = 0;

    localparam STATE_TRIGGER_CONV = 0;
    localparam STATE_WAIT_FOR_START = 1;
    localparam STATE_SAVE_VALUE_WHEN_READY = 2;

    reg [2:0] drawState = 0;
    
    always @(posedge clk) begin
        case (drawState)
            STATE_TRIGGER_CONV: begin
                adcEnable <= 1;
                drawState <= STATE_WAIT_FOR_START;
            end
            STATE_WAIT_FOR_START: begin
                if (~adcDataReady) begin
                    drawState <= STATE_SAVE_VALUE_WHEN_READY;
                end
            end
            STATE_SAVE_VALUE_WHEN_READY: begin
                if (adcDataReady) begin
                    adcChannel <= adcChannel[0] ? 2'b00 : 2'b01;
                    if (~adcChannel[0]) begin
                        voltageCh1 <= adcOutputData[15] ? 15'd0 : adcOutputData[14:0];
                    end
                    else begin
                        voltageCh2 <= adcOutputData[15] ? 15'd0 : adcOutputData[14:0];
                    end
                    drawState <= STATE_TRIGGER_CONV;
                    adcEnable <= 0;
                end
            end
        endcase
    end

  // Dio koda za PWM, PID i UART
  reg [14:0] temp_br;
  reg spori;
  reg signed [15:0] greska;
  reg [14:0] duty;

  always @(posedge clk) begin
  temp_br <= 15'(temp_br + 15'b1);
  if (temp_br == 15'b111111111111111) begin
        spori <= ~(spori);
       end
  end

  always @(posedge clk) begin
    greska <= voltageCh2 - voltageCh1;
  end

  PID_regulacija regul(
    duty,
    greska,
    spori,
    arst_n
  );  

  PWM_izlaz iz(
      clk,
      arst_n,
      duty,   
      ledica
  );


  uart u(
      clk,
      uart_tx,
      voltageCh1,
      voltageCh2
  );


endmodule
