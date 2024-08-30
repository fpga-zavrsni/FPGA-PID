module PID_regulacija (
    output unsigned [14:0] u_out,
    input signed [15:0] e_in, 
    input clk_27,
    input areset
);
// Parametri K1 i K2 (K3 = 0 jer nema Kd komponente)
parameter k1 = 10'b0100000010; //0111//0011
parameter k2 = 10'b0010110001; //0100//0001
    
logic signed [15:0] u_prev;
logic signed [15:0] e_prev;
logic signed [15:0] e_prev1;
logic signed [35:0] d_reg;


// Dio koda za postavljanje spremanje starih vrijednosti ili resetovanje
always_ff @(posedge clk_27 or negedge areset)begin
    if(areset == 0) begin
        u_prev <= 0;
        e_prev <= 0;
        e_prev1 <= 0; // novo dodano;
    end else if ($signed(e_in) < $signed(16'b0))  begin
        u_prev <= 0;        
    end else begin
        e_prev1 <= e_prev;
        e_prev <= e_in;
        u_prev <= u_out;
    end

end


// racunanje PID regulacije
logic signed [35:0] d_wire;  
assign d_wire =  u_prev + k1*e_in - k2*e_prev1; 

//Provjera granicnih uslova
always_ff @(posedge clk_27) begin
    d_reg <= d_wire;
    if ($signed(e_in) < $signed(16'b0)) begin
        d_reg <= 36'b0; 
    end else if ($signed(d_wire) > $signed(36'h7FFF)) begin
        d_reg <= 36'h7FFF;
    end else if ($signed(d_wire) < $signed(36'b0)) begin
        d_reg <= 36'b0;
    end
end

assign u_out = d_reg[14:0];

endmodule: PID_regulacija