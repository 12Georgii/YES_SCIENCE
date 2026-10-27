
clear;
clc;
close all;

%% 1. Загрузка файла COMSOL

filename = 'CompEXTRfineandFINE.txt';

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

% В файле три числовых столбца
data = textscan(fid, '%f %f %f', ...
    'CommentStyle', '%', ...
    'MultipleDelimsAsOne', true, ...
    'CollectOutput', true);

fclose(fid);

M = data{1};

if isempty(M) || size(M, 2) ~= 3
    error('Ошибка чтения данных COMSOL');
end

%% 2. Извлечение столбцов

% Смещение, мм
d = M(:,1);

% Импеданс для сетки Extra fine
Z_extra = M(:,2);

% Импеданс для сетки Finer
Z_finer = M(:,3);

%% 3. Расчет изменений импеданса

% Изменение относительно начального значения
dZ_extra = Z_extra - Z_extra(1);
dZ_finer = Z_finer - Z_finer(1);

% Абсолютное расхождение между сетками
diff_Z = abs(Z_extra - Z_finer);

% Относительное расхождение, %
% За базу принимаем сетку Finer
relative_diff = diff_Z ./ abs(Z_finer) * 100;

%% 4. График 1: Импеданс двух сеток

fig1 = figure( ...
    'Name', 'Сравнение импеданса', ...
    'NumberTitle', 'off', ...
    'Color', 'w');

ax1 = axes('Parent', fig1);

hold(ax1, 'on');

plot(ax1, d, Z_extra, '-or', ...
    'LineWidth', 2, ...
    'MarkerSize', 6, ...
    'DisplayName', 'Extra fine');

plot(ax1, d, Z_finer, '-sb', ...
    'LineWidth', 2, ...
    'MarkerSize', 6, ...
    'DisplayName', 'Finer');

hold(ax1, 'off');

grid(ax1, 'on');
box(ax1, 'on');

xlabel(ax1, 'Смещение, мм');
ylabel(ax1, 'Импеданс Z, Ом');
title(ax1, 'Зависимость импеданса от смещения');

legend(ax1, 'show', 'Location', 'best');

%% 5. График 2: Изменение импеданса

fig2 = figure( ...
    'Name', 'Изменение импеданса', ...
    'NumberTitle', 'off', ...
    'Color', 'w');

ax2 = axes('Parent', fig2);

hold(ax2, 'on');

plot(ax2, d, dZ_extra, '-or', ...
    'LineWidth', 2, ...
    'MarkerSize', 6, ...
    'DisplayName', 'Extra fine');

plot(ax2, d, dZ_finer, '-sb', ...
    'LineWidth', 2, ...
    'MarkerSize', 6, ...
    'DisplayName', 'Finer');

yline(ax2, 0, '--k', ...
    'HandleVisibility', 'off');

hold(ax2, 'off');

grid(ax2, 'on');
box(ax2, 'on');

xlabel(ax2, 'Смещение, мм');
ylabel(ax2, '\Delta Z, Ом');
title(ax2, 'Изменение импеданса относительно d = 0');

legend(ax2, 'show', 'Location', 'best');

%% 6. График 3: Расхождение между сетками

fig3 = figure( ...
    'Name', 'Относительное расхождение', ...
    'NumberTitle', 'off', ...
    'Color', 'w');

ax3 = axes('Parent', fig3);

plot(ax3, d, relative_diff, '-ok', ...
    'LineWidth', 2, ...
    'MarkerSize', 6);

grid(ax3, 'on');
box(ax3, 'on');

xlabel(ax3, 'Смещение, мм');
ylabel(ax3, 'Расхождение, %');

title(ax3, ...
    'Относительное расхождение Extra fine и Finer');

%% 7. Численные результаты

fprintf('\nСРАВНЕНИЕ СЕТОК\n');

fprintf('Максимальное расхождение: %.6f %%\n', ...
    max(relative_diff));

fprintf('Среднее расхождение: %.6f %%\n', ...
    mean(relative_diff));

fprintf('Минимальное расхождение: %.6f %%\n', ...
    min(relative_diff));

fprintf('\nНачальные значения:\n');

fprintf('Extra fine: %.8f Ом\n', Z_extra(1));
fprintf('Finer: %.8f Ом\n', Z_finer(1));

fprintf('\nВсе графики построены.\n');

drawnow;
