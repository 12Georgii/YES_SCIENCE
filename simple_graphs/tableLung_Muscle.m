%% 1. Загрузка файла

filename = 'rho muscle vs lung.txt';

if ~isfile(filename)
    [file, path] = uigetfile('*.txt', ...
        'Выберите файл COMSOL');

    if isequal(file, 0)
        error('Файл не выбран');
    end

    filename = fullfile(path, file);
end

fid = fopen(filename, 'r');

if fid == -1
    error('Не удалось открыть файл');
end

% Пропускаем комментарии COMSOL
data = textscan(fid, '%f %f %f %f', ...
    'CommentStyle', '%', ...
    'MultipleDelimsAsOne', true, ...
    'Delimiter', {' ', '\t'});

fclose(fid);

rhoLung   = data{1};
rhoMuscle = data{2};
V17       = data{3};
V18       = data{4};

fprintf('Загружено строк: %d\n', numel(rhoLung));

if isempty(rhoLung)
    error('Числовые данные не загружены');
end

%% 2. Расчёт импеданса

% ЗАМЕНИ на ток из твоей модели COMSOL
I = 1e-3;  % 1 мА

Z = abs(V17 - V18) / I;

%% 3. Подготовка поверхности

lungValues = unique(rhoLung);
muscleValues = unique(rhoMuscle);

[X, Y] = meshgrid(muscleValues, lungValues);

Zgrid = nan(size(X));

for k = 1:numel(Z)

    row = find(abs(lungValues-rhoLung(k)) < 1e-8, 1);
    col = find(abs(muscleValues-rhoMuscle(k)) < 1e-8, 1);

    Zgrid(row,col) = Z(k);

end

fprintf('Размер сетки: %d x %d\n', size(Zgrid));
fprintf('Заполнено узлов: %d\n', nnz(isfinite(Zgrid)));

%% 4. Построение графиков

figure('Name','Импеданс грудной клетки', ...
    'NumberTitle','off', ...
    'Color','w', ...
    'Visible','on');

% Трёхмерная поверхность
subplot(1,2,1);

surf(X, Y, Zgrid);

shading interp;
colormap turbo;
colorbar;

xlabel('\rho мышц, Ом·м');
ylabel('\rho лёгких, Ом·м');
zlabel('Импеданс, Ом');

title('Поверхность импеданса');

grid on;
view(45,30);

% Исходные точки
subplot(1,2,2);

scatter3(rhoMuscle, rhoLung, Z, ...
    40, Z, 'filled');

colormap turbo;
colorbar;

xlabel('\rho мышц, Ом·м');
ylabel('\rho лёгких, Ом·м');
zlabel('Импеданс, Ом');

title('Исходные данные COMSOL');

grid on;
view(45,30);

drawnow;

%% 5. Статистика

fprintf('\nМинимальный Z: %.4f Ом\n', min(Z));
fprintf('Максимальный Z: %.4f Ом\n', max(Z));
fprintf('Средний Z: %.4f Ом\n', mean(Z));
