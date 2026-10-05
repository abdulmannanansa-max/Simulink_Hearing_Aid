function x = ha_make_ltass_noise(dur, spl_dB, p, seed)
%HA_MAKE_LTASS_NOISE  Stationary speech-shaped noise (long-term average speech spectrum) at spl_dB SPL.
if nargin < 4, seed = 1; end
ha_seed(seed);
n = round(dur*p.fs); n = n + mod(n,2);
X = fft(randn(n,1));
f = (0:n/2)'*p.fs/n;
mag = sqrt(ha_ltass_psd(f, 65));
H = [mag; flipud(mag(2:end-1))];
x = real(ifft(X .* H));
x = ha_scale_to_spl(x, spl_dB, p);
end
