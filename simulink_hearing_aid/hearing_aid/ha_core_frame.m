function [y, st, dg] = ha_core_frame(d, st, p)
%HA_CORE_FRAME  One frame (p.L samples) of the hearing-aid signal chain.
%   d  : microphone frame INCLUDING any acoustic feedback (Lx1)
%   y  : receiver (loudspeaker) frame after processing
%   dg : [compression gain dB (1:nb); noise-reduction gain dB (nb+1:2*nb);
%         AFC adaptation-error level dB (2*nb+1)] for diagnostics.
%         Row 2*nb+1 is a raw diagnostic (the NLMS "ew" term's per-frame RMS, below), NOT a
%         clean convergence indicator: checked directly against this model's own data, it is
%         dominated by input signal level and by closed-loop transients as feedback first
%         builds up, not cleanly by how well the path has been learned, so it does not fall
%         in a simple, presentable way as the canceller adapts. For an honest "AFC working"
%         demonstration, use the howling-vs-stable comparison in ha_verify.m (T6) / fig4
%         instead. Noise reduction is a separate block, in rows nb+1:2*nb (0 dB = no
%         reduction, negative = attenuating that band); THAT gain genuinely and reliably
%         drops as the noise floor is learned -- see ha_demo_nr.m / ha_run_simulink.m fig8.
%
%   Chain:  AFC subtract -> FIR filterbank -> WDRC + noise reduction per band -> sum -> MPO limiter
%
%  CODEGEN NOTE: L, nb, Na are literal constants, not read from p. Every array in this
%  function is sized -- directly (zeros(L,nb), ramp=(1:L)'/L) or via buffer slicing
%  (st.ybuf(L+1:end)) -- from these three numbers. MATLAB Coder needs array sizes to be
%  provable at compile time; a scalar read from a struct field is ordinary runtime data to
%  it, even one that is numerically always 32/6/64, so sizing or slicing from it makes Coder
%  mark the result "unbounded variable-size" -- which is exactly the error a downstream Unit
%  Delay block then rejects. Literals here make every size a compile-time constant instead.
%  If you change L, nb or afc_len in ha_params.m, update these three literals too --
%  ha_verify.m asserts they still agree and errors loudly if they drift.
L  = 32;   % must equal ha_params p.L
nb = 6;    % must equal ha_params p.nb
Na = 64;   % must equal ha_params p.afc_len
d = d(:);

% ---------------- 1) adaptive feedback cancellation (pre-whitened NLMS) --
e = d;
afc_err_dB = -300;    % sentinel: AFC off this frame, so there is no adaptation error to report
if p.afc_on
    w = st.w;
    [dw, st.zd] = filter(p.afc_pwc, 1, d, st.zd);      % pre-whitened / high-frequency-emphasised mic
    ew_ss = 0;                                          % sum of squared adaptation error, this frame
    for j = 1:L
        ref  = st.ybuf(Na+j:-1:j+1);        % HP-filtered y[n-L-k], k = 0..Na-1 (previous-frame samples)
        refw = st.ywbuf(Na+j:-1:j+1);
        e(j) = d(j) - w.'*ref;              % feedback-cancelled input to the hearing aid
        ew   = dw(j) - w.'*refw;            % error used for adaptation (pre-whitened domain)
        ew_ss = ew_ss + ew^2;
        w    = (1 - p.afc_leak)*w + (p.afc_mu*ew/(refw.'*refw + p.afc_delta))*refw;
    end
    st.w = w;
    afc_err_dB = 10*log10(ew_ss/L + 1e-20);   % per-frame RMS adaptation error, dB -- watch this fall
end

% ---------------- 2) filterbank -------------------------------------------
X = zeros(L, nb); P = zeros(nb, 1);
for b = 1:nb
    [xb, zf]  = filter(p.hb(b,:), 1, e, st.zi(:,b));
    st.zi(:,b) = zf;
    X(:,b)    = xb;
    P(b)      = mean(xb.^2) + 1e-20;
end
% warm-up: the FIR filters start from zero state, so the first frames are not representative;
% keep the level / noise trackers locked to the input until the filterbank is filled.
warm = ceil(p.fir_order/L) + 2;
if st.init < warm
    st.env = P; st.ps = P; st.nn = P; st.init = st.init + 1; first = true;
else
    first = false;
end

% ---------------- 3) per-band gain: WDRC + noise reduction ---------------
gcomp = zeros(nb,1);
for b = 1:nb
    if P(b) > st.env(b), al = p.a_att; else al = p.a_rel; end
    st.env(b) = al*st.env(b) + (1-al)*P(b);
    Lb = 10*log10(st.env(b)) + p.cal_dB;
    if p.comp_on
        gcomp(b) = p.G0(b) - p.cs(b)*max(Lb - p.TK, 0) - p.exp_slope*max(p.TE - Lb, 0);
    else
        gcomp(b) = p.tgt(b);
    end
    % noise reduction
    st.ps(b) = p.nr_as*st.ps(b) + (1-p.nr_as)*P(b);
    st.nn(b) = min(st.ps(b), st.nn(b)*p.nr_rise);
    if p.nr_on
        snr = max(st.ps(b)/(p.nr_bias*st.nn(b)) - 1, 0);
        gw  = max(sqrt(snr/(1+snr)), p.nr_gmin);
        if gw > st.nrg(b), al = p.nr_a_up; else al = p.nr_a_dn; end
        st.nrg(b) = al*st.nrg(b) + (1-al)*gw;
    else
        st.nrg(b) = 1;
    end
end
gt = 10.^(gcomp/20).*st.nrg;
if first, st.gprev = gt; end

ramp = (1:L)'/L;
Y = zeros(L,1);
for b = 1:nb
    Y = Y + X(:,b).*(st.gprev(b) + (gt(b) - st.gprev(b))*ramp);
end
st.gprev = gt;

% ---------------- 4) output protection (soft MPO) -------------------------
y = p.mpo_peak*tanh(Y/p.mpo_peak);

% ---------------- 5) update receiver-signal history for the AFC ----------
[yh, st.zh] = filter(p.afc_hp_b, p.afc_hp_a, y, st.zh);   % AFC reference = high-passed receiver signal
[yw, st.zy] = filter(p.afc_pwc, 1, yh, st.zy);             % ... and its pre-whitened version
st.ybuf  = [st.ybuf(L+1:end); yh];
st.ywbuf = [st.ywbuf(L+1:end); yw];

dg = [gcomp; 20*log10(st.nrg); afc_err_dB];
end
