import matplotlib.pyplot as plt

# Данные (пример)
x_edges = [1800, 1800-25, 1800-60, 1800-275, 1800-595, 1800-700]
y_values = [5, 20, 10, 40, 15]

# Рассчитываем центры и ширину столбцов
x_centers = []
widths = []
for i in range(len(x_edges)-1):
    center = (x_edges[i] + x_edges[i+1]) / 2
    width = x_edges[i+1] - x_edges[i]
    x_centers.append(center)
    widths.append(width)

plt.figure(figsize=(12, 6))
plt.bar(x_centers, y_values, width=widths, align='center', edgecolor='black', alpha=0.7, color='lightcoral', label='Гистограмма')
plt.title('Неравномерная гистограмма (Bar Chart)')
plt.xlabel('Ось X (неравномерные точки)')
plt.ylabel('Ось Y')
plt.grid(True, linestyle='--', alpha=0.7, axis='y')
plt.xlim(1000, 2000)
plt.legend()
plt.show()