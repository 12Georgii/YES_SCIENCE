
clear;
clc;
close all;

%% 1. Загрузка данных COMSOL

filename = 'move_heart.txt';

if ~isfile(filename)
    [file, path] = uigetfile('*.txt', ...
        'Выберите файл move_heart.txt');

    if isequal(file, 0)
        error('Файл не выбран');
    end

    filename = fullfile(path, file);
end

% COMSOL использует символ % для комментариев
fid = fopen(filename, 'r');

if fid == -1
    error('Не удалось открыть файл');
end

data = textscan(fid, repmat('%f', 1, 9), ...
    'CommentStyle', '%', ...
    'MultipleDelimsAsOne', true);

fclose(fid);

% Преобразование в числовую матрицу
M = [data{:}];

if isempty(M) || size(M, 2) ~= 9
    error('Ошибка чтения данных COMSOL');
end

%% 2. Извлечение столбцов

% Смещение сердца, мм
d = M(:,1);

% Значения импеданса при вдохе
% Порядок столбцов в исходном файле:
% X_inh, X_exh, Y_inh, Z_inh,
% R_inh, R_exh, Y_exh, Z_exh

Z_inh = M(:, [2 4 5 6]);

% Значения импеданса при выдохе
Z_exh = M(:, [3 8 9 7]);

% Названия кривых
names = {'delX', 'delY', 'delZ', 'delR'};


%% 3. Расчет изменения импеданса

dZ_inh = Z_inh - Z_inh(1,:);
dZ_exh = Z_exh - Z_exh(1,:);

%% 4. Построение четырех графиков

datasets = {Z_inh, Z_exh, dZ_inh, dZ_exh};

titles = {
    'Импеданс при вдохе'
    'Импеданс при выдохе'
    'Изменение импеданса при вдохе'
    'Изменение импеданса при выдохе'
};

names = {'delX', 'delY', 'delZ', 'delR'};

for i = 1:4

    % Создаем отдельное окно
    fig = figure( ...
        'Name', titles{i}, ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Visible', 'on', ...
        'WindowStyle', 'normal');

    % Явно создаем оси
    ax = axes('Parent', fig);

    hold(ax, 'on');

    % Строим четыре кривые
    for j = 1:4
        plot(ax, d, datasets{i}(:,j), '-o', ...
            'LineWidth', 2, ...
            'MarkerSize', 6, ...
            'DisplayName', names{j});
    end

    % Нулевая линия для разностей
    if i >= 3
        yline(ax, 0, '--k', ...
            'HandleVisibility', 'off');
    end

    hold(ax, 'off');

    grid(ax, 'on');
    box(ax, 'on');

    xlabel(ax, 'Смещение, мм');

    if i <= 2
        ylabel(ax, 'Импеданс Z, Ом');
    else
        ylabel(ax, '\Delta Z, Ом');
    end

    title(ax, titles{i});
    legend(ax, 'show', 'Location', 'best');

    xlim(ax, [min(d), max(d)]);

    % Автоматический масштаб
    axis(ax, 'auto');

    % Принудительное отображение
    set(fig, 'Visible', 'on');
    drawnow;

    fprintf('Построен график %d\n', i);

end
