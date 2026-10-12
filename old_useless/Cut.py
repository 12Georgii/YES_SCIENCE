import numpy as np
import matplotlib.pyplot as plt

"""
HEAD (Ω)
-3.917871679694555E-5
MIDDLEHEAD (Ω)
-0.05800775466598876
ARMPITS (Ω)
9.67850430347695
APERTURE (Ω)
0.4693664053745494
LEGS (Ω)
-1.1629444915553873E-4
126.75198653271468
"""

# 1. Ввод данных (пример с тестовыми данными)
x = np.array([0, 1, 2, 3, 4])
y = np.array([3.9178879357895586E-5, 0.1574274255139636, 126.75198653271468-9.711108303599143, 126.75198653271468-1.0966394813670932, 126.75198653271468-1.1629874228486254E-4])

print("Y значения:", y)
#print("Производная:", dy_dx)

#x1 = np.array([0, 1, 2, 3, 4])
#y1 = np.array([])

# Замените массивы x и y своими данными, например:
# x = np.array([ваши_значения])
# y = np.array([ваши_значения])

# 2. Вычисление производной (центральные разности)
"""def compute_derivative(x, y):
    dy_dx = np.zeros_like(y)
    
    # Центральные разности для внутренних точек
    for i in range(1, len(y)-1):
        dy_dx[i] = (y[i+1] - y[i-1]) / (x[i+1] - x[i-1])
    
    # Односторонние разности для краев
    dy_dx[0] = (y[1] - y[0]) / (x[1] - x[0])
    dy_dx[-1] = (y[-1] - y[-2]) / (x[-1] - x[-2])
    
    return dy_dx

#dy_dx = compute_derivative(x, y)

# 3. Построение графиков
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))

# График исходной функции
ax1.scatter(x, y, color='red', label='Исходный импеданс по срезам', zorder=3)
ax1.plot(x, y, 'b-', label='Аппроксимация', linewidth=2)
ax1.set_xlabel('Sn', fontsize=12)
ax1.set_ylabel('Z', fontsize=12)
ax1.set_title('Исходный импеданс по срезам', fontsize=14)
ax1.grid(True, alpha=0.3)
ax1.legend()
"""

"""

# График производной
ax2.scatter(x, dy_dx, color='green', label='График производной импеданса по оси X', zorder=3)
ax2.plot(x, dy_dx, 'm-', label='Производная (аппроксимация)', linewidth=2)
ax2.axhline(y=0, color='black', linestyle='--', alpha=0.3)
ax2.set_xlabel('X', fontsize=12)
ax2.set_ylabel('dZ/dx', fontsize=12)
ax2.set_title('График производной импеданса по оси X', fontsize=14)
ax2.grid(True, alpha=0.3)
ax2.legend()

plt.tight_layout()
plt.show()

print("X значения:", x)
print("Y значения:", y)
print("Производная:", dy_dx)
"""

"""
dy1_dx = compute_derivative(x1, y1)

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))

# График исходной функции
ax1.scatter(x1, y1, color='red', label='Исходный импеданс по срезам', zorder=3)
ax1.plot(x1, y1, 'b-', label='Аппроксимация', linewidth=2)
ax1.set_xlabel('X', fontsize=12)
ax1.set_ylabel('Z', fontsize=12)
ax1.set_title('Исходный импеданс по срезам', fontsize=14)
ax1.grid(True, alpha=0.3)
ax1.legend()

# График производной
ax2.scatter(x1, dy1_dx, color='green', label='График производной импеданса по оси X', zorder=3)
ax2.plot(x1, dy1_dx, 'm-', label='Производная (аппроксимация)', linewidth=2)
ax2.axhline(y=0, color='black', linestyle='--', alpha=0.3)
ax2.set_xlabel('X', fontsize=12)
ax2.set_ylabel('dZ/dx', fontsize=12)
ax2.set_title('График производной импеданса по оси X', fontsize=14)
ax2.grid(True, alpha=0.3)
ax2.legend()

plt.tight_layout()
plt.show()
"""