%%noseImp
GridPath = fullfile('ComsolData', ...
    'HumanBody_Mesh.mphtxt');

txt = fileread(GridPath);

patterns = {
    'Mesh'
    'mesh'
    'number of mesh points'
    'Mesh point coordinates'
    'tet'
    'tri'
    'number of elements'
};

for k = 1:numel(patterns)
    idx = strfind(txt, patterns{k});
    fprintf('%s: %d совпадений\n', ...
        patterns{k}, numel(idx));
end

fprintf('\nРазмер файла: %.2f МБ\n', ...
    numel(txt)/1024^2);

fprintf('Полный путь:\n%s\n', ...
    char(java.io.File(GridPath).getCanonicalPath()));
txt = fileread(GridPath);

fprintf('Mesh points: %d\n', ...
    contains(txt, 'Mesh point coordinates'));

fprintf('Tetrahedra: %d\n', ...
    contains(txt, 'tet'));

info = dir(GridPath);
fprintf('File size: %.2f MB\n', info.bytes/1024^2);


%% importDataComcol
GridPath = fullfile('ComsolData', 'HumanBody_Mesh.mphtxt');

fid = fopen(GridPath, 'r');
assert(fid ~= -1, 'Не удалось открыть файл');

lineNum = 0;

while ~feof(fid)

    line = fgetl(fid);
    lineNum = lineNum + 1;

    if ~ischar(line)
        break;
    end

    if contains(lower(line), 'mesh point') || ...
       contains(lower(line), 'number of points') || ...
       contains(lower(line), 'tet') || ...
       contains(lower(line), 'number of elements') || ...
       contains(lower(line), 'tri') || ...
       contains(lower(line), 'vertex')

        fprintf('%7d | %s\n', lineNum, line);

    end
end

fclose(fid);
%% Import COMSOL mesh

clearvars;
clc;

GridPath = fullfile('ComsolData', ...
    'HumanBody_Mesh.mphtxt');

fid = fopen(GridPath,'r');

assert(fid ~= -1, 'Не удалось открыть файл сетки');

P = [];
E = [];

nNodes = [];
nTet = [];

while ~feof(fid)

    line = strtrim(fgetl(fid));

    % Количество узлов
    if contains(line, '# number of mesh vertices')

        nNodes = sscanf(line,'%d',1);

    % Координаты узлов
    elseif contains(line, '# Mesh vertex coordinates')

        assert(~isempty(nNodes), ...
            'Не найдено количество узлов');

        P = zeros(nNodes,3);

        for i = 1:nNodes
            P(i,:) = sscanf(fgetl(fid),'%f',3)';
        end

    % Найти раздел тетраэдров
    elseif contains(line, '3 tet # type name')

        % Найти количество тетраэдров
        while ~feof(fid)

            line = strtrim(fgetl(fid));

            if contains(line,'# number of elements')
                nTet = sscanf(line,'%d',1);
            end

            if strcmp(line,'# Elements')
                break;
            end
        end

        assert(~isempty(nTet), ...
            'Не найдено количество тетраэдров');

        E = zeros(nTet,4);

        for i = 1:nTet
            E(i,:) = sscanf(fgetl(fid),'%d',4)';
        end

        break;
    end
end

fclose(fid);

%% Проверка данных

assert(~isempty(P), 'Узлы не загружены');
assert(~isempty(E), 'Тетраэдры не загружены');

assert(all(isfinite(P(:))), ...
    'В координатах есть NaN или Inf');

assert(all(isfinite(E(:))), ...
    'В элементах есть NaN или Inf');

assert(size(P,2)==3, ...
    'Неверная размерность координат');

assert(size(E,2)==4, ...
    'Неверная размерность тетраэдров');

fprintf('Узлов: %d\n',size(P,1));
fprintf('Тетраэдров: %d\n',size(E,1));

fprintf('NaN в узлах: %d\n',sum(isnan(P(:))));

fprintf('Минимальный индекс: %d\n',min(E(:)));
fprintf('Максимальный индекс: %d\n',max(E(:)));

%% Проверка индексов

assert(min(E(:))>=0 && max(E(:))<size(P,1), ...
    'Индексы тетраэдров не соответствуют узлам');

%% Построение сетки

TR = triangulation(E+1,P);

figure;
trisurf(freeBoundary(TR), ...
    P(:,1),P(:,2),P(:,3), ...
    'FaceColor',[0.7 0.8 0.9], ...
    'EdgeColor','none');

axis equal;
view(3);
camlight;
lighting gouraud;

title('COMSOL mesh geometry');




%% electrode coordinates
Pel = [-28.5, 87;...
        -89,78;...
        -135, 40.3;...
        -173, -3.1;...
        -192, -60;...
        -156, -108;...
        -97,-116;...
        -32,-116;...
        32, -116;...
        97,-116;...
        156,-108;...
        192, -60;...
        173, -3.1;...
        135, 40.3;...
        89, 78;...
        28.5, 87;];
Pel = [Pel, ones(size(Pel,1),1)*40];

%% Import data
DataPath = fullfile('ComsolData', 'gomogen muscle pulse.txt'); 
[rho_m,Z] = transform(importfileNumTable(DataPath, [6, Inf]));

rho_h = rho_m(1);


%% СОЗДАНИЕ ЭЛЕКТРОДОВ НА СЕТКЕ COMSOL

% P и E уже загружены из COMSOL.
% Предполагается, что P задан в миллиметрах.

% 1. Перевод геометрии в метры
P_m = P * 1e-3;

% 2. Создание модели EIDORS
fmdl = mk_library_model('adult_male_16el');

fmdl.nodes = P_m;
fmdl.elems = E + 1;

% 3. Построение внешней поверхности
TR = triangulation(fmdl.elems, fmdl.nodes);
fmdl.boundary = freeBoundary(TR);

% 4. Координаты центров 16 электродов, мм
Pel_mm = [
    -28.5,  87;
    -89,    78;
    -135,   40.3;
    -173,   -3.1;
    -192,  -60;
    -156, -108;
    -97,  -116;
    -32,  -116;
     32,  -116;
     97,  -116;
    156,  -108;
    192,  -60;
    173,   -3.1;
    135,   40.3;
     89,   78;
     28.5, 87
];

% Высота расположения электродов
z_mm = 40;

% Полные трёхмерные координаты
Pel = [Pel_mm, z_mm * ones(16,1)] * 1e-3;

% 5. Параметры электродов
Nel = 16;
d_el = 0.010;               % Диаметр 10 мм
Sel = pi*d_el^2/4;          % Площадь, м^2

% Примерное удельное контактное сопротивление.
% Заменить на экспериментально обоснованное!
z_contact = 1e-3;           % Ом*м^2

% 6. Создание электродов
fmdl.electrode = CreateSurfaceElectrodes( ...
    fmdl, Pel, Sel, z_contact);

%% Создание шаблонов стимуляции

[fmdl.stimulation, fmdl.meas_select] = ...
    mk_stim_patterns(16, 1, ...
    [0,1], [0,1], {'rotate_meas'}, 1);

% Проверка
fprintf('Электродов: %d\n', numel(fmdl.electrode));
fprintf('Шаблонов стимуляции: %d\n', ...
    numel(fmdl.stimulation));

nMeas = sum(arrayfun( ...
    @(s) size(s.meas_pattern,1), ...
    fmdl.stimulation));

fprintf('Измерений: %d\n', nMeas);

assert(~isempty(fmdl.stimulation), ...
    'Шаблоны стимуляции не созданы');

assert(nMeas == 208, ...
    'Количество измерений отличается от ожидаемых 208');


% 7. Проверка
fprintf('Количество электродов: %d\n', ...
    numel(fmdl.electrode));

for j = 1:Nel
    fprintf('Электрод %2d: %d узлов\n', ...
        j, numel(fmdl.electrode(j).nodes));
end

% 8. Визуализация
figure;
show_fem(fmdl);
axis equal;
view(3);
title('Трёхмерная модель с 16 электродами');

%% Compare forward solution

img = mk_image(fmdl, 1/rho_h);

tic
v = fwd_solve(img);
fwd_duration = toc;

fprintf("Forward solution required %f s", fwd_duration);

figure();

subplot(2,1,1)
plot(v.meas*1e3); hold on;
plot(Z(1,:),'o');
grid on; grid minor;
xlim([1,208]);
xlabel("Lead number");
ylabel("Impedance, \Omega");
legend("MATLAB","COMCOL",'Location','north');

subplot(2,1,2)
e = (Z(1,:)' - v.meas*1e3)./Z(1,:)';
plot(e*100);
grid on; grid minor;
xlim([1,208]);
xlabel("Lead number");
ylabel("Error, %");


%% Absolute Inverse solution

amdl = mk_common_model('b2c2',32); %generic mdl
amdl.solve = @inv_solve_gn; %Default Gauss Newton solvers
amdl.fwd_model = fmdl;
amdl.reconst_type = 'absolute';
amdl.jacobian_bkgnd.value= 1/rho_h;

amdl.inv_solve_gn.max_iterations = 3 ; %Number of iterations
amdl.inv_solve_gn.stop_tolerance = 1e-8;

%cc.cb_shrink_move = [0.5,0.8,0.00];

amdl.RtR_prior=@prior_noser;

hp = 2;

amdl.hyperparameter.value = hp;
%%
aimg = inv_solve(amdl, Z');
%aimg_inspdiast = inv_solve(amdl, vv(:,i_inspdiast));
%aimg_expsyst = inv_solve(amdl, vv(:,i_expsyst));
%img.calc_colours = cc;

%%

H = 40;

figure()
show_slices(aimg,[inf,inf,H]);
eidors_colourbar(aimg);
title("Absolute Images");

dimg = aimg;
dimg.elem_data = dimg.elem_data(:,2:end)-dimg.elem_data(:,1)
figure()
show_slices(dimg,[inf,inf,H]);
eidors_colourbar(dimg);
title("Subtract absolute Img_n - Img_1");
%%
figure()
histogram(aimg.elem_data(:,1),'FaceAlpha',.2); hold on;
for i = 2:size(aimg.elem_data,2)
    histogram(aimg.elem_data(:,i),'FaceAlpha',.2);
end

mean_sigma_est = mean(aimg.elem_data)';
sigma = 1./rho_m;

figure();
plot(rho_m,sigma,'-o','LineWidth',1.1);
ylabel("\sigma_{mdl}, S/m");
xlabel("\rho_{mdl}, \Omega\cdot m");
grid on; grid minor;
yyaxis right
plot(rho_m,mean_sigma_est,'-o','LineWidth',1.1);
ylabel("\sigma_{est}, S/m");


function electrodes = CreateSurfaceElectrodes(fmdl, centers, targetArea, zContact)

    % fmdl       - конечно-элементная модель EIDORS
    % centers    - координаты центров электродов (N x 3)
    % targetArea - требуемая площадь электрода, м^2
    % zContact   - удельное контактное сопротивление, Ом*м^2

    B = fmdl.boundary;
    P = fmdl.nodes;

    nFaces = size(B,1);
    nElectrodes = size(centers,1);

    assert(size(B,2)==3, ...
        'Граничные элементы должны быть треугольниками');

    assert(size(centers,2)==3, ...
        'Центры электродов должны иметь координаты X,Y,Z');

    assert(targetArea > 0 && zContact > 0, ...
        'Площадь и контактное сопротивление должны быть положительными');

    % Координаты вершин треугольников
    p1 = P(B(:,1),:);
    p2 = P(B(:,2),:);
    p3 = P(B(:,3),:);

    % Центры треугольных граней
    C = (p1 + p2 + p3)/3;

    % Площадь каждой грани
    faceArea = 0.5 * vecnorm( ...
        cross(p2-p1,p3-p1,2),2,2);

    % Список рёбер всех треугольников
    edges = [
        B(:,[1 2]);
        B(:,[2 3]);
        B(:,[3 1])
    ];

    edges = sort(edges,2);
    owners = repmat((1:nFaces)',3,1);

    % Сортировка рёбер
    [edges,order] = sortrows(edges);
    owners = owners(order);

    % Поиск общих рёбер
    sameEdge = all( ...
        edges(1:end-1,:) == edges(2:end,:),2);

    idx = find(sameEdge);

    % Матрица смежности треугольников
    adjacency = sparse( ...
        owners(idx),owners(idx+1),true, ...
        nFaces,nFaces);

    adjacency = adjacency | adjacency';

    % Создание структуры электродов
    electrodes = repmat( ...
        struct('nodes',[],'z_contact',zContact), ...
        1,nElectrodes);

    usedNodes = [];

    % Формирование каждого электрода
    for j = 1:nElectrodes

        center = centers(j,:);

        % Расстояние до центров поверхностных граней
        dist = vecnorm(C-center,2,2);

        % Исключение ранее занятых узлов
        blocked = any(ismember(B,usedNodes),2);
        dist(blocked) = inf;

        % Выбор ближайшего свободного треугольника
        [minDist,seed] = min(dist);

        if ~isfinite(minDist)
            error('Нет свободной грани для электрода %d',j);
        end

        selected = false(nFaces,1);
        selected(seed) = true;

        totalArea = faceArea(seed);

        % Расширение электродной площадки
        while totalArea < targetArea

            neighbors = find(any( ...
                adjacency(selected,:),1))';

            % Исключение занятых граней
            neighbors = neighbors( ...
                ~selected(neighbors) & ...
                ~blocked(neighbors));

            if isempty(neighbors)
                error('Невозможно расширить электрод %d',j);
            end

            % Ближайший соседний треугольник
            [~,i] = min(dist(neighbors));
            face = neighbors(i);

            selected(face) = true;
            totalArea = totalArea + faceArea(face);
        end

        % Получение уникальных узлов электрода
        nodes = unique(B(selected,:));

        % Сохранение данных электрода
        electrodes(j).nodes = nodes(:)';
        electrodes(j).z_contact = zContact;

        % Запоминаем занятые узлы
        usedNodes = [usedNodes; nodes(:)];

        % Вывод результата
        fprintf(['Электрод %2d: площадь %.3f мм^2, ' ...
                 'узлов %d\n'], ...
                 j,totalArea*1e6,numel(nodes));
    end
end



function A = TriArea(P)
    a = P(2,:)-P(1,:);
    b = P(3,:)-P(1,:);
    A = 0.5 * norm( cross(a,b));
end