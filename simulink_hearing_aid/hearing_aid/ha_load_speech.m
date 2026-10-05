function [x, src] = ha_load_speech(p, speechFile, dur)
%HA_LOAD_SPEECH  Load real speech (preferred) or fall back to the synthetic generator.
%   Tries: the file you give, then MATLAB's bundled 'Counting-16-44p1-mono-15secs.wav', then synthetic.
%   Output is resampled to p.fs and scaled to 65 dB SPL.
if nargin < 2, speechFile = ''; end
if nargin < 3, dur = 12; end
cands = {};
if ~isempty(speechFile), cands{end+1} = speechFile; end
cands{end+1} = 'Counting-16-44p1-mono-15secs.wav';
x = []; src = 'synthetic';
for i = 1:numel(cands)
    try
        [s, fs0] = audioread(cands{i});
        s = mean(s, 2);
        [pp, qq] = rat(p.fs/fs0, 1e-6);
        s = resample(s, pp, qq);
        s = s(1:min(numel(s), round(dur*p.fs)));
        x = ha_scale_to_spl(s, 65, p); src = cands{i};
        return
    catch
    end
end
x = ha_make_test_speech(dur, p);
end
