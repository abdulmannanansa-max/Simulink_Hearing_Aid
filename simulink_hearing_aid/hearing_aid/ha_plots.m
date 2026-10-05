function ha_plots(R, resdir)
%HA_PLOTS  Save the figures that document the verification (PNG in results/).
p = R.p; fs = p.fs;
if exist('OCTAVE_VERSION','builtin')
    try, graphics_toolkit('gnuplot'); catch, end
end
vis = 'off'; mk = @(n) figure('Visible', vis, 'Position', [100 100 900 600], 'Name', n, 'Renderer', 'painters');
sv  = @(name) ha_save_fig(gcf, fullfile(resdir, name));

% 1 prescription accuracy
mk('fit'); 
semilogx(p.audiogram_f, p.audiogram_HL, 'k-o', 'LineWidth', 1.5); hold on
semilogx(p.fcen, R.gain_target, 'b-s', 'LineWidth', 1.5);
semilogx(p.fcen, R.gain_meas, 'r--d', 'LineWidth', 1.5);
set(gca, 'XTick', [250 500 1000 2000 4000 8000], 'XTickLabel', {'250','500','1k','2k','4k','8k'});
grid on; xlabel('Frequency (Hz)'); ylabel('dB'); legend('Audiogram (dB HL)', 'NAL-R target gain', 'Simulated gain @65 dB SPL', 'Location', 'northwest');
title('Prescription: hearing loss, target gain, achieved gain'); sv('fig1_prescription');

% 2 compression I/O
mk('io'); cmap = lines(p.nb);
for b = 1:p.nb
    plot(R.io_in(:,b), R.io_out(:,b), '-o', 'Color', cmap(b,:), 'LineWidth', 1.3); hold on
end
plot([20 90], [20 90], 'k:'); grid on
xlabel('Input band level (dB SPL)'); ylabel('Output band level (dB SPL)');
legend(arrayfun(@(f) sprintf('%d Hz', round(f)), p.fcen, 'UniformOutput', false), 'Location', 'northwest');
title('Compression input/output curves (speech-shaped noise sweep)'); sv('fig2_compression_io');

% 3 noise reduction
mk('nr'); bar([R.nr(:,2) R.nr(:,3)]); grid on
set(gca, 'XTickLabel', arrayfun(@(v) sprintf('%+d dB in', v), R.nr(:,1), 'UniformOutput', false));
ylabel('Output SNR (dB)'); legend('NR off', 'NR on', 'Location', 'northwest'); title('Noise reduction: output SNR'); sv('fig3_noise_reduction');

% 4 feedback
mk('afc'); 
env = @(y) 10*log10(movmean_(filter(p.hb(5,:),1,y).^2, 800) + 1e-20) + p.cal_dB;
t = (0:numel(R.ref)-1)/fs;
plot(t, env(R.ref), 'k', t, env(R.yo), 'r', t, env(R.ya), 'b', 'LineWidth', 1.2); grid on
xlabel('Time (s)'); ylabel('Output level, 3-5 kHz band (dB SPL)'); legend('no feedback (reference)', 'feedback, AFC off (howls)', 'feedback, AFC on', 'Location', 'northwest');
title('Acoustic feedback: howling and its cancellation'); sv('fig4_feedback');
close all
end

function y = movmean_(x, n)
c = cumsum([0; x(:)]); y = zeros(size(x));
for i = 1:numel(x), a = max(1, i-n+1); y(i) = (c(i+1)-c(a))/(i-a+1); end
end

