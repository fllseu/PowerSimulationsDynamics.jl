initpsat

runpsat('Test01.m', 'data')
%Set Time-Step = 0.02
Settings.tstep = 0.005;
%Set Fixed Time Step
Settings.fixt = 1;
% Set Frequency to 60 Hz
Settings.freq = 60;

%Run PF
runpsat('pf')

%Run Time-Domain simulation
runpsat('td')

t = Varout.t;
delta = Varout.vars(:, 1);
M = [t, delta];
csvwrite('Test01_delta.csv', M)

