function ha_seed(s)
%HA_SEED  Reproducible random numbers in both MATLAB and Octave.
if exist('OCTAVE_VERSION','builtin')
    randn('state', s); rand('state', s);
else
    rng(s);
end
end
