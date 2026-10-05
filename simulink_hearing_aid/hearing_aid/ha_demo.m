function ha_demo(speechFile)
%HA_DEMO  Make listenable files: what the wearer hears without and with the hearing aid.
%   Writes results/*.wav (levels normalised together so they can be compared) and a figure.
if nargin < 1, speechFile = ''; end
p = ha_design_all(); fs = p.fs;
sp = ha_load_speech(p, speechFile, 12);
nz = ha_make_ltass_noise(numel(sp)/fs, 60, p, 9); nz = nz(1:numel(sp));
scene = sp + nz;
y = ha_simulate(scene, p);
g = 0.8/max(abs(y));
if ~exist('results','dir'), mkdir('results'); end
audiowrite('results/demo_unaided.wav', g*scene, fs);
audiowrite('results/demo_aided.wav',   g*y,     fs);
fprintf('Wrote results/demo_unaided.wav and demo_aided.wav (same scaling).\n');
fprintf('Note: the aid adds ~%.0f dB overall; listen at a low volume first.\n', ...
    20*log10(sqrt(mean(y.^2))/sqrt(mean(scene.^2))));
end
