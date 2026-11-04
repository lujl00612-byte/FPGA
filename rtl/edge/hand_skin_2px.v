// Fixed YCbCr gates. No histogram, automatic threshold or runtime adaptation.
module hand_skin_2px(input wire [47:0] rgbx2,output wire [1:0] skin,weak_skin);
    function [1:0] skin_flags;
        input [23:0] rgb;
        reg [7:0] r,g,b;
        reg signed [18:0] y,cb,cr;
        reg signed [18:0] dc,dr;
        reg skin_seed,skin_candidate;
        begin
            r=rgb[23:16];g=rgb[15:8];b=rgb[7:0];
            y=(77*$signed({1'b0,r})+150*$signed({1'b0,g})+29*$signed({1'b0,b}))>>>8;
            cb=((-43*$signed({1'b0,r})-85*$signed({1'b0,g})+128*$signed({1'b0,b}))>>>8)+128;
            cr=((128*$signed({1'b0,r})-107*$signed({1'b0,g})-21*$signed({1'b0,b}))>>>8)+128;
            skin_seed=y>=40&&cb>=77&&cb<=127&&cr>=133&&cr<=180&&r>g&&r>b;
            dc=cb>=108?cb-108:108-cb;
            dr=cr>=151?cr-151:151-cr;
            // Fixed chroma polygon admits dimmer/less red skin, while excluding neutral grey.
            skin_candidate=skin_seed||(y>=24&&cb>=70&&cb<=137&&cr>=125&&cr<=188&&
                r>g&&r>b&&2*dc+dr<=54);
            skin_flags={skin_seed,skin_candidate};
        end
    endfunction
    wire [1:0] f0=skin_flags(rgbx2[23:0]),f1=skin_flags(rgbx2[47:24]);
    assign skin={f1[1],f0[1]};
    assign weak_skin={f1[0],f0[0]};
endmodule
