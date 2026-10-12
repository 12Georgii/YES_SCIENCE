import matplotlib.pyplot as plt
import numpy as np

# Данные (пример)
x_edges = [1800, 1800-25, 1800-60, 1800-275, 1800-595, 1800-700]
y_values = [5, 20, 10, 40, 15]

def wide(x):
    y_centers = []
    heights = []
    x_wide = np.zeros_like(x)
    for i in range(len(x_wide)-1):
        center = (x_wide[i] + x_wide[i+1]) / 2
        height = x_wide[i+1] - x_wide[i]
        y_centers.append(center)
        heights.append(height)
    # Центральные разности для внутренних точек
    return y_centers,heights

# Рассчитываем центры и высоту столбцов для горизонтальной гистограммы
#y_centers = []
#heights = []
y_edging, x_edging= wide(x_edges)
#for i in range(len(x_edges)-1):
#    center = (x_edges[i] + x_edges[i+1]) / 2
#    height = x_edges[i+1] - x_edges[i]
#    x_centers.append(center)
#    heights.append(height)

# Создаем график с горизонтальными столбцами
plt.figure(figsize=(8, 10))
bars = plt.barh(y_edging, y_values, height=x_edging, align='center', 
                edgecolor='black', alpha=0.7, color='lightcoral', 
                label='Гистограмма')

# Инвертируем ось Y (чтобы числа шли сверху вниз в обратном порядке)
plt.gca().invert_yaxis()

# Устанавливаем подписи осей
plt.title('Неравномерная гистограмма (Horizontal Bar Chart)')
plt.xlabel('Ось Y')
plt.ylabel('Ось X (неравномерные точки)')

# Устанавливаем лимиты для оси Y (теперь вертикальной)
plt.ylim(1000, 2000)

# Добавляем сетку
plt.grid(True, linestyle='--', alpha=0.7, axis='x')

# Добавляем легенду
plt.legend()

plt.tight_layout()
plt.show()