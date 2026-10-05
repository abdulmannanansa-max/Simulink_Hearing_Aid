function [out, info] = ha_simulate(scene, p)
%HA_SIMULATE  Closed-loop, frame-by-frame simulation (identical structure to the Simulink model).
%   scene : ear-level acoustic input at the microphone (column, digital units, see p.cal_dB)
%   out   : receiver signal
%   info  : .gains ((2nb+1) x nF) per-frame [compression gain dB; NR gain dB; AFC error dB],
%           .fb (fed-back signal), .w_hist (AFC coefficients over time)
L = p.L; nF = floor(numel(scene)/L);
st  = ha_init_state(p);
zfb = zeros(numel(p.fb_h)-1, 1);
ydel = zeros(L,1);                      % Unit Delay (1 frame) in the feedback loop
out  = zeros(nF*L,1); fbs = zeros(nF*L,1);
gains = zeros(2*p.nb + 1, nF);   % +1 for the AFC adaptation-error row ha_core_frame.m now returns
wh = zeros(p.afc_len, ceil(nF/50));
for m = 1:nF
    idx = (m-1)*L + (1:L);
    if p.fb_on
        [fb, zfb] = filter(p.fb_h, 1, ydel, zfb);
    else
        fb = zeros(L,1);
    end
    [y, st, dg] = ha_core_frame(scene(idx) + fb, st, p);
    out(idx) = y; fbs(idx) = fb; gains(:,m) = dg; ydel = y;
    if mod(m,50)==0, wh(:,m/50) = st.w; end
end
info.gains = gains; info.fb = fbs; info.w_hist = wh; info.state = st;
end
