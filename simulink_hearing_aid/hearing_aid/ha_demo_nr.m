function ha_demo_nr(speechFile, dur)
%HA_DEMO_NR  A genuine, verified "going down" demonstration -- but of NOISE REDUCTION, not AFC.
%  (See the note in ha_core_frame.m / README.md: the raw AFC adaptation-error signal is
%  dominated by input level and closed-loop transients, not cleanly by cancellation quality,
%  so it does NOT make a convincing "error descends -> feedback learned" demo on its own --
%  verified by direct inspection, not assumed. Noise reduction gain, by contrast, genuinely
%  and reliably drops as the noise-floor estimator locks on, then tracks speech activity.)
%  Uses the MATLAB *script* model -- no Simulink needed for this one.
if nargin < 1, speechFile = ''; end
if nargin < 2, dur = 10; end
p = ha_design_all(); fs = p.fs;
sp = ha_load_speech(p, speechFile, dur);
nz = ha_make_ltass_noise(numel(sp)/fs, 60, p, 9); nz = nz(1:numel(sp));
mix = sp + nz;
[y, info] = ha_simulate(mix, p);
nr_gain = info.gains(p.nb+1:2*p.nb, :);     % dB, per band, per frame
avg_nr  = mean(nr_gain, 1);
nF = numel(avg_nr); tframe = (0:nF-1)*p.L/fs;
tt = (0:numel(mix)-1)/fs;
if ~exist('results','dir'), mkdir('results'); end
try
    fig = figure('Visible','off', 'Renderer', 'painters');
    subplot(2,1,1);
    plot(tt, mix, 'Color', [0.6 0.6 0.6]); grid on
    ylabel('Input (speech + noise)'); title('Noise reduction: input, and NR gain applied over time');
    subplot(2,1,2);
    plot(tframe, avg_nr, 'b', 'LineWidth', 1.2); grid on
    xlabel('Time (s)'); ylabel('Avg NR gain (dB)');
    title('Noise-reduction gain -- drops as the noise floor is learned, then tracks speech activity');
    ha_save_fig(fig, 'results/fig9_noise_reduction_gain'); close(fig);
    fprintf('Wrote results/fig9_noise_reduction_gain.png\n');
catch e
    fprintf('(plot skipped: %s)\n', e.message);
end
fprintf('NR gain: %.1f dB (frame 1) -> %.1f dB (frame 20, ~40 ms later) -> %.1f dB (mean over whole clip)\n', ...
    avg_nr(1), avg_nr(min(20,nF)), mean(avg_nr));
if exist('results','dir')
    csvwrite('results/data_nr_demo.csv', [tframe(:) avg_nr(:)]);
end
end
