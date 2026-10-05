function y = ha_scale_to_spl(x, spl_dB, p)
%HA_SCALE_TO_SPL  Scale signal so its overall rms corresponds to spl_dB SPL.
x = x(:);
y = x * 10^((spl_dB - p.cal_dB)/20) / sqrt(mean(x.^2));
end
