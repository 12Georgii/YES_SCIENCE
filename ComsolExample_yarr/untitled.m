%% Parameters
I = 1; %[A] injection current
rho = 5; %[Ohm*m] resistivity
d = 6e-2; %[m] distance between adjacent electrodes


%% 3D analitic solution
dV_3d = I*rho/2/pi*( ...
    ( 1/(2*d)-1/d ) ... % positive potential electrode
    -( 1/(3*d) - 1/(2*d) ) ) % negative potential electrode
%% 2D alalitic solution
dV_2d = I*rho/pi*( ...
    ( log(2) - log(1) ) ... % positive potential electrode
    -( log(3) - log(2) ) ) % negative potential electrode