function st = ha_init_state(p)
%HA_INIT_STATE  Initial state of the hearing-aid core.
%  CODEGEN NOTE: literal constants, not read from p -- see ha_core_frame.m for why. If you
%  change these in ha_params.m, update the matching literals here too (ha_verify.m checks).
nb = 6;    % must equal ha_params p.nb
N  = 192;  % must equal ha_params p.fir_order
Na = 64;   % must equal ha_params p.afc_len
L  = 32;   % must equal ha_params p.L
st.zi    = zeros(N, nb);
st.env   = 1e-12*ones(nb,1);
st.ps    = 1e-12*ones(nb,1);
st.nn    = ones(nb,1);
st.nrg   = ones(nb,1);
st.gprev = ones(nb,1);
st.init  = 0;
st.w     = zeros(Na,1);
st.ybuf  = zeros(Na+L,1);
st.ywbuf = zeros(Na+L,1);
K = numel(p.afc_pwc) - 1;
st.zy = zeros(K,1);
st.zd = zeros(K,1);
st.zh = zeros(2,1);
end
