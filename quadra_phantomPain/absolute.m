%% Import data
%pulmovistadir = fullfile("EITData","2026_04_23","ID_SC");
data = load('Exp_ClearTube.mat');

%filepath = fullfile(pulmovistadir,"ID_SC_08_001.eit");
%[vv,auxdata]= eidors_readdata(filepath,'eit');

Iinj = 15e-3;% 15 мА
Z = data.CT;                % Чистый фантом, только солевой раствор
Z1 = data.Bottle1el;        % Помещена бутылка на расстоянии 1 см от 1го электрода
Z2 = data.Third;            %-//- от 3го электрода
Z3 = data.Fifth;            %-//- от 5го электрода
Z4 = data.Center;          %-//- в центре
Z5 = data.DoubleCenter;
Z6 = data.DoubleFirst;            % Ом
Z7 = data.BigBotCen;
Z8 = data.BigBotFirst;
Z9 = data.BigBotSecond;

vv = Z * Iinj;                 % В
vv1=Z1 * Iinj;
vv2=Z2 * Iinj;
vv3=Z3 * Iinj;
vv4=Z4 * Iinj;                 % В
vv5=Z5 * Iinj;
vv6=Z6 * Iinj;
vv7=Z7 * Iinj;
vv8=Z8 * Iinj;
vv9=Z9 * Iinj;

%vv = data.M_MatExp1;
FR = 1;
N = size(vv,2);
N1 = size(vv1,2);
N2 = size(vv2,2);
N3 = size(vv3,2);
N4 = size(vv4,2);
N5 = size(vv5,2);
N6 = size(vv6,2);
N7 = size(vv7,2);
N8 = size(vv8,2);
N9 = size(vv9,2);

sigma = 2606e-4; %conductvity
rho_h = 1/sigma; % homogemeous model

%% =========================================================
%% HUMAN THORAX FORWARD MODEL
%% =========================================================

Nelec = 16;

% Стандартная грудная клетка взрослого человека
fmdl = mk_library_model('adult_male_16el');

% Явно задаём функции прямой задачи
fmdl.solve      = @fwd_solve_1st_order;
fmdl.system_mat = @system_mat_1st_order;
fmdl.jacobian   = @jacobian_adjoint;

% Разрешение отображения
fmdl.mdl_slice_mapper.npx = 256;
fmdl.mdl_slice_mapper.npy = 256;


%% Схема стимуляции и измерений

M = readmatrix('NEIGHBORING_16.csv');

% CSV:
% 1 INDEX
% 2 EX+
% 3 EX-
% 4 V+
% 5 V-

sp_mp = M(:,2:5);

% ВАЖНО: получаем ОБА объекта от stim_meas_list
fmdl.stimulation = ...
    stim_meas_list(sp_mp, Nelec, Iinj, 1);

fmdl.meas_select = ...
    true(size(sp_mp,1),1);


%% Проверки

fprintf('\n===== MODEL CHECK =====\n');

fprintf('Nodes:      %d\n', size(fmdl.nodes,1));
fprintf('Elements:   %d\n', size(fmdl.elems,1));
fprintf('Electrodes: %d\n', length(fmdl.electrode));
fprintf('Stimulations: %d\n', length(fmdl.stimulation));

fprintf('Min electrode number in CSV: %d\n', ...
    min(sp_mp(:)));

fprintf('Max electrode number in CSV: %d\n', ...
    max(sp_mp(:)));

if min(sp_mp(:)) < 1 || max(sp_mp(:)) > Nelec
    error('Ошибка в NEIGHBORING_16.csv: номера электродов должны быть 1...16');
end


%% Геометрия

z_min = min(fmdl.nodes(:,3));
z_max = max(fmdl.nodes(:,3));

z_slice = (z_min + z_max)/2;


%% Проверка модели

figure();
show_fem(fmdl);
view(2);
axis equal;
title('Human thorax model');


%% =========================================================
%% FORWARD SOLUTION TEST
%% =========================================================

img0 = mk_image(fmdl, sigma);

fprintf('\nImage elements: %d\n', length(img0.elem_data));
fprintf('sigma min = %.6g S/m\n', min(img0.elem_data));
fprintf('sigma max = %.6g S/m\n', max(img0.elem_data));

v0 = fwd_solve(img0);

fprintf('Forward solution OK\n');
fprintf('Number of calculated measurements = %d\n', ...
    length(v0.meas));

%% Reconstruct Difference model

% opt.imgsz = [32 32];
% opt.square_pixels = true;
% opt.noise_figure = 0.5;

% dimdl = mk_GREIT_model( ...
%     mk_image(fmdl,1/rho_h), ...
%     0.20, [], opt);

% vh = mean(vv(:,1:100),2);
% dimgr = inv_solve(dimdl, vh, vv);
%% Absolute I
% 2. Сравниваем эксперимент с однородной моделью

img0 = mk_image(fmdl,sigma);
v0 = fwd_solve(img0);

Zexp = Z;                 % твои данные, Ом
Zmodel = v0.meas/Iinj;    % расчёт EIDORS, Ом

[min(Zexp) max(Zexp)]
[min(Zmodel) max(Zmodel)]
corr(Zexp,Zmodel)



%% Calibration of absolute forward model
% Известный пустой фантом:
% sigma = 0.2606 S/m
% vv    = реальные напряжения пустого фантома

vempty = mean(vv,2);     % если кадров несколько - усредняем

% Перебираем эффективный контактный импеданс
zc_grid = logspace(-4,-1,25);

fit_err = zeros(size(zc_grid));
gain_all = zeros(size(zc_grid));

for iz = 1:length(zc_grid)

    % временная копия модели
    fmdl_test = fmdl;

    % одинаковый контактный импеданс всех 16 электродов
    for e = 1:Nelec
        fmdl_test.electrode(e).z_contact = zc_grid(iz);
    end

    % однородный фантом известной проводимости
    img_test = mk_image(fmdl_test,sigma);

    % расчёт прямой задачи
    vmodel_test = fwd_solve(img_test);
    vm = vmodel_test.meas(:);

    ve = vempty(:);

    % общий коэффициент масштаба измерительной системы
    Ktest = (ve' * vm)/(ve' * ve);

    gain_all(iz) = Ktest;

    % отрицательный коэффициент означает проблему со знаком /
    % порядком измерений, а не нормальную калибровку
    if Ktest <= 0
        fit_err(iz) = Inf;
    else
        fit_err(iz) = norm(Ktest*ve - vm) / norm(vm);
    end
end

% Лучший z_contact
[best_error, idx_best] = min(fit_err);

zc_best = zc_grid(idx_best);
K = gain_all(idx_best);

fprintf('\n===== ABSOLUTE CALIBRATION =====\n');
fprintf('Best z_contact = %.8g\n',zc_best);
fprintf('Gain K         = %.8g\n',K);
fprintf('Relative error = %.4f %%\n',100*best_error);

% Записываем найденный z_contact в рабочую модель
for e = 1:Nelec
    fmdl.electrode(e).z_contact = zc_best;
end

% Проверка корреляции после настройки модели
img0 = mk_image(fmdl,sigma);
v0 = fwd_solve(img0);

Rcorr = corr(vempty(:),v0.meas(:));

fprintf('Correlation = %.6f\n',Rcorr);

%% Absolute reconstruction in RESISTIVITY rho [Ohm*m]

% Известная проводимость солевого раствора
sigma = 2606e-4;          % S/m

% Соответствующее удельное сопротивление
rho_h = 1/sigma;          % Ohm*m


%% Создание обратной модели

amdl = mk_common_model('b2c2',16);

amdl.solve = @inv_solve_gn;
amdl.fwd_model = fmdl;

% Абсолютная реконструкция
amdl.reconst_type = 'absolute';


%% Фоновая модель для вычисления Jacobian

% ВАЖНО:
% это оставляем в conductivity.
% EIDORS рассчитывает прямую задачу и Jacobian через sigma,
% а затем сам преобразует Jacobian для rho.

amdl.jacobian_bkgnd.value = sigma;


%% Gauss-Newton

amdl.inv_solve_gn.max_iterations = 15;
amdl.inv_solve_gn.stop_tolerance = 1e-6;


%% Начальное состояние реконструкции

% Начальное значение задаём уже в rho
amdl.inv_solve_gn.prior_data = rho_h;

% Говорим EIDORS, что prior_data имеет единицы Ohm*m
amdl.inv_solve_gn.elem_prior = 'resistivity';


%% ПАРАМЕТР РЕКОНСТРУКЦИИ

% Решаем относительно log(rho)
% Это не позволяет rho становиться отрицательным
amdl.inv_solve_gn.elem_working = 'log_resistivity';

% На выходе хотим получить обычное rho, а не log(rho)
amdl.inv_solve_gn.elem_output = 'resistivity';


%% Измерительные данные

% На вход подаются реальные измеренные напряжения
amdl.inv_solve_gn.meas_input = 'voltage';
amdl.inv_solve_gn.meas_working = 'voltage';


%% Регуляризация

amdl.RtR_prior = @prior_noser;

hp = 0.1;
amdl.hyperparameter.value = hp;

%% Apply absolute calibration

vv_cal  = K * vv;
vv1_cal = K * vv1;
vv2_cal = K * vv2;
vv3_cal = K * vv3;
vv4_cal = K * vv4;
vv5_cal = K * vv5;
vv6_cal = K * vv6;
vv7_cal = K * vv7;
vv8_cal = K * vv8;
vv9_cal = K * vv9; 

%% Absolute reconstruction

aimg  = inv_solve(amdl, vv_cal);   % пустой фантом

aimg1 = inv_solve(amdl, vv1_cal);  % объект у электрода 1
aimg2 = inv_solve(amdl, vv2_cal);  % у электрода 3
aimg3 = inv_solve(amdl, vv3_cal);  % у электрода 5
aimg4 = inv_solve(amdl, vv4_cal);  % центр

aimg5 = inv_solve(amdl, vv5_cal);
aimg6 = inv_solve(amdl, vv6_cal);

aimg7 = inv_solve(amdl, vv7_cal);
aimg8 = inv_solve(amdl, vv8_cal);
aimg9 = inv_solve(amdl, vv9_cal);
%%
fprintf('\nEMPTY PHANTOM RECONSTRUCTION IN RESISTIVITY\n');

fprintf('min    = %.6f Ohm*m\n', min(aimg.elem_data));
fprintf('max    = %.6f Ohm*m\n', max(aimg.elem_data));
fprintf('mean   = %.6f Ohm*m\n', mean(aimg.elem_data));
fprintf('median = %.6f Ohm*m\n', median(aimg.elem_data));
fprintf('std    = %.6f Ohm*m\n', std(aimg.elem_data));


fprintf('\n===== PAIR OBJECT CHECK =====\n');

fprintf('\nDouble center:\n');
fprintf('min  = %.6f Ohm*m\n', min(aimg5.elem_data));
fprintf('max  = %.6f Ohm*m\n', max(aimg5.elem_data));
fprintf('mean = %.6f Ohm*m\n', mean(aimg5.elem_data));

fprintf('\nDouble electrode 1:\n');
fprintf('min  = %.6f Ohm*m\n', min(aimg6.elem_data));
fprintf('max  = %.6f Ohm*m\n', max(aimg6.elem_data));
fprintf('mean = %.6f Ohm*m\n', mean(aimg6.elem_data));


%% Common colour scale for resistivity

rho_min = 0;
rho_max = 10;      % Ohm*m

imgs = {
    aimg
    aimg1
    aimg2
    aimg3
    aimg4
    aimg5
    aimg6
    aimg7
    aimg8
    aimg9
};

for k = 1:numel(imgs)

    imgs{k}.calc_colours.auto_clim = 0;
    imgs{k}.calc_colours.ref_level = ...
        (rho_min + rho_max)/2;

    imgs{k}.calc_colours.clim = ...
        (rho_max - rho_min)/2;
end

aimg  = imgs{1};
aimg1 = imgs{2};
aimg2 = imgs{3};
aimg3 = imgs{4};
aimg4 = imgs{5};
aimg5 = imgs{6};
aimg6 = imgs{7};
aimg7 = imgs{8};
aimg8 = imgs{9};
aimg9 = imgs{10};

%% Высота модели для построения среза

H = range(fmdl.nodes(:,3));

%% SoloObj

figure('Name','Одиночный объект');

subplot(2,3,1);
show_slices(aimg,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Пустой фантом');

subplot(2,3,2);
show_slices(aimg1,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg1);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Объект у электрода 1');

subplot(2,3,3);
show_slices(aimg2,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg2);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Объект у электрода 3');

subplot(2,3,4);
show_slices(aimg3,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg3);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Объект у электрода 5');

subplot(2,3,5);
show_slices(aimg4,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg4);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Объект в центре');




%% PairObj

figure('Name','Два объекта');

subplot(1,3,1);
show_slices(aimg,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Пустой фантом');

subplot(1,3,2);
show_slices(aimg5,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg5);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Два объекта в центре');

subplot(1,3,3);
show_slices(aimg6,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg6);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Два объекта у электрода 1');



%% BigObject

figure('Name','Большой объект');

subplot(2,3,1);
show_slices(aimg,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Пустой фантом');

subplot(2,3,2);
show_slices(aimg7,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg7);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Большой объект в центре');

subplot(2,3,3);
show_slices(aimg8,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg8);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Большой объект у электрода 1');

subplot(2,3,4);
show_slices(aimg9,[inf,inf,z_slice]);
cb = eidors_colourbar(aimg9);
cb.Label.String = 'Resistivity, \Omega\cdot m';
title('Большой объект у электрода 8');


%% Impedancegram

figure;

plot(-Z);
hold on;

plot(-Z1);
plot(-Z2);

hold off;

xlabel('Номер измерения');
ylabel('Импеданс, Ом');
title('Сравнение измерений');

legend('Эксперимент 1', ...
       'Эксперимент 2', ...
       'Эксперимент 3');

grid on;

%% Каждый график отдельно

names = {
    'Пустой фантом'
    'Объект у электрода 1'
    'Объект у электрода 3'
    'Объект у электрода 5'
    'Объект в центре'
    'Два объекта в центре'
    'Два объекта у электрода 1'
    'Большой объект в центре'
    'Большой объект у электрода 1'
    'Большой объект у электрода 8'
};

Zall = {-Z,-Z1,-Z2,-Z3,-Z4,-Z5,-Z6,-Z7,-Z8,-Z9};

for i = 1:length(Zall)

    figure;

    plot(1:length(Zall{i}), Zall{i});

    xlabel('Номер измерения');
    ylabel('Импеданс, Ом');

    title(names{i});

    grid on;
end

%% SoloObj - отдельные оси

figure('Name','Одиночные объекты');

Solo = {-Z,-Z1,-Z2,-Z3,-Z4};

SoloNames = {
    'Пустой фантом'
    'Объект у электрода 1'
    'Объект у электрода 3'
    'Объект у электрода 5'
    'Объект в центре'
};

for i = 1:5

    subplot(2,3,i);

    plot(Solo{i});

    xlabel('Номер измерения');
    ylabel('Импеданс, Ом');

    title(SoloNames{i});

    grid on;
end

sgtitle('Одиночный объект');

%% PairObj - отдельные оси

figure('Name','Два объекта');

Pair = {-Z,-Z5,-Z6};

PairNames = {
    'Пустой фантом'
    'Два объекта в центре'
    'Два объекта у электрода 1'
};

for i = 1:3

    subplot(2,2,i);

    plot(Pair{i});

    xlabel('Номер измерения');
    ylabel('Импеданс, Ом');

    title(PairNames{i});

    grid on;
end

sgtitle('Два объекта');

%% BigObject - отдельные оси

figure('Name','Большой объект');

Big = {-Z,-Z7,-Z8,-Z9};

BigNames = {
    'Пустой фантом'
    'Большой объект в центре'
    'Большой объект у электрода 1'
    'Большой объект у электрода 8'
};

for i = 1:4

    subplot(2,2,i);

    plot(Big{i});

    xlabel('Номер измерения');
    ylabel('Импеданс, Ом');

    title(BigNames{i});

    grid on;
end

sgtitle('Большой объект');

%% SoloObj - на одних осях

figure;

plot(-Z);
hold on;
plot(-Z1);
plot(-Z2);
plot(-Z3);
plot(-Z4);

xlabel('Номер измерения');
ylabel('Импеданс, Ом');

title('Одиночный объект');

legend( ...
    'Пустой фантом', ...
    'У электрода 1', ...
    'У электрода 3', ...
    'У электрода 5', ...
    'В центре', ...
    'Location','best');

grid on;
hold off;

%% PairObj - на одних осях

figure;

plot(-Z);
hold on;
plot(-Z5);
plot(-Z6);

xlabel('Номер измерения');
ylabel('Импеданс, Ом');

title('Два объекта');

legend( ...
    'Пустой фантом', ...
    'Два объекта в центре', ...
    'Два объекта у электрода 1', ...
    'Location','best');

grid on;
hold off;

%% BigObject - на одних осях

figure;

plot(-Z);
hold on;
plot(-Z7);
plot(-Z8);
plot(-Z9);

xlabel('Номер измерения');
ylabel('Импеданс, Ом');

title('Большой объект');

legend( ...
    'Пустой фантом', ...
    'Большой объект в центре', ...
    'Большой объект у электрода 1', ...
    'Большой объект у электрода 8', ...
    'Location','best');

grid on;
hold off;
