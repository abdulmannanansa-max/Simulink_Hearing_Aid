function p = ha_design(p)
%HA_DESIGN  Derive filterbank, fitting gains and time constants from ha_params.
%  CODEGEN NOTE: N and nb below are literal constants, not read from p, even though p carries
%  the same numbers. MATLAB Coder requires every array's size to be provable at compile time;
%  a value read from a struct field is treated as ordinary runtime data (even one that is
%  numerically always 192/6), so using it to size an array -- zeros(nb,N+1), a colon range
%  that builds an array, etc. -- makes Coder mark the result "unbounded variable-size", which
%  later blocks (e.g. Unit Delay) then reject. See ha_core_frame.m for the same note in full.
%  If you change fir_order or nb in ha_params.m, update these two literals to match --
%  ha_verify.m asserts they still agree and errors loudly if they drift.
N  = 192;  % must equal ha_params p.fir_order
nb = 6;    % must equal ha_params p.nb
fs = p.fs; L = p.L; Tf = L/fs;    % pure arithmetic from here, not used to size an array: fine from p

% ---- perfect-reconstruction FIR filterbank (windowed-sinc low-pass differences)
n = (0:N) - N/2;
w = 0.54 - 0.46*cos(2*pi*(0:N)/N);
lp = zeros(nb-1, N+1);
for k = 1:nb-1
    fc = p.edges(k)/(fs/2);
    x  = fc*n;
    s  = ones(size(x));
    nz = (x ~= 0);
    s(nz) = sin(pi*x(nz))./(pi*x(nz));
    lp(k,:) = fc*s.*w;
end
hb = zeros(nb, N+1);
hb(1,:) = lp(1,:);
for k = 2:nb-1
    hb(k,:) = lp(k,:) - lp(k-1,:);
end
dl = zeros(1, N+1); dl(N/2+1) = 1;
hb(nb,:) = dl - lp(nb-1,:);
p.hb = hb;
p.delay_samples = N/2;

% ---- fitting: NAL-R target at band centres, converted to compression gains
e    = [0 p.edges p.fs/2];
fcen = sqrt(max(e(1:end-1),1).*e(2:end));
fcen(1) = 250;
p.fcen = fcen;
p.tgt  = ha_nalr(fcen, p.audiogram_f, p.audiogram_HL);        % dB gain for 65 dB speech

f  = (0:4:8000)'; df = 4;
H  = hb * exp(-1i*2*pi*(0:N)'*f'/fs);                          % nb x nf
dens = ha_ltass_psd(f, 65);
Lref = 10*log10((abs(H).^2) * dens * df);                       % dB SPL of 65 dB speech in each band
p.Lref = Lref(:).';
p.cs   = 1 - 1./p.CR;                                            % gain-reduction slope above knee
p.G0   = min(p.tgt + p.cs.*max(p.Lref - p.TK, 0), p.Gmax);      % gain below the knee

% ---- time constants -------------------------------------------------------
p.a_att   = exp(-Tf/p.att_s);
p.a_rel   = exp(-Tf/p.rel_s);
p.nr_as   = exp(-Tf/p.nr_tau_pow);
p.nr_a_up = exp(-Tf/p.nr_tau_up);
p.nr_a_dn = exp(-Tf/p.nr_tau_dn);
p.nr_rise = 10^(p.nr_rise_dBps*Tf/10);
p.nr_gmin = 10^(p.nr_gmin_dB/20);
p.mpo_peak = sqrt(2)*10^((p.mpo_dB - p.cal_dB)/20);

% ---- AFC high-pass (2nd-order Butterworth, bilinear transform)
K  = tan(pi*p.afc_hp_fc/fs);  nrm = 1/(1 + sqrt(2)*K + K^2);
p.afc_hp_b = [1 -2 1]*nrm;
p.afc_hp_a = [1, 2*(K^2-1)*nrm, (1 - sqrt(2)*K + K^2)*nrm];

% ---- synthetic acoustic feedback path (plant) ----------------------------
NFB = 48;   % must equal ha_params p.fb_len -- literal for the same codegen reason as N, nb above
k   = (0:NFB-1)';
h  = exp(-k/10).*sin(2*pi*p.fb_fc*k/fs + 0.6);
Hf = abs(fft(h, 1024));
p.fb_h = h*10^(p.fb_peak_dB/20)/max(Hf);
end
