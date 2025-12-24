import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Загрузка данных из CSV-файла
file_path = 'test_eit_data.csv'  # Укажите путь к файлу
data = pd.read_csv(file_path)

# Игнорирование первого столбца
data = data.iloc[:, 1:]

# Создание графиков для каждого столбца
fig, axes = plt.subplots(nrows=data.shape[1], figsize=(12, 3*data.shape[1]))

# Обработка каждого столбца
for i, col in enumerate(data.columns):
    # Получаем данные столбца
    column_data = data[col]
    
    # Фильтруем значения, оставляем только <= 100
    filtered_data = column_data[column_data <= 100].dropna()
    
    # Вычисляем разности между соседними значениями
    differences = filtered_data.diff()
    
    # Создаем подграфик
    ax = axes[i] if data.shape[1] > 1 else axes
    
    # График исходных данных (без значений >100)
    ax.plot(filtered_data.index, filtered_data, 'b-', marker='o', 
            label=f'Исходные данные ({col})', alpha=0.7)
    
    # График разностей
    ax.plot(differences.index, differences, 'r--', marker='s', 
            label=f'Разности ({col})', alpha=0.7)
    
    # Добавляем горизонтальную линию на уровне 0 для разностей
    ax.axhline(y=0, color='gray', linestyle='-', alpha=0.3)
    
    ax.set_ylabel('Значения')
    ax.set_title(f'Столбец: {col}')
    ax.grid(True)
    ax.legend()

plt.xlabel('Индекс строк')
plt.tight_layout()
plt.show()

# Альтернатива: отдельные графики для разностей
fig, axes = plt.subplots(nrows=data.shape[1], figsize=(12, 3*data.shape[1]))

for i, col in enumerate(data.columns):
    # Получаем данные столбца
    column_data = data[col]
    
    # Фильтруем значения, оставляем только <= 100
    filtered_data = column_data[column_data <= 100].dropna()
    
    # Вычисляем разности между соседними значениями
    differences = filtered_data.diff().dropna()  # Удаляем первый NaN
    
    # Создаем подграфик
    ax = axes[i] if data.shape[1] > 1 else axes
    
    # Гистограмма разностей
    ax.hist(differences, bins=20, edgecolor='black', alpha=0.7)
    ax.set_xlabel('Величина разности')
    ax.set_ylabel('Частота')
    ax.set_title(f'Распределение разностей для столбца: {col}')
    ax.grid(True, alpha=0.3)

plt.tight_layout()
plt.show()

# График всех разностей на одном полотне
plt.figure(figsize=(14, 8))

for col in data.columns:
    # Получаем данные столбца
    column_data = data[col]
    
    # Фильтруем значения, оставляем только <= 100
    filtered_data = column_data[column_data <= 100].dropna()
    
    # Вычисляем разности между соседними значениями
    differences = filtered_data.diff().dropna()
    
    # График разностей для каждого столбца
    plt.plot(differences.index, differences, marker='o', 
             label=f'Разности ({col})', alpha=0.7, linewidth=2)

plt.xlabel('Индекс строк')
plt.ylabel('Величина разности')
plt.title('Графики разностей между соседними значениями для всех столбцов')
plt.legend()
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.show()

# Сводная статистика по разностям
print("Сводная статистика по разностям между соседними значениями:")
print("=" * 60)

for col in data.columns:
    # Получаем данные столбца
    column_data = data[col]
    
    # Фильтруем значения, оставляем только <= 100
    filtered_data = column_data[column_data <= 100].dropna()
    
    # Вычисляем разности между соседними значениями
    differences = filtered_data.diff().dropna()
    
    if not differences.empty:
        print(f"\nСтолбец: {col}")
        print(f"  Количество разностей: {len(differences)}")
        print(f"  Средняя разность: {differences.mean():.4f}")
        print(f"  Стандартное отклонение: {differences.std():.4f}")
        print(f"  Минимальная разность: {differences.min():.4f}")
        print(f"  Максимальная разность: {differences.max():.4f}")
        print(f"  Медиана разности: {differences.median():.4f}")
    else:
        print(f"\nСтолбец: {col} - недостаточно данных для вычисления разностей")

print("\n" + "=" * 60)