%% Import data
pulmovistadir = fullfile("EITData","2026_04_23","ID_SC");

filepath = fullfile(pulmovistadir,"ID_SC_08_001.eit");
[vv,auxdata]= eidors_readdata(filepath,'eit');
vv = real(vv);
FR = 20;
N = size(vv,2);

rho_h = 5; % homogemeous model

%% Forward Model

fmdl = mk_library_model('adult_male_32el_lungs');

fmdl.electrode = fmdl.electrode(2:2:32);

[fmdl.stimulation,fmdl.meas_select]= mk_stim_patterns(16,1,[0,1],[0,1],{'rotate_meas'});
opt.imgsz = [32 32];
opt.square_pixels = true;
opt.noise_figure = 0.5;

figure();
fmdl.nodes = fmdl.nodes / Perimeter(fmdl) * 1;

show_fem(fmdl);

%% Reconstruct Difference model
%rho_h = 5; % homogemeous model
opt.imgsz = [32 32];
opt.square_pixels = true;
opt.noise_figure = 0.5;
dimdl= mk_GREIT_model(mk_image(fmdl,1/rho_h), 0.20, [], opt);

vh = mean(vv(:,1:100),2);
dimgr= inv_solve(dimdl, vh, vv);
%% Display difference reconstruction
%N = size(vv,2);
% select frames for absolute reconstruction
i_inspsyst = 572; % inspiration, end-diastole, Yar_572, NIX_466
i_inspdiast = 578; % inspiration, end-systole, Yar_578, NIX_485
i_expsyst = 827; % expiration, end-systole, Yar_827, NIX_582
%FR = 20;
Fig = figure();
subplot(2,3,[4:6]);
z_tot = sum(dimgr.elem_data(:,1:N));
T = (0:N-1)/FR;
plot(T,z_tot); hold on;
plot(T(i_inspsyst),z_tot(i_inspsyst),'k^','MarkerFaceColor','k');
plot(T(i_inspdiast),z_tot(i_inspdiast),'kv','MarkerFaceColor','k');
plot(T(i_expsyst),z_tot(i_expsyst),'kd','MarkerFaceColor','k');
xlim([20,35]);%time cut
legend("\Sigma\Delta\sigma","End Diastole, Inspiration","End Systole, Inspiration","End Diastole, Expiration",...
    'Location', 'northeast');
grid on; grid minor;
xlabel("Time, s");
ylabel("\sigma, Sm");

%% Absolute Inverse solution

amdl = mk_common_model('b2c2',32); %generic mdl
amdl.solve = @inv_solve_gn; %Default Gauss Newton solvers
amdl.fwd_model = fmdl;
amdl.reconst_type = 'absolute';
amdl.jacobian_bkgnd.value = 1/rho_h;

amdl.inv_solve_gn.max_iterations = 10; %Number of iterations
amdl.inv_solve_gn.stop_tolerance = 1e-8;

amdl.RtR_prior=@prior_noser;

hp = 5e-2;

amdl.hyperparameter.value = hp;
%%
aimg_inspsyst = inv_solve(amdl, vv(:,i_inspsyst));
aimg_inspdiast = inv_solve(amdl, vv(:,i_inspdiast));
aimg_expsyst = inv_solve(amdl, vv(:,i_expsyst));
 

%% Convert to resistivity
rho_max = 10;
rhoimg_inspsyst  = toResistivity(aimg_inspsyst,rho_max) ;
rhoimg_inspdiast  = toResistivity(aimg_inspdiast,rho_max) ;
rhoimg_expsyst  = toResistivity(aimg_expsyst,rho_max) ;


%%

H = range(fmdl.nodes(:,3)); % model height

figure(Fig);
subplot(2,3,1);
show_slices(rhoimg_inspsyst,[inf,inf,.5*H]);
eidors_colourbar(rhoimg_inspsyst);

title("End Diastole, Inspiration");

subplot(2,3,2);
show_slices(rhoimg_inspdiast,[inf,inf,.6*H]);
eidors_colourbar(rhoimg_inspdiast);
title("End Systole, Inspiration");

subplot(2,3,3);
show_slices(rhoimg_expsyst,[inf,inf,.6*H]);
eidors_colourbar(rhoimg_expsyst);
title("End Diastole, Expiration");

%% Subtract absolute images
figure();
subplot(1,2,1);
img = rhoimg_inspsyst;
img.elem_data = img.elem_data - rhoimg_expsyst.elem_data;
rho_b =0.2;
bimg= toBorders(img,rho_b) ;
show_slices(bimg,[inf,inf,.5*H]);
eidors_colourbar(bimg);
title("Inspiration Minus Expiration (End Diastole)");


subplot(1,2,2)
img = rhoimg_inspsyst;
img.elem_data = img.elem_data - rhoimg_inspdiast.elem_data;
rho_b =0.05;
bimg= toBorders(img,rho_b) ;
show_slices(bimg,[inf,inf,.5*H]);
eidors_colourbar(bimg);
title("End Diastole Minus End Systole (Inspiration)");

%figure();
%show_fem(img)
%% Show solution
img = rhoimg_inspsyst; % end-diastole

figure();
subplot(1,2,1);
show_fem(fmdl);


subplot(1,2,2);
show_fem(img);
title("Reconstructed Image");

%figure()
%title("Reconstructed Image Horizontal Slices");
%show_3d_slices(img,H*[.25,.5,.75],[],[]);   eidors_colourbar(img);

%figure();

%show_slices(img,[inf,inf,.2*H; inf,inf,.3*H; inf,inf,.5*H; inf,inf,.7*H; inf,inf,.8*H], ...
%    [1,1;2,1;3,1; 1,2;2,2])
%title("Reconstructed Image Horizontal Slices");
%eidors_colourbar(img);
%% Estimate mean conductivity for lungs

%sigma = aimg_expsyst.elem_data;
%sigma = aimg_inspsyst.elem_data;
%sigma = aimg_inspdiast.elem_data;

%vol = get_elem_volume(fmdl); 

% left lung
%sigma_ll = sum(sigma(fmdl.mat_idx{2}) .* vol(fmdl.mat_idx{2})) / sum(vol(fmdl.mat_idx{2}));
%rho_ll = 1/sigma_ll

% right lung
%sigma_rl = sum(sigma(fmdl.mat_idx{3}) .* vol(fmdl.mat_idx{3})) / sum(vol(fmdl.mat_idx{3}));
%rho_rl = 1/sigma_rl


%% Try cilindre

% 1. Создаем базовую модель (например, цилиндр)
%fmdl = mk_common_model('n3r2',16);

% 2. Получаем координаты всех узлов сетки
%nodes = fmdl.nodes;

% 3. Задаем параметры сферы (например, в центре с радиусом 0.2)
%center = [0.05, 0.05, 0.1];
%radius = 0.02;

% 4. Вычисляем расстояние от узлов до центра сферы
%distances = sqrt((nodes(:,1)-center(1)).^2 + (nodes(:,2)-center(2)).^2 + (nodes(:,3)-center(3)).^2);

% 5. Находим индексы элементов, попадающих внутрь сферы
%internal_nodes = distances <= radius;

% 6. Создаем модифицированный вектор проводимости
% Базовая проводимость = 1, внутри сферы = 2
%img = mk_image(fmdl, 1);
%img.elem_data(internal_nodes) = 2;

% 7. Вычисляем прямую задачу для получения значений потенциала
%data = fwd_solve(img);

function rimg = toResistivity(cimg,rho_max)
    rimg = cimg;
    %rho_max = 10;
    rimg.elem_data = 1./cimg.elem_data;
    rimg.elem_data(rimg.elem_data>rho_max) = rho_max;
    rimg.elem_data(rimg.elem_data<0) = 0;
    rimg.calc_colours.auto_clim = 0;
    rimg.calc_colours.ref_level = rho_max/2;
    rimg.calc_colours.clim = rho_max/2;
end

function rimg = toBorders(cimg,rho_max)
    rimg=cimg;
    rimg.elem_data = cimg.elem_data;
    rimg.elem_data(rimg.elem_data<0) = 0;
    rimg.calc_colours.auto_clim = 0;
    rimg.calc_colours.ref_level = rho_max/2;
    rimg.calc_colours.clim = rho_max/2;
end