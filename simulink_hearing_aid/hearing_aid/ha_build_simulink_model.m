function mdl = ha_build_simulink_model(scene, mdl)
%HA_BUILD_SIMULINK_MODEL  Programmatically build the closed-loop hearing-aid model in Simulink.
%   Requires: Simulink only (no DSP System Toolbox). Frame-based: one 32-sample vector per time step.
%
%   Signal flow (all signals are 32x1 frames):
%     Scene --> MicSum --> HACore --> Out (To Workspace)
%                 ^           |----> Gains (To Workspace)
%                 |           v
%              FBPath <-- FBDelay (1 frame)        <- acoustic feedback loop
%
%   HACore  = MATLAB Function block calling ha_core_frame (filterbank, WDRC, noise reduction, AFC, MPO)
%   FBPath  = MATLAB Function block: synthetic ear-canal/vent feedback path (ha_params: fb_*)
if nargin < 2, mdl = 'simulink_hearing_aid'; end
p  = ha_design_all(); L = p.L; Tf = L/p.fs; nF = floor(numel(scene)/L);
u  = reshape(scene(1:nF*L), L, nF).';
assignin('base', 'ha_scene', [(0:nF-1)'*Tf, u]);

if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl); open_system(mdl);
Ts = sprintf('%.12g', Tf);

add_block('simulink/Sources/From Workspace', [mdl '/Scene'], 'VariableName', 'ha_scene', ...
    'SampleTime', Ts, 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value', ...
    'Position', [30 90 130 130]);
add_block('simulink/Math Operations/Sum', [mdl '/MicSum'], 'Inputs', '++', 'Position', [190 95 220 125]);
add_mfb(mdl, 'HACore', [ ...
    'function [y, dg] = HACore(d)\n' ...
    'persistent st p\n' ...
    'if isempty(st)\n' ...
    '    p  = ha_design_all();\n' ...
    '    st = ha_init_state(p);\n' ...
    'end\n' ...
    '[y, st, dg] = ha_core_frame(d, st, p);\n' ...
    'end\n'], [280 80 400 140]);
add_block('simulink/Discrete/Unit Delay', [mdl '/FBDelay'], 'InitialCondition', '0', 'SampleTime', Ts, ...
    'Position', [470 200 520 240], 'Orientation', 'left');
add_mfb(mdl, 'FBPath', [ ...
    'function fb = FBPath(yd)\n' ...
    'persistent zi h\n' ...
    'if isempty(zi)\n' ...
    '    p  = ha_design_all();\n' ...
    '    h  = p.fb_h * double(p.fb_on);\n' ...
    '    zi = zeros(numel(h)-1, 1);\n' ...
    'end\n' ...
    '[fb, zi] = filter(h, 1, yd, zi);\n' ...
    'end\n'], [280 195 400 255]);
set_param([mdl '/FBPath'], 'Orientation', 'left');
add_block('simulink/Sinks/To Workspace', [mdl '/Out'],   'VariableName', 'ha_out',   'SaveFormat', 'Array', 'Position', [520 80 600 110]);
add_block('simulink/Sinks/To Workspace', [mdl '/Gains'], 'VariableName', 'ha_gains', 'SaveFormat', 'Array', 'Position', [520 130 600 160]);

add_line(mdl, 'Scene/1',   'MicSum/1');
add_line(mdl, 'MicSum/1',  'HACore/1');
add_line(mdl, 'HACore/1',  'Out/1');
add_line(mdl, 'HACore/2',  'Gains/1');
add_line(mdl, 'HACore/1',  'FBDelay/1');
add_line(mdl, 'FBDelay/1', 'FBPath/1');
add_line(mdl, 'FBPath/1',  'MicSum/2');

set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', Ts, 'StopTime', sprintf('%.12g', (nF-1)*Tf));
% Force "single simulation output": To Workspace data comes back attached to the object
% sim() returns (simOut.get('ha_out')), rather than depending on this installation's own
% Data Import/Export default for where such data lands. ha_run_simulink.m still falls back
% to the base workspace too, in case a particular Simulink version ignores this for classic
% To Workspace blocks.
set_param(mdl, 'ReturnWorkspaceOutputs', 'on');
save_system(mdl);
end

function add_mfb(mdl, name, code, pos)
blk = [mdl '/' name];
add_block('simulink/User-Defined Functions/MATLAB Function', blk, 'Position', pos);
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blk);
ch.Script = sprintf(code);
end
