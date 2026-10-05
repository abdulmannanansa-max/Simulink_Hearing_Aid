function Lb = ha_bandlevels(x, p, skip)
%HA_BANDLEVELS  Band levels (dB SPL) of a signal through the analysis filterbank.
if nargin < 3, skip = 0; end
Lb = zeros(1, p.nb);
for b = 1:p.nb
    xb = filter(p.hb(b,:), 1, x);
    xb = xb(skip+1:end);
    Lb(b) = 10*log10(mean(xb.^2) + 1e-20) + p.cal_dB;
end
end
