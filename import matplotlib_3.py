import matplotlib.pyplot as plt
import numpy as np

# Данные точек
x = [1, 2, 3, 4, 5]
y = [2, 4, 1, 5, 3]
points = list(zip(x, y))

# Создание фигуры с двумя областями
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

# 1. График точек
ax1.scatter(x, y, color='red', s=50, zorder=5)
ax1.plot(x, y, 'b--', alpha=0.5)  # Соединяем точки линией
ax1.grid(True, linestyle='--', alpha=0.7)
ax1.set_xlabel('X', fontsize=12)
ax1.set_ylabel('Y', fontsize=12)
ax1.set_title('График по точкам', fontsize=14)

# Подписываем точки на графике
for i, (xi, yi) in enumerate(points):
    ax1.text(xi + 0.1, yi + 0.1, f'({xi},{yi})', fontsize=9)

# 2. Текстовое представление точек
ax2.axis('off')  # Выключаем оси для текстовой области
ax2.set_title('Список точек', fontsize=14, pad=20)

# Создаем текст с координатами
text_content = "Координаты точек:\n" + "\n".join([f"{i+1}. ({x[i]}, {y[i]})" for i in range(len(x))])

# Добавляем статистику
text_content += f"\n\nСтатистика:\n"
text_content += f"Всего точек: {len(x)}\n"
text_content += f"X: min={min(x)}, max={max(x)}, avg={np.mean(x):.2f}\n"
text_content += f"Y: min={min(y)}, max={max(y)}, avg={np.mean(y):.2f}"

ax2.text(0.1, 0.95, text_content, fontsize=12, family='monospace',
         verticalalignment='top', transform=ax2.transAxes,
         bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.5))

plt.tight_layout()
plt.show()

# Альтернативный вариант: вывод точек в таблице на графике
fig2, ax3 = plt.subplots(figsize=(10, 6))

# График
ax3.scatter(x, y, color='red', s=100, zorder=5)
ax3.plot(x, y, 'g-', alpha=0.7)
ax3.grid(True, linestyle=':', alpha=0.6)
ax3.set_xlabel('X', fontsize=12)
ax3.set_ylabel('Y', fontsize=12)
ax3.set_title('График с таблицей точек', fontsize=14)

# Таблица с точками
columns = ('№', 'X', 'Y')
cell_text = [[i+1, x[i], y[i]] for i in range(len(x))]

table = ax3.table(cellText=cell_text, colLabels=columns,
                  colColours=['lightgray']*3,
                  cellLoc='center', loc='right',
                  bbox=[1.05, 0.1, 0.3, 0.8])

table.auto_set_font_size(False)
table.set_fontsize(10)
table.scale(1, 1.5)

plt.tight_layout(rect=[0, 0, 0.75, 1])  # Оставляем место для таблицы
plt.show()

# Вывод в консоль
print("Точки для построения графика:")
for i, (xi, yi) in enumerate(points):
    print(f"Точка {i+1}: ({xi}, {yi})")