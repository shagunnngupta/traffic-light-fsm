// traffic_light.v  (plain Verilog) - with pedestrian button
module traffic_light (
    input  wire clk,
    input  wire rst_n,      // active low reset
    input  wire ped_button, // pedestrian request (momentary)
    output reg [2:0] ns,   // ns = {red, yellow, green}
    output reg [2:0] ew,   // ew = {red, yellow, green}
    output reg ped_walk    // pedestrian "WALK" active during extended NS green
);

    // state encoding
    localparam S_NS_GREEN  = 3'd0;
    localparam S_NS_YEL    = 3'd1;
    localparam S_ALL_RED   = 3'd2;
    localparam S_EW_GREEN  = 3'd3;
    localparam S_EW_YEL    = 3'd4;
    localparam S_ALL_RED2  = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] counter;        // main counter for durations
    reg ped_request;           // latched pedestrian request
    reg [15:0] ped_extend;     // pedestrian extend counter (counts down when serving)

    // durations (in clock ticks)
    localparam NS_GREEN_T = 16'd50; // base NS green
    localparam NS_YEL_T   = 16'd10;
    localparam ALL_RED_T  = 16'd5;
    localparam EW_GREEN_T = 16'd50;
    localparam EW_YEL_T   = 16'd10;
    localparam ALL_RED2_T = 16'd5;
    localparam PED_T      = 16'd20; // extra ticks to serve pedestrian

    // synchronous state + counters + ped request latch
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_NS_GREEN;
            counter <= 16'd0;
            ped_request <= 1'b0;
            ped_extend <= 16'd0;
        end else begin
            // latch pedestrian request (edge or level doesn't matter; keep it simple)
            if (ped_button) ped_request <= 1'b1;

            // update main counter
            if (counter == 16'hFFFF) counter <= 16'd0;
            else counter <= counter + 16'd1;

            // if ped_extend active, count it down on each clock
            if (ped_extend != 16'd0) ped_extend <= ped_extend - 16'd1;

            state <= next_state;
        end
    end

    // next state logic
    always @(*) begin
        // by default, do not change state
        next_state = state;
        case (state)
            // In NS_GREEN, if ped_extend is active we hold extra time.
            S_NS_GREEN: begin
                // if we are in NS_GREEN and there's no ped_extend active, use base time
                if (ped_extend != 16'd0) begin
                    if (counter >= NS_GREEN_T + PED_T - 1) next_state = S_NS_YEL;
                end else begin
                    if (counter >= NS_GREEN_T - 1) next_state = S_NS_YEL;
                end
            end

            S_NS_YEL:   if (counter >= NS_YEL_T-1)   next_state = S_ALL_RED;
            S_ALL_RED:  if (counter >= ALL_RED_T-1)  next_state = S_EW_GREEN;
            S_EW_GREEN: if (counter >= EW_GREEN_T-1) next_state = S_EW_YEL;
            S_EW_YEL:   if (counter >= EW_YEL_T-1)   next_state = S_ALL_RED2;
            S_ALL_RED2: if (counter >= ALL_RED2_T-1) next_state = S_NS_GREEN;
            default: next_state = S_NS_GREEN;
        endcase
    end

    // When we enter NS_GREEN and a request exists, start ped_extend and clear the request
    // We'll implement this as a small combinational check and edge update in a synchronous block:
    // (To do it cleanly, detect when next_state is NS_GREEN and state != NS_GREEN to know an entry)
    reg entering_ns_green;
    always @(*) begin
        entering_ns_green = (next_state == S_NS_GREEN) && (state != S_NS_GREEN);
    end

    // But we need to actually set ped_extend and ped_walk inside a synchronous update.
    // We'll update ped_extend and ped_request in the posedge block above by checking entering_ns_green.
    // To do that, add another small sequential block (separate always) that uses entering_ns_green.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ped_extend <= 16'd0;
            ped_request <= 1'b0;
            // ped_request already handled above; this double-decl ensures init
        end else begin
            // When we just entered NS_GREEN, if there is a pending request, set ped_extend
            if (entering_ns_green && ped_request) begin
                ped_extend <= PED_T;
                ped_request <= 1'b0; // clear request, will be served now
            end
        end
    end

    // output logic (Moore)
    always @(*) begin
        // default outputs
        ns = 3'b100; // red,yel,green = {red,yel,green}
        ew = 3'b100;
        ped_walk = 1'b0;
        case (state)
            S_NS_GREEN: begin
                ns = 3'b001;
                ew = 3'b100;
                // ped_walk is high while ped_extend is counting (i.e., being served) OR during normal NS_GREEN when ped_extend>0
                if (ped_extend != 16'd0) ped_walk = 1'b1;
            end
            S_NS_YEL:   begin ns = 3'b010; ew = 3'b100; end
            S_ALL_RED:  begin ns = 3'b100; ew = 3'b100; end
            S_EW_GREEN: begin ns = 3'b100; ew = 3'b001; end
            S_EW_YEL:   begin ns = 3'b100; ew = 3'b010; end
            S_ALL_RED2: begin ns = 3'b100; ew = 3'b100; end
        endcase
    end

endmodule
