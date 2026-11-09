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

% Каждая строка: [Zmin Zmax rhoM_min rhoM_max rhoL_min rhoL_max]
%                   импеданс     X: мышцы       Y: лёгкие
% Для отключения ограничения используйте -Inf и Inf.
% Пример нескольких независимых диапазонов:
% 48.00 49.00  0.8 2.0  8 25
% 46.00 48.00  1.0 3.0  10 30
ranges = [
    56.60 58.31   2.05 2.4   3.7 9.4
];

if size(ranges, 2) ~= 6
    error('ranges должен содержать 6 столбцов: Zmin Zmax rhoM_min rhoM_max rhoL_min rhoL_max');
end
if any(ranges(:,1) > ranges(:,2) | ...
       ranges(:,3) > ranges(:,4) | ...
       ranges(:,5) > ranges(:,6))
    error('В ranges минимальные границы не должны превышать максимальные.');
end

rangeNames = {
    'Z(\rho_M,\rho_L), Ом'
};

colors = [
    0.95 0.48 0.12;  % Оранжевый
    0.12 0.48 0.86;  % Синий
    0.62 0.27 0.75   % Фиолетовый
];

if numel(rangeNames) ~= size(ranges,1)
    error('Количество названий rangeNames должно совпадать с количеством строк ranges.');
end
if size(ranges,1) > size(colors,1)
    colors = lines(size(ranges,1));
end

%% =========================================================
% 5. ДВА ГРАФИКА: ОБРЕЗАННЫЙ И С НАЛОЖЕНИЕМ ОГРАНИЧЕНИЙ
% ==========================================================

% Первый график: исходные линии и точки обрезаны по X и Y.
% Второй график: полные линии и точки (только по Z), а поверх
% показаны прямоугольные области ограничений X и Y.
% Значения -Inf/Inf автоматически заменяются границами данных
% при построении прямоугольников.

xBounds = [min(muscleValues), max(muscleValues)];
yBounds = [min(lungValues), max(lungValues)];

for plotMode = 1:2
    fig = figure('Color', 'w', 'Position', [150 100 1050 750]);
    hold on; grid on; box on;
    h = gobjects(size(ranges,1),1);

    for k = 1:size(ranges,1)
        zMin = ranges(k,1);
        zMax = ranges(k,2);
        mMin = ranges(k,3);
        mMax = ranges(k,4);
        lMin = ranges(k,5);
        lMax = ranges(k,6);
        zCenter = (zMin + zMax)/2;

        if plotMode == 1
            % Строго ограничиваем линии областью, заданной по X и Y.
            insideXY = Xfine >= mMin & Xfine <= mMax & ...
                       Yfine >= lMin & Yfine <= lMax;
            Zdraw = Zfine;
            Zdraw(~insideXY) = NaN;
            idx = Z >= zMin & Z <= zMax & ...
                  rhoMuscle >= mMin & rhoMuscle <= mMax & ...
                  rhoLung >= lMin & rhoLung <= lMax;
        else
            % Полные контуры Z и точки в диапазоне Z: не обрезаем по X/Y.
            Zdraw = Zfine;
            idx = Z >= zMin & Z <= zMax;
        end

        if any(isfinite(Zdraw(:)))
            contour(Xfine, Yfine, Zdraw, [zMin zMin], ...
                'LineStyle','--', 'LineColor',colors(k,:), ...
                'LineWidth',1.1, 'HandleVisibility','off');
            contour(Xfine, Yfine, Zdraw, [zMax zMax], ...
                'LineStyle','--', 'LineColor',colors(k,:), ...
                'LineWidth',1.1, 'HandleVisibility','off');
            contour(Xfine, Yfine, Zdraw, [zCenter zCenter], ...
                'LineStyle','-', 'LineColor',colors(k,:), ...
                'LineWidth',2.8, 'HandleVisibility','off');
        end

        h(k) = scatter(rhoMuscle(idx),rhoLung(idx), ...
            65,colors(k,:),'filled','MarkerEdgeColor','k', ...
            'LineWidth',0.6,'DisplayName',rangeNames{k});

        if plotMode == 2
            % Пересечение заданного диапазона с исходной областью COMSOL.
            % Прямоугольник рисуем поверх полных линий и точек.
            x1 = max(mMin,xBounds(1));
            x2 = min(mMax,xBounds(2));
            y1 = max(lMin,yBounds(1));
            y2 = min(lMax,yBounds(2));
            if x1 < x2 && y1 < y2
                patch([x1 x2 x2 x1],[y1 y1 y2 y2],[0 0.75 1], ...
                    'FaceAlpha',0.09,'EdgeColor',[0 0.75 1], ...
                    'LineWidth',2.2,'LineStyle','-', ...
                    'HandleVisibility','off');
            else
                warning('Ограничение X/Y для диапазона %d не пересекается с областью данных.',k);
            end
        end

        if plotMode == 1
            fprintf('\nДиапазон %s\n',rangeNames{k});
            fprintf('Z: [%.4f, %.4f] Ом; rhoM: [%g, %g] Ом*м; rhoL: [%g, %g] Ом*м\n', ...
                zMin,zMax,mMin,mMax,lMin,lMax);
            fprintf('Количество точек с учетом всех ограничений: %d\n',sum(idx));
            for j = find(idx(:))'
                fprintf('rhoM = %.2f; rhoL = %.2f; Z = %.4f\n', ...
                    rhoMuscle(j),rhoLung(j),Z(j));
            end
        end
    end

    view(2);
    xlabel('Удельное сопротивление мышц, \rho_M (Ом·м)', ...
        'Interpreter','tex','FontSize',13);
    ylabel('Удельное сопротивление лёгких, \rho_L (Ом·м)', ...
        'Interpreter','tex','FontSize',13);
    if plotMode == 1
        title({'Зависимость трансторакального импеданса добровольца 2'; ...
               'от удельного сопротивления'}, ...
            'FontSize',15,'FontWeight','bold');
        outputBase = 'COMSOL_rho_muscle_lung_limited';
    else
        title({'Зависимость трансторакального импеданса добровольца 2'; ...
               'от удельного сопротивления'}, ...
            'FontSize',15,'FontWeight','bold');
        outputBase = 'COMSOL_rho_muscle_lung_overlay';
    end
    legend(h,rangeNames,'Location','northeast','FontSize',11);
    xlim(xBounds); ylim(yBounds);
    set(gca,'FontSize',11,'Layer','top');

   
end
