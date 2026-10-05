function [ys, yn] = ha_shadow(sp, nz, gains, p)
%HA_SHADOW  Apply the time-varying band gains a run computed on (speech+noise) separately to the
%  speech and to the noise ("shadow filtering"), so the SNR at the OUTPUT can be measured.
%  Valid when the MPO limiter is in its linear region (checked by the caller).
L = p.L; nb = p.nb; nF = size(gains, 2);
gt = 10.^((gains(1:nb,:) + gains(nb+1:2*nb,:))/20);
ramp = (1:L)'/L;
ys = zeros(nF*L,1); yn = ys;
for b = 1:nb
    xs = filter(p.hb(b,:), 1, sp(1:nF*L));
    xn = filter(p.hb(b,:), 1, nz(1:nF*L));
    gprev = gt(b,1);
    for m = 1:nF
        idx = (m-1)*L + (1:L);
        g = gprev + (gt(b,m) - gprev)*ramp;
        ys(idx) = ys(idx) + xs(idx).*g;
        yn(idx) = yn(idx) + xn(idx).*g;
        gprev = gt(b,m);
    end
end
end
