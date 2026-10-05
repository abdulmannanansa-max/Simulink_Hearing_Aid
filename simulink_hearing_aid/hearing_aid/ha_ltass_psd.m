function d = ha_ltass_psd(f, overall_dB)
%HA_LTASS_PSD  Approximate long-term average speech spectrum (power density per Hz).
%  Octave-band levels are approximate (Byrne et al. 1994-style, ~65 dB SPL overall).
%  d integrates (sum(d)*df) to 10^(overall_dB/10).
f  = f(:);
fo = [125 250 500 1000 2000 4000 8000];
Lo = [ 52  57  62   58   52   47   41];
ff = max(f, 60);
Ld = interp1(log2(fo), Lo, log2(ff), 'linear', 'extrap') - 10*log10(0.7071*ff);
d  = 10.^(Ld/10);
df = f(2) - f(1);
d  = d * 10^(overall_dB/10) / (sum(d)*df);
end
