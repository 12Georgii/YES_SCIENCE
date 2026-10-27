%% SCORP: выбор папки, файла и каналов измерений
clearvars; clc;

% НАСТРОЙКИ
sampleInterval_ms = 1;      % Интервал между строками данных, мс (уточни по прибору)
timeUnit = 's';            % 's' - секунды, 'ms' - миллисекунды, 'samples' - отсчёты
savePNG = false;           % true - сохранять PNG рядом с TXT

%% 1. Выбор папки (можно выбрать папку с вложенными папками)
rootDir = uigetdir(pwd, 'Выберите папку Scorp или папку эксперимента');
if isequal(rootDir, 0), disp('Выбор папки отменён'); return; end

% Ищем TXT в выбранной папке и всех её подпапках
files = dir(fullfile(rootDir, '**', '*.txt'));
if isempty(files)
    errordlg('В выбранной папке нет TXT-файлов.', 'Нет данных');
    return;
end

labels = cell(numel(files),1);
for k = 1:numel(files)
    relativeDir = erase(files(k).folder, [rootDir filesep]);
    if strcmp(relativeDir, files(k).folder), relativeDir = ''; end
    labels{k} = fullfile(relativeDir, files(k).name);
end

[fileIndex, ok] = listdlg('PromptString','Выберите TXT-файл:', ...
    'SelectionMode','single', 'ListString',labels, ...
    'ListSize',[650 380], 'Name','Файлы SCORP');
if ~ok, disp('Выбор файла отменён'); return; end

filePath = fullfile(files(fileIndex).folder, files(fileIndex).name);
fprintf('Файл: %s\n', filePath);

%% 2. Заголовки каналов: разделитель TAB, числа с десятичной запятой
fid = fopen(filePath,'rt');
if fid < 0, error('Невозможно открыть файл: %s',filePath); end
firstLine = fgetl(fid);
if ~ischar(firstLine)
    fclose(fid); error('Файл пуст');
end
columnNames = strsplit(strtrim(firstLine), sprintf('\t'));
columnNames = strtrim(columnNames);
columnNames = columnNames(~cellfun(@isempty,columnNames));
nCols = numel(columnNames);

if nCols < 2
    fclose(fid); error('Не удалось распознать заголовки каналов');
end

% Считываем все числовые столбцы; DecimalSeparator важен для SCORP
% Закрываем файл после чтения заголовка
fclose(fid);

% Читаем текстовые данные
rawText = fileread(filePath);

% Преобразуем десятичные запятые в точки
rawText = strrep(rawText, ',', '.');

% Считываем числовые столбцы
formatSpec = repmat('%f', 1, nCols);

C = textscan(rawText, formatSpec, ...
    'Delimiter', sprintf('\t'), ...
    'HeaderLines', 1, ...
    'CollectOutput', true, ...
    'MultipleDelimsAsOne', true, ...
    'ReturnOnError', false);

M = C{1};

%% 3. Выбор одного или нескольких каналов
isCount = strcmpi(columnNames,'COUNT');
channelNames = columnNames(~isCount);
columnIndices = find(~isCount);
if isempty(channelNames)
    error('Измерительные каналы отсутствуют');
end

[selection, ok] = listdlg('PromptString', ...
    {'Выберите один или несколько каналов:', ...
     '(Ctrl или Shift для нескольких)'}, ...
    'SelectionMode','multiple', 'ListString',channelNames, ...
    'InitialValue',find(startsWith(channelNames,'BEI')), ...
    'ListSize',[440 330], 'Name','Каналы SCORP');
if ~ok || isempty(selection)
    disp('Каналы не выбраны'); return;
end
selectedNames = channelNames(selection);
selectedColumns = columnIndices(selection);

%% 4. Временная ось
n = size(M,1);
switch lower(timeUnit)
    case 's'
        t = (0:n-1)' * sampleInterval_ms / 1000;
        timeLabel = 'Время, с';
    case 'ms'
        t = (0:n-1)' * sampleInterval_ms;
        timeLabel = 'Время, мс';
    case 'samples'
        t = (0:n-1)';
        timeLabel = 'Номер отсчёта';
    otherwise
        error('Неизвестная единица времени: %s',timeUnit);
end

%% 5. Построение графиков по отдельности
fig = figure('Color','w','Name',files(fileIndex).name, ...
    'NumberTitle','off','Position',[120 70 1200 750]);
T = tiledlayout(numel(selection),1,'TileSpacing','compact', ...
    'Padding','compact');

for j = 1:numel(selection)
    ax = nexttile(T);
    y = M(:,selectedColumns(j));
    plot(ax,t,y,'LineWidth',0.85);
    grid(ax,'on');
    ylabel(ax,channelUnit(selectedNames{j}),'Interpreter','none');
    title(ax,selectedNames{j},'Interpreter','none','FontSize',10);
    set(ax,'FontSize',10);
    if j ~= numel(selection)
        ax.XTickLabel = [];
    else
        xlabel(ax,timeLabel);
    end
end
sgtitle(T,files(fileIndex).name,'Interpreter','none','FontWeight','bold');

%% 6. Экспорт в PNG
if savePNG
    [~,stem] = fileparts(filePath);
    outputPath = fullfile(files(fileIndex).folder,[stem '_plots.png']);
    exportgraphics(fig,outputPath,'Resolution',300);
    fprintf('PNG сохранён: %s\n', outputPath);
end

%% Локальная функция для подписи вертикальных осей
function unit = channelUnit(name)
    if startsWith(name,'EMG','IgnoreCase',true)
        unit = 'ЭМГ, мВ';
    elseif contains(name,'ohm','IgnoreCase',true)
        unit = 'Импеданс, Ом';
    elseif contains(name,'grad','IgnoreCase',true)
        unit = 'Фаза, град';
    else
        unit = 'Значение';
    end
end
