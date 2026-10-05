function x = ha_make_test_speech(dur, p, seed)
%HA_MAKE_TEST_SPEECH  Deterministic speech-like signal (voiced syllables with formants, fricatives,
%  syllabic modulation and pauses) used when no real recording is available. Overall level = 65 dB SPL.
%  For the real deliverable use RECORDED speech (see ha_config.m).
if nargin < 3, seed = 7; end
ha_seed(seed);
fs = p.fs; n = round(dur*fs); x = zeros(n,1);
V = [700 1100 2500; 500 1800 2500; 300 2300 3000; 500  900 2500; 350  800 2400];   % a e i o u
t = 1;
while t < n - 0.4*fs
    len = round((0.12 + 0.12*rand)*fs);
    v   = V(1+floor(5*rand),:);
    f0  = 100 + 40*rand;
    tt  = (0:len-1)'/fs;
    f0t = f0*(1 + 0.1*sin(2*pi*3*tt));
    ph  = 2*pi*cumsum(f0t)/fs;
    src = zeros(len,1);
    for k = 1:30
        src = src + sin(k*ph)/k;                     % glottal-like harmonic series (-6 dB/oct)
    end
    seg = src;
    for i = 1:3                                       % formant resonators
        r = 0.97; th = 2*pi*v(i)/fs;
        seg = filter(1-r, [1 -2*r*cos(th) r^2], seg);
    end
    seg = seg/max(abs(seg)+1e-12) .* (0.5*(1-cos(2*pi*(0:len-1)'/len)));   % syllable envelope
    x(t:t+len-1) = x(t:t+len-1) + seg*(0.6 + 0.4*rand);
    t = t + len;
    if rand < 0.3                                     % fricative burst
        fl = round(0.09*fs); nz = randn(fl,1);
        nz = filter([1 -1],[1 -0.3], nz);             % high-pass tilt
        x(t:t+fl-1) = x(t:t+fl-1) + 0.15*nz.*hann_(fl);
        t = t + fl;
    end
    t = t + round((0.04 + 0.15*rand)*fs);             % pause
end
x = ha_scale_to_spl(x, 65, p);
end

function w = hann_(n)
w = 0.5*(1-cos(2*pi*(0:n-1)'/(n-1)));
end
