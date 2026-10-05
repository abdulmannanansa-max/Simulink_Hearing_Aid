% RUN_ME  One-click: verify the DSP, make demo audio, and (if Simulink is present) build + check the model.
%   Optional: RUN_ME('my_speech.wav') to use your own recording (mono/stereo, any rate).
function RUN_ME(speechFile)
if nargin < 1, speechFile = ''; end
addpath(fileparts(mfilename('fullpath')));
R = ha_verify(speechFile, false);           %#ok<NASGU>
ha_demo(speechFile);
if license('test', 'Simulink')
    ha_run_simulink(speechFile);
else
    disp('Simulink not available: skipped model build.');
end
end
