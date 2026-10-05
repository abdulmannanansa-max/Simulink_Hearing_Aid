function p = ha_params()
%HA_PARAMS  All tunable settings of the Simulink hearing aid (numeric only, codegen-safe).
%  Edit the audiogram and any parameter here, then re-run. Everything else derives from this.
%
%  CODEGEN RULE THIS FILE OBEYS: MATLAB Coder fixes a struct's field list, sizes and classes
%  the instant any field of it is READ, and refuses to add a new field name afterwards ("...
%  addition of new fields after a structure has been read or used"). Even reading an
%  already-existing field of p to *size a new placeholder* counts as a read. So this file
%  computes everything into plain local variables first and touches "p" only with a single,
%  unbroken run of "p.field = <local variable>" assignments at the very end -- p is never
%  read anywhere in this function, only written.

% ---- signal / framing --------------------------------------------------
fs        = 16000;            % Hz, sample rate (speech bandwidth 8 kHz)
L         = 32;                % samples per frame (2 ms)  -> low latency
cal_dB    = 115;               % dB SPL that a digital rms of 1.0 represents (calibration)

% ---- hearing loss (audiogram, dB HL) -----------------------------------
% Illustrative moderate sloping sensorineural loss. REPLACE with your own / a Bisgaard profile.
audiogram_f  = [250 500 1000 2000 4000 8000];
audiogram_HL = [ 30  35   45   55   65   70];

% ---- multi-band filterbank ---------------------------------------------
edges     = [350 750 1500 3000 5000];   % Hz, crossover frequencies -> 6 bands
nb        = 6;
fir_order = 192;                        % linear-phase FIR order (even) -> 6 ms group delay

% ---- wide dynamic range compression (WDRC), per band --------------------
CR        = [1.5 1.7 2.0 2.2 2.5 2.5];  % compression ratios
TK        = 40;                         % dB SPL (band level) compression knee
TE        = 25;                         % dB SPL expansion threshold (mic-noise squelch)
exp_slope = 0.5;                        % dB gain lost per dB below TE
Gmax      = 50;                         % dB, gain ceiling
att_s     = 0.005;                      % s attack time
rel_s     = 0.060;                      % s release time

% ---- noise reduction (per-band minimum-statistics Wiener-style) ---------
nr_on        = true;
nr_gmin_dB   = -9;                      % max attenuation
nr_bias      = 1.5;                     % min-tracker bias compensation (power)
nr_rise_dBps = 3;                       % noise-floor rise rate, dB/s
nr_tau_pow   = 0.020;                   % s power smoothing
nr_tau_up    = 0.010;                   % s gain increase (fast, protects speech onsets)
nr_tau_dn    = 0.050;                   % s gain decrease (slow, avoids warble)

% ---- output protection (MPO) -------------------------------------------
mpo_dB    = 105;                        % dB SPL maximum power output (sine rms equiv.)

% ---- feedback: physical plant + adaptive canceller ---------------------
fb_on      = true;                      % include the acoustic feedback path
fb_len     = 48;                        % taps of the feedback path
fb_fc      = 3500;                      % Hz, resonance of the feedback path
fb_peak_dB = -22;                       % peak |H_fb| (dB). -22 dB vs. ~28 dB HA gain => unstable w/o AFC
afc_on     = true;
afc_len    = 64;                        % NLMS taps
afc_mu     = 0.002;                     % NLMS step size
afc_hp_fc  = 1500;                      % Hz, AFC operates above this frequency (howling region)
afc_pwc    = [1 -1.8 0.81];             % pre-whitening / HF-emphasis FIR: decorrelates speech
afc_leak   = 1e-5;                      % NLMS leakage per sample (bounds the filter norm)
afc_delta  = 1e-5;                      % NLMS regularisation. Must be large enough that true
                                         % digital silence (refw'*refw -> 0) can't blow up the
                                         % step mu/(refw'*refw+delta) into instability -- found by
                                         % direct reproduction, not assumed: 1e-8 measurably failed
                                         % transparency (AFC changing the output with NO feedback
                                         % present) on a signal with real silence gaps; 1e-5 passes
                                         % with margin and is still ~60x below typical active-signal
                                         % reference power, so normal-condition adaptation is barely
                                         % affected.

% ---- misc ---------------------------------------------------------------
comp_on = true;                         % false => linear NAL-R gain (for comparison)

% ---- derived-field sizes, computed from the LOCAL variables above, not from p -----------
NB  = nb;                               % number of bands
NF  = fir_order + 1;                    % filterbank taps
NFB = fb_len;                           % feedback-path taps

% =====================================================================================
% From here on: WRITE ONLY. Every field p will ever have -- base parameters and the
% derived placeholders ha_design() fills in for real -- is assigned exactly once, below,
% from local variables only. Nothing above this point reads "p"; nothing below reads it either.
% =====================================================================================
p.fs = fs;  p.L = L;  p.cal_dB = cal_dB;
p.audiogram_f = audiogram_f;  p.audiogram_HL = audiogram_HL;
p.edges = edges;  p.nb = nb;  p.fir_order = fir_order;
p.CR = CR;  p.TK = TK;  p.TE = TE;  p.exp_slope = exp_slope;  p.Gmax = Gmax;
p.att_s = att_s;  p.rel_s = rel_s;
p.nr_on = nr_on;  p.nr_gmin_dB = nr_gmin_dB;  p.nr_bias = nr_bias;  p.nr_rise_dBps = nr_rise_dBps;
p.nr_tau_pow = nr_tau_pow;  p.nr_tau_up = nr_tau_up;  p.nr_tau_dn = nr_tau_dn;
p.mpo_dB = mpo_dB;
p.fb_on = fb_on;  p.fb_len = fb_len;  p.fb_fc = fb_fc;  p.fb_peak_dB = fb_peak_dB;
p.afc_on = afc_on;  p.afc_len = afc_len;  p.afc_mu = afc_mu;  p.afc_hp_fc = afc_hp_fc;
p.afc_pwc = afc_pwc;  p.afc_leak = afc_leak;  p.afc_delta = afc_delta;
p.comp_on = comp_on;

% derived-field PLACEHOLDERS -- ha_design() overwrites these with real values; it never
% introduces a field name that is not already listed here.
p.hb             = zeros(NB, NF);   % filterbank impulse responses
p.delay_samples  = 0;               % filterbank group delay, samples
p.fcen           = zeros(1, NB);    % band centre frequencies, Hz
p.tgt            = zeros(1, NB);    % NAL-R target insertion gain, dB
p.Lref           = zeros(1, NB);    % band level of 65 dB SPL speech, dB SPL
p.cs             = zeros(1, NB);    % compression slope (1 - 1/CR)
p.G0             = zeros(1, NB);    % gain below the compression knee, dB
p.a_att          = 0;               % envelope attack coefficient
p.a_rel          = 0;               % envelope release coefficient
p.nr_as          = 0;               % NR power-smoothing coefficient
p.nr_a_up        = 0;               % NR gain rise coefficient
p.nr_a_dn        = 0;               % NR gain fall coefficient
p.nr_rise        = 0;               % NR noise-floor rise factor per frame
p.nr_gmin        = 0;               % NR gain floor (linear)
p.mpo_peak       = 0;               % MPO ceiling (linear peak)
p.afc_hp_b       = zeros(1,3);      % AFC reference high-pass, numerator
p.afc_hp_a       = zeros(1,3);      % AFC reference high-pass, denominator
p.fb_h           = zeros(NFB, 1);   % synthetic acoustic feedback path
end
