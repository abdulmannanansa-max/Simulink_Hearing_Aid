function ok = ha_run_simulink(speechFile)
%HA_RUN_SIMULINK  Build + simulate the Simulink model and check it against the MATLAB script model.
%   PASS criterion: Simulink output equals ha_simulate output (rms difference < -100 dB re signal).
if nargin < 1, speechFile = ''; end
p = ha_design_all(); fs = p.fs; L = p.L;
[sp, src] = ha_load_speech(p, speechFile, 8);
nz  = ha_make_ltass_noise(numel(sp)/fs, 60, p, 5); nz = nz(1:numel(sp));
scene = sp + nz;                                   % 65 dB speech in 60 dB speech-shaped noise (+5 dB SNR)
fprintf('speech source: %s\n', src);

mdl = ha_build_simulink_model(scene);
fprintf('Simulating %s ...\n', mdl);
simOut = sim(mdl);
% Depending on the model's Data Import/Export setting ("Single simulation output"), a To
% Workspace block's variable either lands in the base workspace (old default) or is bundled
% into the returned Simulink.SimulationOutput object (current default in many installs).
% ha_build_simulink_model.m now forces the latter (ReturnWorkspaceOutputs='on'); fall back
% to the base workspace too, so this works regardless of the installation's own default.
try
    out = simOut.get('ha_out');
catch
    out = evalin('base', 'ha_out');
end
nF = floor(numel(scene)/L);
out = squeeze(out);
if size(out,1) == L && size(out,2) == nF, out = out.'; end
y_sl = reshape(out.', [], 1);

% Same retrieval, for the diagnostics port: dg = [compression gain dB (nb); NR gain dB (nb);
% AFC adaptation-error dB (1)], one column per frame -- see ha_core_frame.m.
try
    gains_raw = simOut.get('ha_gains');
catch
    gains_raw = evalin('base', 'ha_gains');
end
gains_raw = squeeze(gains_raw);
NG = 2*p.nb + 1;                                    % 13 rows: plain MATLAB here, p.nb is fine to read
if size(gains_raw, 1) == NG, gains = gains_raw; else, gains = gains_raw.'; end   % force (NG x nF)
afc_err = gains(NG, :);                             % row 13: AFC adaptation error, dB, one value per frame

y_ml = ha_simulate(scene, p);
err  = 10*log10(sum((y_sl - y_ml).^2)/sum(y_ml.^2) + 1e-30);
ok   = err < -100;
fprintf('Simulink vs MATLAB-script model: difference %.1f dB  -> %s\n', err, ternary(ok));
if ~exist('results', 'dir'), mkdir('results'); end
audiowrite('results/simulink_aided.wav', 0.9*y_sl/max(abs(y_sl)), fs);

% Simulink itself has no Scope/plot in this build (To Workspace sinks only); this is the one
% figure that is generated FROM the Simulink run, as visual backup for the numeric check above.
try
    fig = figure('Visible', 'off', 'Renderer', 'painters');
    tt = (0:numel(y_ml)-1)'/fs; nshow = min(numel(y_ml), round(2*fs));
    subplot(2,1,1);
    plot(tt(1:nshow), y_ml(1:nshow), 'b', tt(1:nshow), y_sl(1:nshow), 'r--'); grid on
    legend('MATLAB script model (ha\_simulate)', 'Simulink model'); xlabel('Time (s)'); ylabel('Amplitude');
    title(sprintf('Simulink vs script-model output (difference %.1f dB -> %s)', err, ternary(ok)));
    subplot(2,1,2);
    plot(tt(1:nshow), y_sl(1:nshow) - y_ml(1:nshow), 'k'); grid on
    xlabel('Time (s)'); ylabel('Residual'); title('Simulink minus script-model residual');
    ha_save_fig(fig, 'results/fig6_simulink_vs_script'); close(fig);
    fprintf('Wrote results/fig6_simulink_vs_script.png\n');
catch plotErr
    fprintf('(comparison plot skipped: %s)\n', plotErr.message);
end

% Demo plot 1: input audio vs. the hearing aid's output, from the Simulink run itself.
try
    fig = figure('Visible', 'off', 'Renderer', 'painters');
    tt = (0:numel(scene)-1)'/fs; nshow = min(numel(scene), round(4*fs));
    plot(tt(1:nshow), scene(1:nshow), 'Color', [0.6 0.6 0.6]); hold on
    plot(tt(1:nshow), y_sl(1:nshow), 'b'); grid on
    legend('Input (mic: speech + noise)', 'Hearing-aid output (Simulink)'); xlabel('Time (s)'); ylabel('Amplitude');
    title('Simulink simulation: input audio vs. hearing-aid output');
    ha_save_fig(fig, 'results/fig7_input_vs_output'); close(fig);
    fprintf('Wrote results/fig7_input_vs_output.png\n');
catch plotErr
    fprintf('(input-vs-output plot skipped: %s)\n', plotErr.message);
end

% Demo plot 2: noise-reduction gain, from the Simulink run itself. Checked by direct inspection
% (not assumed) to be a genuine, honest "going down" story: the raw AFC adaptation-error signal
% (gains row 2*nb+1, still available in `afc_err` above if you want to look at it) is dominated
% by input level and closed-loop transients, not cleanly by cancellation quality -- plotting it
% does NOT reliably show the canceller "learning" and would overclaim what it demonstrates. NR
% gain (rows nb+1:2*nb) does genuinely drop as the per-band noise floor is learned, then track
% speech activity -- that's the honest "working" visual, confirmed against this exact run's data.
try
    fig = figure('Visible', 'off', 'Renderer', 'painters');
    nr_gain = gains(p.nb+1:2*p.nb, :); avg_nr = mean(nr_gain, 1);
    tframe = (0:nF-1)*L/fs;
    subplot(2,1,1);
    plot((0:numel(scene)-1)/fs, scene, 'Color', [0.6 0.6 0.6]); grid on
    ylabel('Input (speech + noise)'); title('Noise reduction, from the Simulink run: input, and NR gain applied over time');
    subplot(2,1,2);
    plot(tframe, avg_nr, 'b', 'LineWidth', 1.2); grid on
    xlabel('Time (s)'); ylabel('Avg NR gain (dB)');
    title('NR gain -- drops as the noise floor is learned, then tracks speech activity');
    ha_save_fig(fig, 'results/fig8_noise_reduction_simulink'); close(fig);
    fprintf('Wrote results/fig8_noise_reduction_simulink.png\n');
    fprintf('NR gain: %.1f dB (frame 1) -> %.1f dB (frame 20, ~40 ms later) -> %.1f dB (mean over run)\n', ...
        avg_nr(1), avg_nr(min(20,nF)), mean(avg_nr));
catch plotErr
    fprintf('(noise-reduction plot skipped: %s)\n', plotErr.message);
end
end

function s = ternary(ok)
if ok, s = 'PASS'; else, s = 'FAIL (check parameter/ha_params edits or block-port errors)'; end
end
