module PWM_izlaz(
    input logic clk1,
    input logic arst_n,
    input logic [14:0] duty,
    output logic pwm_iz
);


reg [11:0] Q_reg;
reg d_reg;

reg [11:0] smanjeni_duty;
reg [11:0] modifikovani_duty;
assign smanjeni_duty = duty[14:3];


always_ff @(negedge arst_n,posedge clk1) begin
    if (arst_n == 1'b0) begin
        Q_reg <= 12'b111111111111;
    end
    else begin
        Q_reg <= 12'(Q_reg + 12'b1);
        d_reg <= (Q_reg < smanjeni_duty);
    end 
end

// Zbog invertovanja tranzistora
assign pwm_iz = ~d_reg;

endmodule: PWM_izlaz