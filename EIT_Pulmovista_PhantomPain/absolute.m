%% Import data
pulmovistadir = fullfile("EITData","2026_09_16","ID_SC");

filepath = fullfile(pulmovistadir,"ID_SC_02_001.eit");
[vv,auxdata]= eidors_readdata(filepath,'eit');
vv = real(vv);
FR = 20;
N = size(vv,2);


sigma= 0.2528;
rho_h = 1/sigma; % homogemeous model



%% =========================================================
%% FORWARD MODEL - HUMAN THORAX
%% =========================================================

Nelec = 16;

% Стандартная библиотечная модель грудной клетки взрослого человека
% 16 электродов в одном поясе
fmdl = mk_library_model('adult_male_16el');

% Разрешение отображения
fmdl.mdl_slice_mapper.npx = 256;
fmdl.mdl_slice_mapper.npy = 256;


%% Схема стимуляции и измерений
% Оставляем ту же самую схему, что использовалась для данных

[fmdl.stimulation, fmdl.meas_select] = ...
    mk_stim_patterns( ...
        Nelec, ...
        1, ...
        [0,1], ...
        [0,1], ...
        {'rotate_meas'} );


%% Координата центрального поперечного среза

z_min = min(fmdl.nodes(:,3));
z_max = max(fmdl.nodes(:,3));

H = z_max - z_min;

z_slice = (z_min + z_max)/2;


%% Проверка модели

fprintf('\n===== HUMAN THORAX MODEL =====\n');
fprintf('Nodes       = %d\n',size(fmdl.nodes,1));
fprintf('Elements    = %d\n',size(fmdl.elems,1));
fprintf('Electrodes  = %d\n',length(fmdl.electrode));
fprintf('z min       = %g\n',z_min);
fprintf('z max       = %g\n',z_max);
fprintf('z slice     = %g\n',z_slice);


figure;
show_fem(fmdl);
view(2);
axis equal;
title('Human thorax FEM model');

%% Forward Model

%fmdl = mk_library_model('adult_male_32el_lungs');
%fmdl = mk_library_model('cylinder_16x1el_coarse');
% Размеры цилиндра
H = 0.228;          % высота цилиндра, м = 228 мм
R = 0.190;          % радиус, м = 190 мм → диаметр 380 мм

% Параметры основной сетки
body_maxh = 0.010;  % максимальный размер элемента сетки, 10 мм

% Положение электродов
elec_pos = [16, H/2];   % 16 электродов на высоте середины цилиндра

% Размер электрода
% 20 мм вдоль окружности × 30 мм по высоте
elec_shape = [0.020, 0.030, 0.003];
%                         ↑
%                 размер сетки около электрода = 3 мм

% Создание цилиндрической модели
fmdl = ng_mk_cyl_models( ...
    [H, R, body_maxh], ...
    elec_pos, ...
    elec_shape);
% Разрешение изображения при построении срезов
fmdl.mdl_slice_mapper.npx = 128;
fmdl.mdl_slice_mapper.npy = 128;
%fmdl.electrode = fmdl.electrode(2:2:32);

[fmdl.stimulation,fmdl.meas_select]= mk_stim_patterns(16,1,[0,1],[0,1],{'rotate_meas'});
opt.imgsz = [32 32];
opt.square_pixels = true;
opt.noise_figure = 0.5;

figure();
%fmdl.nodes = fmdl.nodes / Perimeter(fmdl) * 1;

show_fem(fmdl);



%% =========================================================
%% DIFFERENCE RECONSTRUCTION - HUMAN THORAX
%% =========================================================

opt.imgsz = [50 50];
opt.square_pixels = true;
opt.noise_figure = 0.5;

% Однородное начальное изображение
img_bkg = mk_image(fmdl,sigma);

% GREIT строится уже на человеческой forward model
dimdl = mk_GREIT_model( ...
    img_bkg, ...
    0.20, ...
    [], ...
    opt);

% Среднее пустое состояние
vh = mean(vv(:,1:100),2);

% Difference reconstruction
dimgr = inv_solve(dimdl,vh,vv);


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
i_empt = 100; % inspiration
i_center = 600; % inspiration
i_first = 950; % expiration
i_third = 1300; % inspiration
i_fift = 1560; % inspiration
i_eight = 1800; % expiration
%FR = 20;
Fig = figure();
subplot(2,3,[4:6]);
z_tot = sum(dimgr.elem_data(:,1:N));
T = (0:N-1)/FR;
plot(T,z_tot); hold on;
plot(T(i_empt),z_tot(i_empt),'k^','MarkerFaceColor','k');
plot(T(i_center),z_tot(i_center),'kv','MarkerFaceColor','k');
plot(T(i_first),z_tot(i_first),'kd','MarkerFaceColor','k');
plot(T(i_third),z_tot(i_third),'k^','MarkerFaceColor','k');
plot(T(i_fift),z_tot(i_fift),'kv','MarkerFaceColor','k');
plot(T(i_eight),z_tot(i_eight),'kd','MarkerFaceColor','k');
%xlim([20,35]);%time cut
legend("\Sigma\Delta\sigma","empty","center","first","third", "fift", "eight",...
    'Location', 'northeast');
grid on; grid minor;
xlabel("Time, s");
ylabel("\sigma, Sm");

%% Absolute reconstruction in RESISTIVITY rho [Ohm*m]

fmdl = mk_library_model('adult_male_16el');
amdl.solve = @inv_solve_gn;
amdl.fwd_model = fmdl;
amdl.reconst_type = 'absolute';

% ---------------------------------------------------------
% РЕКОНСТРУКЦИЯ В УДЕЛЬНОМ СОПРОТИВЛЕНИИ rho
% ---------------------------------------------------------

% Начальное однородное сопротивление
rho_h = 1/sigma;             % [Ohm*m]

% Говорим EIDORS, что начальные данные заданы именно как rho
amdl.inv_solve_gn.elem_prior = 'resistivity';
amdl.inv_solve_gn.prior_data = rho_h;

% Оптимизируем именно rho
amdl.inv_solve_gn.elem_working = 'resistivity';

% На выходе тоже хотим rho
amdl.inv_solve_gn.elem_output = 'resistivity';

% Параметры Gauss-Newton
amdl.inv_solve_gn.max_iterations = 10;
amdl.inv_solve_gn.stop_tolerance = 1e-8;

% Регуляризация
amdl.RtR_prior = @prior_noser;

hp = 5e-2;
amdl.hyperparameter.value = hp;
%%
aimg_empt = inv_solve(amdl, vv(:,i_empt));
aimg_center = inv_solve(amdl, vv(:,i_center));
aimg_first = inv_solve(amdl, vv(:,i_first));
aimg_third = inv_solve(amdl, vv(:,i_third));
aimg_fift = inv_solve(amdl, vv(:,i_fift));
aimg_eight = inv_solve(amdl, vv(:,i_eight)); 

%% Проверка результатов реконструкции

fprintf('\nEMPTY [Ohm*m]:\n');
fprintf('rho min  = %g Ohm*m\n', min(aimg_empt.elem_data));
fprintf('rho max  = %g Ohm*m\n', max(aimg_empt.elem_data));
fprintf('rho mean = %g Ohm*m\n', mean(aimg_empt.elem_data));

fprintf('\nCENTER [Ohm*m]:\n');
fprintf('rho min  = %g Ohm*m\n', min(aimg_center.elem_data));
fprintf('rho max  = %g Ohm*m\n', max(aimg_center.elem_data));
fprintf('rho mean = %g Ohm*m\n', mean(aimg_center.elem_data));


%% Общая цветовая шкала rho

rho_min = 0;
rho_max = 10;     % Ohm*m

imgs = {
    aimg_empt
    aimg_center
    aimg_first
    aimg_third
    aimg_fift
    aimg_eight
};

for k = 1:length(imgs)

    imgs{k}.calc_colours.auto_clim = 0;

    % Центр шкалы
    imgs{k}.calc_colours.ref_level = ...
        (rho_min + rho_max)/2;

    % Половина диапазона
    imgs{k}.calc_colours.clim = ...
        (rho_max - rho_min)/2;

end

aimg_empt   = imgs{1};
aimg_center = imgs{2};
aimg_first  = imgs{3};
aimg_third  = imgs{4};
aimg_fift   = imgs{5};
aimg_eight  = imgs{6};

%%
%cmin = 0;
%cmax = 0.5;

aimg_empt.calc_colours.auto_clim = 0;%empty
aimg_empt.calc_colours.ref_level = (cmin + cmax)/2;
aimg_empt.calc_colours.clim = (cmax - cmin)/2;

aimg_center.calc_colours.auto_clim = 0;%bottle 1 el
aimg_center.calc_colours.ref_level = (cmin + cmax)/2;
aimg_center.calc_colours.clim = (cmax - cmin)/2;

aimg_first.calc_colours.auto_clim = 0;%bottle 3 el
aimg_first.calc_colours.ref_level = (cmin + cmax)/2;
aimg_first.calc_colours.clim = (cmax - cmin)/2;

aimg_third.calc_colours.auto_clim = 0;%bottle 5 el
aimg_third.calc_colours.ref_level = (cmin + cmax)/2;
aimg_third.calc_colours.clim = (cmax - cmin)/2;

aimg_fift.calc_colours.auto_clim = 0;%center bottle
aimg_fift.calc_colours.ref_level = (cmin + cmax)/2;
aimg_fift.calc_colours.clim = (cmax - cmin)/2;

aimg_eight.calc_colours.auto_clim = 0;%double bottle center
aimg_eight.calc_colours.ref_level = (cmin + cmax)/2;
aimg_eight.calc_colours.clim = (cmax - cmin)/2;



%% SoloObj
H = range(fmdl.nodes(:,3)); % model height
figure('Name','Два объекта');

subplot(2,3,1);
show_slices(aimg_empt,[inf,inf,.5*H]);
cb = eidors_colourbar(aimg_empt);
cb.Label.String = 'Resistivity, \Omega\cdotm';
title('Пустой фантом');

subplot(2,3,2);
show_slices(aimg_center,[inf,inf,.5*H]);
cb = eidors_colourbar(aimg_center);
cb.Label.String = 'Resistivity, \Omega\cdotm';
title('Объект по центру');

subplot(2,3,3);
show_slices(aimg_first,[inf,inf,.5*H]);
cb = eidors_colourbar(aimg_first);
cb.Label.String = 'Resistivity, \Omega\cdotm';
title('Объект у 1го электрода');

subplot(2,3,4);
show_slices(aimg_third,[inf,inf,.5*H]);
cb = eidors_colourbar(aimg_third);
cb.Label.String = 'Resistivity, \Omega\cdotm';
title('Объект у 3го электрода');

subplot(2,3,5);
show_slices(aimg_fift,[inf,inf,.5*H]);
cb = eidors_colourbar(aimg_fift);
cb.Label.String = 'Resistivity, \Omega\cdotm';
title('Объект у 5го электрода');


subplot(2,3,6);
show_slices(aimg_eight,[inf,inf,.5*H]);
cb = eidors_colourbar(aimg_eight);
cb.Label.String = 'Resistivity, \Omega\cdotm';
title('Объект у 8го электрода');

saveas(fig, ['Одиночный объект.png']);

%%
dv_center = vv(:,i_center) - vv(:,i_empt);
dv_first  = vv(:,i_first)  - vv(:,i_empt);
dv_third  = vv(:,i_third)  - vv(:,i_empt);
dv_fift   = vv(:,i_fift)   - vv(:,i_empt);
dv_eight  = vv(:,i_eight)  - vv(:,i_empt);

%% Difference reconstruction between selected RAW frames

dimg_center = inv_solve(dimdl, vv(:,i_empt), vv(:,i_center));
dimg_first  = inv_solve(dimdl, vv(:,i_empt), vv(:,i_first));
dimg_third  = inv_solve(dimdl, vv(:,i_empt), vv(:,i_third));
dimg_fift   = inv_solve(dimdl, vv(:,i_empt), vv(:,i_fift));
dimg_eight  = inv_solve(dimdl, vv(:,i_empt), vv(:,i_eight));

figure;

subplot(2,3,1);
show_slices(dimg_center,[inf,inf,.5*H]);
eidors_colourbar(dimg_center);
title('Центр - пустой');

subplot(2,3,2);
show_slices(dimg_first,[inf,inf,.5*H]);
eidors_colourbar(dimg_first);
title('1 электрод - пустой');

subplot(2,3,3);
show_slices(dimg_third,[inf,inf,.5*H]);
eidors_colourbar(dimg_third);
title('3 электрод - пустой');

subplot(2,3,4);
show_slices(dimg_fift,[inf,inf,.5*H]);
eidors_colourbar(dimg_fift);
title('5 электрод - пустой');

subplot(2,3,5);
show_slices(dimg_eight,[inf,inf,.5*H]);
eidors_colourbar(dimg_eight);
title('8 электрод - пустой');
%%
H = range(fmdl.nodes(:,3)); % model height

subplot(2,3,3);
show_slices(aimg_first,[inf,inf,.5*H]);
cb = eidors_colourbar(aimg_first);
cb.Label.String = 'Resistivity, \Omega\cdotm';
title('Объект у 1го электрода');
%%

H = range(fmdl.nodes(:,3)); % model height

figure(Fig);
subplot(2,3,1);
show_slices(aimg_inspsyst,[inf,inf,.5*H]);
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
rho_b =0.6;
bimg= toBorders(img,rho_b) ;
show_slices(bimg,[inf,inf,.5*H]);
eidors_colourbar(bimg);
title("Inspiration Minus Expiration (End Diastole)");


subplot(1,2,2)
img = rhoimg_inspsyst;
img.elem_data = img.elem_data - rhoimg_inspdiast.elem_data;
rho_b =0.2;
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



% 7. Вычисляем прямую задачу для получения значений потенциала

function rimg = toBorders(cimg,rho_max)
    rimg=cimg;
    %rimg.elem_data = cimg.elem_data;
    %rimg.elem_data(rimg.elem_data<0) = -rho_max/2;
    rimg.calc_colours.auto_clim = 1;
    rimg.calc_colours.ref_level = 0;
    rimg.calc_colours.clim = rho_max;
end