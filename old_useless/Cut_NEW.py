import numpy as np
import matplotlib.pyplot as plt

Trans =	127.92323544263654
	
Cardiac = 4.307238406127593
I = 0.003

#solution1
#HEAD (Ω)
#1.4838443975950526E-8
#NECK (Ω)
#0.15511322631614757
#ARMPITS (Ω)
#9.750174651731388
#APERTURE (Ω)
#1.3593598607991795
#LEGS (Ω)
#0.283827138836417

#Trans = abs(TTR-TTL)/I
HEAD = 3.705497521098947E-4
NECK = 0.6009618641375063
ARMPITS = 13.423484744004607
APERTURE = 5.2044881729897
LEGS = 1.1123052317087403

#Trans2 = abs(TTR2-TTL2)/I
#print("Trans1", Trans, "\nTrans2", Trans2)
#solution2
#HEAD2 (Ω)
#6.070115417923033E-8
#NECK2 (Ω)
#0.6346413675457745
#ARMPITS2 (Ω)
#14.20595410306176
#APERTURE2 (Ω)
#5.562291406128914
#LEGS2 (Ω)
#1.183666781583348

HEAD2 = 6.070115417923033E-8
NECK2 = 0.6346413675457745
ARMPITS2 = 14.20595410306176
APERTURE2 = 5.562291406128914
LEGS2 = 1.183666781583348


#solution3
#HEAD3 (Ω)
#2.025927435409718E-9
#NECK3 (Ω)
#0.021156609689146354
#ARMPITS3 (Ω)
#2.4502168599448044
#APERTURE3 (Ω)
#1.0847472289690312
#LEGS3 (Ω)
#0.0532730965080836

HEAD3 = 2.025927435409718E-9
NECK3 = 0.021156609689146354
ARMPITS3 = 2.4502168599448044
APERTURE3 = 1.0847472289690312
LEGS3 = 0.0532730965080836
# 1. Ввод данных (пример с тестовыми данными)
x = np.array([0, 1, 2, 3, 4, 5, 6])
#y = np.array([0, HEAD, NECK, Trans-ARMPITS, Trans-APERTURE, Trans-LEGS, Trans])

y = np.array([0, HEAD2, NECK2, Trans-ARMPITS2, Trans-APERTURE2, Trans-LEGS2, Trans])
y2 = np.array([0, HEAD3, NECK3, Cardiac-ARMPITS3, Cardiac-APERTURE3, Cardiac-LEGS3, Cardiac])
# print("Производная:", dy_dx)
solution2 = [0,HEAD2, NECK2, ARMPITS2, APERTURE2, LEGS2,0]
solution3 = [0,HEAD3, NECK3, ARMPITS3, APERTURE3, LEGS3,0]
# x1 = np.array([0, 1, 2, 3, 4])
# y1 = np.array([])

# Замените массивы x и y своими данными, например:
# x = np.array([ваши_значения])
# y = np.array([ваши_значения])

# 2. Вычисление производной (центральные разности)


def compute_derivative(x, y):
    dy_dx = np.zeros_like(y)

    # Центральные разности для внутренних точек
    for i in range(1, len(y)-1):
        dy_dx[i] = (y[i+1] - y[i-1]) / (x[i+1] - x[i-1])

    # Односторонние разности для краев
    dy_dx[0] = (y[1] - y[0]) / (x[1] - x[0])
    dy_dx[-1] = (y[-1] - y[-2]) / (x[-1] - x[-2])

    return dy_dx


dy_dx = compute_derivative(x, y)

dy2_dx = compute_derivative(x, y2)

x_centers = []
widths = []
for i in range(len(x)-1):
    center = (x[i] + x[i+1]) / 2
    width = x[i+1] - x[i]
    x_centers.append(center)
    widths.append(width)
#print ("diff dy/dx", dy_dx)
# Создаем фигуру с сеткой 3x2 (3 строки, 2 столбца)
fig = plt.figure(figsize=(16, 10))

# Задаем сетку для размещения графиков и таблицы
gs = plt.GridSpec(3, 2, height_ratios=[1, 1, 1.2], hspace=0.3, wspace=0.4)

# График 1: Исходный импеданс по срезам (первый набор данных)
ax1 = fig.add_subplot(gs[0, 0])
ax1.scatter(x, y, color='red', label='Исходный импеданс по срезам', zorder=3, s=50)
ax1.plot(x, y, 'b-', label='Аппроксимация', linewidth=2)
ax1.set_xlabel('Sn', fontsize=10)
ax1.set_ylabel('Z', fontsize=10)
ax1.set_title('Исходный импеданс по срезам (Набор 1)', fontsize=11)
ax1.grid(True, alpha=0.3)
ax1.legend(fontsize=9)

#График 2: Производная первого набора данных
ax2 = fig.add_subplot(gs[0, 1])
ax2.bar(x_centers, dy_dx, width=widths, align='center', edgecolor='black', alpha=0.7, color='lightcoral', label='Гистограмма')
#ax2.step(x, dy_dx, 'm-', label='Производная (аппроксимация)', linewidth=2, where='mid')
ax2.axhline(y=0, color='black', linestyle='--', alpha=0.3)
ax2.set_xlabel('Sn', fontsize=10)
ax2.set_ylabel('dZ/dx', fontsize=10)
ax2.set_title('Производная импеданса по оси X (Набор 1)', fontsize=11)
ax2.grid(True, alpha=0.3)
ax2.legend(fontsize=9)

#ax2 = fig.add_subplot(gs[0, 1])
#bar_width = 0.6
#ax2.bar(x, dy_dx, width=bar_width, color='magenta', edgecolor='darkmagenta', 
#        label='Производная (гистограмма)', alpha=0.7)
#ax2.axhline(y=0, color='black', linestyle='--', alpha=0.3)
#ax2.set_xlabel('Sn', fontsize=10)
#ax2.set_ylabel('dZ/dx', fontsize=10)
#ax2.set_title('Производная импеданса по оси X (Набор 1)', fontsize=11)
#ax2.grid(True, alpha=0.3, axis='y')
#ax2.legend(fontsize=9)

# График 3: Второй набор данных
ax3 = fig.add_subplot(gs[1, 0])
ax3.scatter(x, y2, color='green', label='Импеданс 2', zorder=3, s=50)
ax3.plot(x, y2, 'g-', label='Аппроксимация', linewidth=2)
ax3.axhline(y=0, color='black', linestyle='--', alpha=0.3)
ax3.set_xlabel('Sn', fontsize=10)
ax3.set_ylabel('Z2', fontsize=10)
ax3.set_title('Исходный импеданс по срезам (Набор 2)', fontsize=11)
ax3.grid(True, alpha=0.3)
ax3.legend(fontsize=9)

# График 4: Производная второго набора данных
ax4 = fig.add_subplot(gs[1, 1])
ax4.step(x, dy2_dx, 'c-', label='Производная (аппроксимация)', linewidth=2, where='mid')
ax4.axhline(y=0, color='black', linestyle='--', alpha=0.3)
ax4.set_xlabel('Sn', fontsize=10)
ax4.set_ylabel('dZ2/dx', fontsize=10)
ax4.set_title('Производная импеданса по оси X (Набор 2)', fontsize=11)
ax4.grid(True, alpha=0.3)
ax4.legend(fontsize=9)

# Таблица с данными (занимает всю ширину нижней строки)
ax_table = fig.add_subplot(gs[2, :])
ax_table.axis('tight')
ax_table.axis('off')

# Создаем таблицу с данными
table_data = []
headers = ['№', 'H', 'int1', 'Z', 'dZ/dx', 'int2', 'Z2', 'dZ2/dx']

for i in range(len(x)):
    table_data.append([
        i+1,
        f"{x[i]:.1f}",
        f"{solution2[i]:.12f}",
        f"{y[i]:.12f}",
        f"{dy_dx[i]:.12f}",
        f"{solution3[i]:.12f}",
        f"{y2[i]:.12f}",
        f"{dy2_dx[i]:.12f}"
    ])

# Создаем таблицу
table = ax_table.table(cellText=table_data, 
                       colLabels=headers,
                       cellLoc='center',
                       loc='center',
                       colWidths=[0.05, 0.05, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2])

# Настраиваем стиль таблицы
table.auto_set_font_size(False)
table.set_fontsize(9)
table.scale(1, 1.8)

# Цвета заголовков
for i in range(len(headers)):
    table[(0, i)].set_facecolor('#DDDDDD')
    table[(0, i)].set_text_props(weight='bold')

# Заголовок для таблицы
ax_table.set_title('Таблица значений импедансов и их производных', fontsize=12, pad=20)

plt.suptitle('Анализ импедансов по срезам тела', fontsize=14, y=0.98)
plt.tight_layout()
plt.show()

# Вывод точек в консоль
print("=" * 80)
print("РАСЧЕТНЫЕ ДАННЫЕ")
print("=" * 80)
print(f"Trans1 = {Trans}")
#print(f"Trans2 = {Trans2}")
print()

#print("Набор данных 1:")
#print(f"{'Sn':<5} {'Z':<15}")
#for i in range(len(x)):
#    print(f"{x[i]:<5} {y[i]:<15.6f}")
#
#print("\nНабор данных 2:")
#print(f"{'Sn':<5} {'Z2':<15}")
#for i in range(len(x)):
#    print(f"{x[i]:<5} {y2[i]:<15.6f}")
#
#print("\nПроизводные:")
#print(f"{'Sn':<5} {'dZ/dx':<15} {'dZ2/dx':<15}")
#for i in range(len(x)):
#    print(f"{x[i]:<5} {dy_dx[i]:<15.6f} {dy2_dx[i]:<15.6f}")
#print("=" * 80)