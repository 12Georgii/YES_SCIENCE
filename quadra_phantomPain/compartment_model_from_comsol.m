%% Tissue properties
% alternatively could be extracted from COMSOL files
rho_bl = 1.35; %[Ohm*m]
rho_mus = 5; %[Ohm*m]
rho_lung = 6:12; %[Ohm*m]
%% Import COMSOLE partial impedances

datadir = fullfile("data","20260605");

Zh = transform(import_comsol_partial_z(fullfile(datadir,"Simp_Yar_Tom_int_Blood_and_miocard.txt"), [6, Inf]));
Zhc = transform(import_comsol_partial_z(fullfile(datadir,"Simp_Yar_Tom_int_Blood.txt"), [6, Inf]));
Zrl = transform(import_comsol_partial_z(fullfile(datadir,"Simp_Yar_Tom_int_Right_lung.txt"), [6, Inf]));
Zll = transform(import_comsol_partial_z(fullfile(datadir,"Simp_Yar_Tom_int_Left_lung.txt"), [6, Inf]));
Zm = transform(import_comsol_partial_z(fullfile(datadir,"Simp_Yar_Tom_int_Muscle.txt"), [6, Inf]));
Zt = transform(import_comsol_partial_z(fullfile(datadir,"Simp_Yar_Tom_int_All.txt"), [6, Inf]));

Zm = Zm + Zh-Zhc; % add myocardium to muscles
Zh = Zhc; % heart as just heart chambers


%% Estimate Sensitivity and Reconstruction matrices

mdl.compartments = {"Right Lung","Left Lung","Heart Chambers","Muscles"};
mdl.n_meas = size(Zt,2);

mdl.rho = [rho_lung(1), rho_lung(1), rho_bl, rho_mus];
mdl.n_comp = numel(mdl.compartments);
mdl.S = []; % Sensitivity matrix [m^-1]
mdl.R = []; % Reconstruction matrix[m]

n_models = numel(rho_lung);
 
for i = 1:n_models
    models(i) = mdl;
    models(i).rho(1:2) = rho_lung(i);
    models(i).S = [Zrl(i,:)',Zll(i,:)',Zh(i,:)',Zm(i,:)'] ./ models(i).rho; % Sensitivity matrix [m^-1]
    models(i).R = pinv(models(i).S); % Reconstruction matrix [m]
end

%% Save data to file

timestamp = string(datetime(),'yyyy-MM-dd''T''HH-mm-ss');
save(sprintf("CompartmentModel_%s",timestamp),"models"); 




function Zo = transform(D)
    Zo = zeros(7,208);
    for i = 1:7
        Zo(i,:) = -OmitCurrentAndRotate(D(i,2:end));
    end
end

function Z = OmitCurrentAndRotate(Z_wc)
    Z = zeros(208,1);
    for i = 1:16
        z = Z_wc(16*(i-1)+(1:16));
        z = circshift(z,1-i);
        Z(13*(i-1)+(1:13)) = z(3:15);
    end
end