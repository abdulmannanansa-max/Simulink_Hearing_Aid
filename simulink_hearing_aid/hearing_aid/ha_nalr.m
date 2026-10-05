function G = ha_nalr(fq, af, HL)
%HA_NALR  NAL-R style target insertion gain (dB) at frequencies fq for audiogram (af, HL).
%  REIG = 0.15*H3FA + 0.31*HL + k(f)   (Byrne & Dillon, 1986). Verify against the reference if it matters.
ft = [250 500 750 1000 1500 2000 3000 4000 6000];
kt = [-17  -8  -3    1    1   -1   -2   -2   -2];
H3 = (hl_at(500, af, HL) + hl_at(1000, af, HL) + hl_at(2000, af, HL))/3;
G  = zeros(size(fq));
for i = 1:numel(fq)
    fk   = min(max(fq(i), ft(1)), ft(end));
    k    = interp1(log2(ft), kt, log2(fk), 'linear');
    G(i) = 0.15*H3 + 0.31*hl_at(fq(i), af, HL) + k;
end
G = max(G, 0);
end

function h = hl_at(f, af, HL)
h = interp1(log2(af), HL, log2(min(max(f, af(1)), af(end))), 'linear');
end
