
clear; clc; close all;

%% 1. Исходные данные, Ом

ZTT = 54.989058595451226;
Z_top = 0;
Z_head      = abs(-7.514666425581548E-6);
Z_neck      = abs(-0.4574799997345432);
Z_armpit    = 54.989058595451226 - abs(12.04933566526849);
Z_diaphragm = 54.989058595451226 -abs(1.2549170535619674);
Z_belly     = 54.989058595451226 - abs(-3.594359445864576E-4);

Z = [Z_head, Z_neck, Z_armpit, ...
     Z_diaphragm, Z_belly];

Z_rest = ZTT - sum(Z);



%% 2. Высоты анатомических точек, м
% Примерные значения!
% Заменить на реальные высоты измерений.

H_crown     = 1.70; % Макушка
H_head      = 1.60; % Голова
H_neck      = 1.50; % Шея
H_armpit    = 1.40; % Подмышки
H_diaphragm = 1.30; % Диафрагма
H_belly     = 1.20; % Живот

H = [H_head, H_neck, H_armpit, ...
     H_diaphragm, H_belly];

names = {'Head', 'Neck', 'Armpit', ...
         'Diaphragm', 'Belly'};

%% 3. Расчёт процентных вкладов

P = Z / ZTT * 100;
P_rest = Z_rest / ZTT * 100;

% Накопленный вклад
P_cum = [0, cumsum(P)];

%% 4. Построение ступенчатой диаграммы

figure('Color','w', 'Position',[200 150 950 600]);
hold on;

blue = [0 0.4470 0.7410];

% Макушка головы: вклад 0
plot(0, H_crown, '.', ...
    'Color',blue,'MarkerSize',14);

% Вертикальный переход к голове
plot([0 0], [H_crown H(1)], ...
    'Color',blue,'LineWidth',1.5);

% Ступени по анатомическим областям
for i = 1:numel(Z)

    % Горизонтальный участок
    plot([P_cum(i), P_cum(i+1)], ...
         [H(i), H(i)], ...
         'Color',blue,'LineWidth',1.5);

    % Вертикальный переход
    if i < numel(Z)
        plot([P_cum(i+1), P_cum(i+1)], ...
             [H(i), H(i+1)], ...
             'Color',blue,'LineWidth',1.5);
    end
end

% Остаточный импеданс
% Показан пунктиром на уровне живота,
% но не приписывается животу.
plot([P_cum(end), 100], ...
     [H_belly, H_belly], '--', ...
     'Color',[0.85 0.325 0.098], ...
     'LineWidth',1.8);

%% 5. Оформление

xlabel('Contribution to Z_{TT}, %', ...
       'FontSize',12);

ylabel('Height, m', ...
       'FontSize',12);

title('Impedance contribution by body height');

xlim([0 100]);
ylim([1.10 1.75]);

xticks(0:10:100);
yticks(1.10:0.05:1.75);

grid on;
grid minor;
box on;

set(gca,'FontSize',11, ...
        'GridAlpha',0.25, ...
        'MinorGridAlpha',0.12);

%% 6. Вывод результатов

fprintf('\nTotal ZTT = %.6f Ohm\n',ZTT);

for i = 1:numel(Z)
    fprintf('%-12s %12.8f Ohm | %10.6f %%\n', ...
        names{i}, Z(i), P(i));
end

fprintf('Residual     %12.8f Ohm | %10.6f %%\n', ...
        Z_rest, P_rest);
