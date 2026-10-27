%% =========================================================
% 1. ЗАГРУЗКА ДАННЫХ COMSOL
% ==========================================================

scriptPath = mfilename('fullpath');

if isempty(scriptPath)
    scriptDir = pwd;
else
    scriptDir = fileparts(scriptPath);
end

fileName = 'resulets_perebor_Yar(1).txt';
filePath = fullfile(scriptDir, fileName);

[fileName, selectedDir] = uigetfile( ...
    {'*.txt', 'Текстовые файлы COMSOL (*.txt)'; ...
     '*.*', 'Все файлы (*.*)'}, ...
    'Выберите файл результатов COMSOL', scriptDir);

if isequal(fileName, 0)
    disp('Выбор файла отменён.');
    return;
end

filePath = fullfile(selectedDir, fileName);

% Формат файла:
% roLung (Ohm*m) | roMuscle (Ohm*m) | ZTT (Ohm)
% Строки, начинающиеся с %, являются комментариями.

fid = fopen(filePath, 'r');

if fid == -1
    error('Не удалось открыть файл');
end

C = textscan(fid, '%f %f %f', ...
    'CommentStyle', '%', ...
    'MultipleDelimsAsOne', true);

fclose(fid);

rhoLung   = C{1};
rhoMuscle = C{2};
Z         = C{3};

valid = isfinite(rhoLung) & ...
        isfinite(rhoMuscle) & ...
        isfinite(Z);

rhoLung   = rhoLung(valid);
rhoMuscle = rhoMuscle(valid);
Z         = Z(valid);

if isempty(Z)
    error('В файле отсутствуют числовые данные');
end

%% =========================================================
% 2. ФОРМИРОВАНИЕ ИСХОДНОЙ СЕТКИ
% ==========================================================

% X — удельное сопротивление мышц
% Y — удельное сопротивление лёгких
% Z — трансторакальный импеданс

muscleValues = unique(rhoMuscle);
lungValues   = unique(rhoLung);

[X, Y] = meshgrid(muscleValues, lungValues);

Zgrid = nan(size(X));

for i = 1:numel(Z)

    row = find(lungValues == rhoLung(i), 1);
    col = find(muscleValues == rhoMuscle(i), 1);

    Zgrid(row, col) = Z(i);
end

if any(isnan(Zgrid(:)))
    error('Исходная сетка COMSOL содержит пропуски');
end

%% =========================================================
% 3. ДВУМЕРНАЯ КУБИЧЕСКАЯ ИНТЕРПОЛЯЦИЯ
% ==========================================================

% Создаём плотную сетку.
% Интерполяция выполняется только внутри исходной области.

nPoints = 600;

muscleFine = linspace(min(muscleValues), ...
                      max(muscleValues), nPoints);

lungFine = linspace(min(lungValues), ...
                    max(lungValues), nPoints);

[Xfine, Yfine] = meshgrid(muscleFine, lungFine);

% Двумерная сплайн-интерполяция

Zfine = interp2(X, Y, Zgrid, ...
                Xfine, Yfine, 'spline');

%% =========================================================
% 4. ДИАПАЗОНЫ ИМПЕДАНСА
% ==========================================================

ranges = [
    56.6 58.5
];

rangeNames = {
    'Z(\rho_M,\rho_L), Ом'
};

colors = [
    0.95 0.48 0.12;  % Оранжевый
    0.12 0.48 0.86;  % Синий
    0.62 0.27 0.75   % Фиолетовый
];

%% =========================================================
% 5. ПОСТРОЕНИЕ ГРАФИКА
% ==========================================================

figure('Color', 'w', ...
       'Position', [150 100 1050 750]);

hold on;
grid on;
box on;

% Фоновая карта допустимых диапазонов
% Каждый диапазон рисуется отдельно.
% Если диапазоны пересекаются, цвета накладываются.

for k = 1:size(ranges, 1)

    zMin = ranges(k, 1);
    zMax = ranges(k, 2);

    mask = Zfine >= zMin & Zfine <= zMax;

    % Область выбранного диапазона
    region = double(mask);
    region(~mask) = NaN;

    %surf(Xfine, Yfine, zeros(size(Xfine)), ...
     %    region, ...
      %   'FaceColor', colors(k,:), ...
       %  'FaceAlpha', 0.13, ...
        % 'EdgeColor', 'none');

end

view(2);

% Границы интервалов и центральные линии

h = gobjects(size(ranges,1),1);

for k = 1:size(ranges,1)

    zMin = ranges(k,1);
    zMax = ranges(k,2);

    zCenter = (zMin + zMax)/2;

    % Границы диапазона
    contour(Xfine, Yfine, Zfine, ...
            [zMin zMin], ...
            'LineStyle', '--', ...
            'LineColor', colors(k,:), ...
            'LineWidth', 1.1);

    contour(Xfine, Yfine, Zfine, ...
            [zMax zMax], ...
            'LineStyle', '--', ...
            'LineColor', colors(k,:), ...
            'LineWidth', 1.1);

    % Центральная аппроксимированная линия
    contour(Xfine, Yfine, Zfine, ...
            [zCenter zCenter], ...
            'LineStyle', '-', ...
            'LineColor', colors(k,:), ...
            'LineWidth', 2.8);

    % Исходные точки COMSOL внутри диапазона
    idx = Z >= zMin & Z <= zMax;

    h(k) = scatter(rhoMuscle(idx), ...
                   rhoLung(idx), ...
                   65, colors(k,:), ...
                   'filled', ...
                   'MarkerEdgeColor', 'k', ...
                   'LineWidth', 0.6, ...
                   'DisplayName', rangeNames{k});

    fprintf('\nДиапазон %s\n', rangeNames{k});
    fprintf('Количество исходных точек: %d\n', sum(idx));

    for j = find(idx(:))'
        fprintf('rhoM = %.2f; rhoL = %.2f; Z = %.4f\n', ...
                rhoMuscle(j), rhoLung(j), Z(j));
    end
end

%% =========================================================
% 6. ОФОРМЛЕНИЕ
% ==========================================================

xlabel('Удельное сопротивление мышц, \rho_M (Ом·м)', ...
       'Interpreter', 'tex', ...
       'FontSize', 13);

ylabel('Удельное сопротивление лёгких, \rho_L (Ом·м)', ...
       'Interpreter', 'tex', ...
       'FontSize', 13);

title({'Аппроксимация зависимости трансторакального импеданса'; ...
       'от удельных сопротивлений мышц и лёгких'}, ...
       'FontSize', 15, ...
       'FontWeight', 'bold');

legend(h, rangeNames, ...
       'Location', 'northeast', ...
       'FontSize', 11);

xlim([min(muscleValues), max(muscleValues)]);
ylim([min(lungValues), max(lungValues)]);

set(gca, ...
    'FontSize', 11, ...
    'Layer', 'top');

%% =========================================================
% 7. СОХРАНЕНИЕ
% ==========================================================

outputPNG = fullfile(scriptDir, ...
    'COMSOL_rho_muscle_lung_ranges.png');

outputPDF = fullfile(scriptDir, ...
    'COMSOL_rho_muscle_lung_ranges.pdf');

exportgraphics(gcf, outputPNG, ...
    'Resolution', 300);

exportgraphics(gcf, outputPDF, ...
    'ContentType', 'vector');

fprintf('\nГрафики сохранены:\n%s\n%s\n', ...
        outputPNG, outputPDF);
