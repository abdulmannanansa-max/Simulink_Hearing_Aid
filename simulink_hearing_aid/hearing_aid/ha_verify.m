function R = ha_verify(speechFile, quick)
%HA_VERIFY  Objective verification of the hearing-aid model. Prints PASS/FAIL, writes results/.
%   R = ha_verify()            full suite
%   R = ha_verify(file, true)  'quick' skips the slow added-stable-gain sweep
if nargin < 1, speechFile = ''; end
if nargin < 2, quick = false; end
if exist('OCTAVE_VERSION','builtin'), setenv('GNUTERM','dumb'); end
here = fileparts(mfilename('fullpath')); resdir = fullfile(here, 'results');
if ~exist(resdir,'dir'), mkdir(resdir); end
p   = ha_design_all();
fs  = p.fs; nb = p.nb; L = p.L;
rep = {}; R = struct(); npass = 0; nfail = 0;
    function say(varargin)
        s = sprintf(varargin{:}); disp(s); rep{end+1} = s; %#ok<AGROW>
    end
    function chk(name, ok, detail)
        if ok, tag = 'PASS'; npass = npass+1; else, tag = 'FAIL'; nfail = nfail+1; end
        say('  [%s] %s  --  %s', tag, name, detail);
    end
lvl = @(x) 10*log10(mean(x.^2)+1e-20) + p.cal_dB;
q0  = p; q0.fb_on = false; q0.afc_on = false; q0.nr_on = false;    % isolate the stage under test

say('=== Simulink hearing aid -- verification report ===');
say('audiogram (dB HL) @ %s Hz: %s', mat2str(p.audiogram_f), mat2str(p.audiogram_HL));

%% T0 codegen-literal consistency
% ha_design.m / ha_init_state.m / ha_core_frame.m hardcode L, nb, fir_order, afc_len and
% fb_len as literal constants, because MATLAB Coder needs array sizes provable at compile
% time and won't accept a value read from a struct field for that (see the comments in
% those files). If ha_params.m is ever edited without updating those literals, the Simulink
% model would silently run with mismatched buffer sizes -- catch that here, every run.
say('\nT0  Codegen-literal consistency (ha_params.m vs. the hardcoded Simulink-block literals)');
chk('p.L (frame size) matches the literal 32 in ha_core_frame.m / ha_init_state.m', p.L == 32, sprintf('p.L = %g', p.L));
chk('p.nb (band count) matches the literal 6 in ha_design.m / ha_init_state.m / ha_core_frame.m', p.nb == 6, sprintf('p.nb = %g', p.nb));
chk('p.fir_order matches the literal 192 in ha_design.m / ha_init_state.m', p.fir_order == 192, sprintf('p.fir_order = %g', p.fir_order));
chk('p.afc_len matches the literal 64 in ha_init_state.m / ha_core_frame.m', p.afc_len == 64, sprintf('p.afc_len = %g', p.afc_len));
chk('p.fb_len matches the literal 48 in ha_design.m', p.fb_len == 48, sprintf('p.fb_len = %g', p.fb_len));
chk('p.afc_pwc stays length 3 (ha_init_state.m sizes st.zy/st.zd from it)', numel(p.afc_pwc) == 3, sprintf('numel = %d', numel(p.afc_pwc)));
if nfail > 0
    error('ha_verify:codegenLiteralMismatch', ...
        'ha_params.m no longer matches the literal constants hardcoded for MATLAB Coder -- fix the T0 failures above before trusting anything else in this report.');
end

%% T1 filterbank perfect reconstruction & latency
say('\nT1  Filterbank & latency');
d = zeros(1, p.fir_order+1); d(p.fir_order/2+1) = 1;
prerr = max(abs(sum(p.hb,1) - d));
chk('perfect reconstruction (sum of bands = pure delay)', prerr < 1e-10, sprintf('max error %.2e', prerr));
lat = 1000*(p.fir_order/2 + L)/fs;
chk('total latency < 10 ms', lat < 10, sprintf('%.1f ms (filter %.1f + frame %.1f)', lat, 1000*p.fir_order/2/fs, 1000*L/fs));
R.latency_ms = lat;

%% T2 fitting accuracy: 65 dB speech-shaped noise -> band gain vs NAL-R target
say('\nT2  Prescription accuracy (65 dB SPL speech-shaped noise, compression on, NR/AFC off)');
x = ha_make_ltass_noise(8, 65, p, 3);
y = ha_simulate(x, q0);
skip = 2*fs;
Gm = ha_bandlevels(y, p, skip) - ha_bandlevels(x(1:numel(y)), p, skip);
err = Gm - p.tgt;
chk('measured gain within +/-3 dB of NAL-R target in all bands', max(abs(err)) <= 3, ...
    sprintf('max |error| = %.2f dB', max(abs(err))));
say('     target : %s dB', mat2str(round(p.tgt*10)/10));
say('     measured: %s dB', mat2str(round(Gm*10)/10));
R.gain_target = p.tgt; R.gain_meas = Gm;

%% T3 compression input/output behaviour
say('\nT3  Compression ratio (level sweep, per band)');
sweep = 40:5:85; Lin = zeros(numel(sweep), nb); Lout = Lin;
for i = 1:numel(sweep)
    xs = ha_make_ltass_noise(3, sweep(i), p, 11);
    ys = ha_simulate(xs, q0);
    Lin(i,:)  = ha_bandlevels(xs(1:numel(ys)), p, fs);
    Lout(i,:) = ha_bandlevels(ys, p, fs);
end
CRm = nan(1,nb);
for b = 1:nb
    sel = Lin(:,b) >= p.TK + 5;
    if sum(sel) >= 3
        c = polyfit(Lin(sel,b), Lout(sel,b), 1);
        CRm(b) = 1/c(1);
    end
end
ok = all(isnan(CRm) | abs(CRm - p.CR) <= 0.35);
chk('measured CR within +/-0.35 of programmed CR (bands with >=3 points above knee)', ok, ...
    sprintf('measured %s vs programmed %s', mat2str(round(CRm*100)/100), mat2str(p.CR)));
R.CR_meas = CRm; R.io_in = Lin; R.io_out = Lout;

%% T4 output limiting
say('\nT4  Maximum power output (MPO) protection');
tt = (0:round(3*fs)-1)'/fs;
xl = ha_scale_to_spl(sin(2*pi*1000*tt), 105, p);          % 105 dB SPL, 1 kHz tone
yl = ha_simulate(xl, q0);
pk = max(abs(yl));
chk('peak output never exceeds the MPO ceiling for a 105 dB SPL input', pk <= p.mpo_peak*1.0001, ...
    sprintf('peak %.3f <= ceiling %.3f  (%.1f dB SPL equiv. rms)', pk, p.mpo_peak, p.mpo_dB));

%% T5 noise reduction
say('\nT5  Noise reduction (speech + speech-shaped noise, shadow-filter SNR measurement)');
[sp, src] = ha_load_speech(p, speechFile, 12);
say('     speech source: %s', src);
R.nr = [];
qn = q0;
for snr_in = [0 5]
    nz = ha_make_ltass_noise(numel(sp)/fs, 65 - snr_in, p, 5); nz = nz(1:numel(sp));
    mix = sp + nz;
    qn.nr_on = false; [~, i0] = ha_simulate(mix, qn);
    qn.nr_on = true;  [~, i1] = ha_simulate(mix, qn);
    [s0, n0] = ha_shadow(sp, nz, i0.gains, p);
    [s1, n1] = ha_shadow(sp, nz, i1.gains, p);
    sel = fs+1:numel(s0);
    snr0 = 10*log10(sum(s0(sel).^2)/sum(n0(sel).^2));
    snr1 = 10*log10(sum(s1(sel).^2)/sum(n1(sel).^2));
    dn   = 10*log10(sum(n1(sel).^2)/sum(n0(sel).^2));
    ds   = 10*log10(sum(s1(sel).^2)/sum(s0(sel).^2));
    chk(sprintf('NR raises output SNR by >= 2 dB at %+d dB input SNR, speech loss <= 4 dB', snr_in), ...
        (snr1 - snr0) >= 2.0 && ds >= -4, ...
        sprintf('SNR %.1f -> %.1f dB (%+.1f);  noise %.1f dB, speech %.1f dB', snr0, snr1, snr1-snr0, dn, ds));
    R.nr = [R.nr; snr_in snr0 snr1 dn ds];
end

%% T6 acoustic feedback and adaptive cancellation
say('\nT6  Acoustic feedback: howling and adaptive feedback cancellation (AFC)');
sp8 = sp(1:min(numel(sp), 10*fs));
ref = ha_simulate(sp8, q0);                                   % no-feedback reference
tail = numel(ref)-4*fs+1:numel(ref);
dev = @(y) max(ha_bandlevels(y(tail), p, 0) - ha_bandlevels(ref(tail), p, 0));   % worst band excess (dB)
qf = p; qf.nr_on = false;
qf.afc_on = false; [yo, ~]  = ha_simulate(sp8, qf);
qf.afc_on = true;  [ya, ia] = ha_simulate(sp8, qf);
howl_off = dev(yo); howl_on = dev(ya);
chk('without AFC the loop howls (a band >= +6 dB above the no-feedback reference)', howl_off >= 6, ...
    sprintf('worst band %+.1f dB', howl_off));
chk('with AFC the loop is stable (all bands within +3 dB of reference)', howl_on <= 3, ...
    sprintf('worst band %+.1f dB', howl_on));
% (informational) cancellation depth of the true feedback signal above 1.5 kHz over the last 4 s
ydl  = [zeros(L,1); ya(1:end-L)];
fbt  = filter(p.fb_h, 1, ydl);
fbe  = filter(ia.state.w, 1, filter(p.afc_hp_b, p.afc_hp_a, ydl));
hf   = sum(p.hb(4:6,:), 1);
ft_  = filter(hf,1,fbt); fr_ = filter(hf,1,fbt-fbe);
depth = 10*log10(sum(ft_(tail).^2)/sum(fr_(tail).^2));
say('     (info) feedback-signal cancellation depth above 1.5 kHz: %.1f dB (speech-correlation bias limits this)', depth);
% transparency: with NO feedback present the AFC must not eat/colour the speech
qt = q0; qt.afc_on = true; yt = ha_simulate(sp8, qt);
tr = 10*log10(sum((yt-ref).^2)/sum(ref.^2));
chk('AFC is transparent when there is no feedback (output change < -10 dB re signal)', tr < -10, sprintf('%.1f dB', tr));
R.howl_off = howl_off; R.howl_on = howl_on; R.depth = depth; R.transparency = tr;
R.yo = yo; R.ya = ya; R.ref = ref;

if ~quick
    say('     added stable gain (ASG): scale the feedback path until the loop howls, with and without AFC');
    sw = -30:5:10; stab = false(2, numel(sw));
    for k = 1:numel(sw)
        for a = 0:1
            qs = qf; qs.afc_on = logical(a); qs.fb_h = p.fb_h*10^(sw(k)/20);
            stab(a+1,k) = dev(ha_simulate(sp8, qs)) < 3;
        end
    end
    lim = @(v) sw(find(v,1,'last'));
    if any(stab(1,:)) && any(stab(2,:))
        asg = lim(stab(2,:)) - lim(stab(1,:));
        chk('AFC gives added stable gain >= 10 dB', asg >= 10, ...
            sprintf('max stable path gain re nominal: %+d dB (AFC off) vs %+d dB (AFC on) => ASG = %d dB', lim(stab(1,:)), lim(stab(2,:)), asg));
        R.asg = asg;
    else
        chk('AFC gives added stable gain >= 10 dB', false, 'sweep range did not bracket the stability limit');
    end
    R.sweep = sw; R.stab = stab;
end

%% T7 audibility (simplified SII-like index) -- did the aid actually restore audibility?
say('\nT7  Aided vs unaided audibility of 65 dB SPL speech (simplified SII-like index)');
ret  = interp1(log2([250 500 1000 2000 4000 8000]), [25.5 11.5 7 9 9.5 13], log2(p.fcen), 'linear', 'extrap'); % ~ISO 389-1 TDH-39
thr  = interp1(log2(p.audiogram_f), p.audiogram_HL, log2(min(max(p.fcen,250),8000)), 'linear') + ret;
w    = [0.07 0.14 0.22 0.27 0.20 0.10];
AI   = @(Lb) sum(w .* min(max((Lb + 15 - thr)/30, 0), 1));
Lun  = p.Lref;                 Lai = p.Lref + Gm;
ai_un = AI(Lun); ai_ai = AI(Lai);
chk('audibility index improves by >= 0.20 with the aid', ai_ai - ai_un >= 0.20, ...
    sprintf('unaided %.2f -> aided %.2f', ai_un, ai_ai));
R.ai = [ai_un ai_ai]; R.thr = thr;

%% summary + figures
say('\nSUMMARY: %d passed, %d failed', npass, nfail);
R.npass = npass; R.nfail = nfail; R.p = p;
fid = fopen(fullfile(resdir,'verification_report.txt'),'w');
for i = 1:numel(rep), fprintf(fid, '%s\n', rep{i}); end
fclose(fid);
try
    csvwrite(fullfile(resdir,'data_gain.csv'), [p.fcen(:) R.gain_target(:) R.gain_meas(:) p.audiogram_HL(:)]);
    csvwrite(fullfile(resdir,'data_io_in.csv'), R.io_in);  csvwrite(fullfile(resdir,'data_io_out.csv'), R.io_out);
    csvwrite(fullfile(resdir,'data_nr.csv'), R.nr);
    csvwrite(fullfile(resdir,'data_fb.csv'), [R.ref(:) R.yo(:) R.ya(:)]);
    if isfield(R,'sweep'), csvwrite(fullfile(resdir,'data_asg.csv'), [R.sweep(:) R.stab']); end
catch
end
try, ha_plots(R, resdir); catch err, disp(['(plots skipped: ' err.message ')']); end
end
