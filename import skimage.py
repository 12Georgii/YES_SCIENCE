import numpy as np
import matplotlib.pyplot as plt
from scipy import sparse
from scipy.sparse.linalg import spsolve
from scipy.spatial import Delaunay
import matplotlib.tri as tri
from scipy.interpolate import griddata

class SimpleEITReconstructor:
    """
    Упрощенный реконструктор EIT изображений на методе обратной проекции
    """
    
    def __init__(self, n_electrodes=16, mesh_size=32):
        """
        Инициализация реконструктора
        
        Parameters:
        -----------
        n_electrodes : int
            Количество электродов
        mesh_size : int
            Размер сетки для реконструкции
        """
        self.n_electrodes = n_electrodes
        self.mesh_size = mesh_size
        self.angles = np.linspace(0, 2*np.pi, n_electrodes, endpoint=False)
        
        # Координаты электродов на окружности
        self.electrode_pos = np.array([
            [np.cos(theta), np.sin(theta)] 
            for theta in self.angles
        ])
        
    def generate_mesh(self):
        """Генерация треугольной сетки для реконструкции"""
        # Создаем точки внутри круга
        points = []
        for x in np.linspace(-1, 1, self.mesh_size):
            for y in np.linspace(-1, 1, self.mesh_size):
                if x**2 + y**2 <= 1:  # Только внутри круга
                    points.append([x, y])
        
        points = np.array(points)
        
        # Триангуляция Делоне
        tri_mesh = Delaunay(points)
        
        return points, tri_mesh.simplices
    
    def forward_simulate(self, anomaly_position=(0.3, 0.3), anomaly_radius=0.2, 
                         anomaly_conductivity=2.0, base_conductivity=1.0):
        """
        Симуляция измерений EIT (прямая задача)
        
        Parameters:
        -----------
        anomaly_position : tuple
            Позиция аномалии (x, y)
        anomaly_radius : float
            Радиус аномалии
        anomaly_conductivity : float
            Проводимость аномалии
        base_conductivity : float
            Базовая проводимость
            
        Returns:
        --------
        measurements : numpy.ndarray
            Измеренные напряжения для всех пар электродов
        """
        n = self.n_electrodes
        measurements = np.zeros((n, n))
        
        # Генерация фонового распределения проводимости
        points, _ = self.generate_mesh()
        
        # Создаем распределение проводимости
        conductivity = np.ones(points.shape[0]) * base_conductivity
        
        # Добавляем аномалию
        for i, (x, y) in enumerate(points):
            dist = np.sqrt((x - anomaly_position[0])**2 + 
                          (y - anomaly_position[1])**2)
            if dist < anomaly_radius:
                conductivity[i] = anomaly_conductivity
        
        # Упрощенная симуляция измерений
        # Реальная симуляция требует решения уравнения Лапласа,
        # здесь используется упрощенная модель
        for i in range(n):
            for j in range(n):
                if i != j:
                    # Ток между электродами i и j
                    # Простая модель: напряжение зависит от проводимости
                    # на пути между электродами
                    pos_i = self.electrode_pos[i]
                    pos_j = self.electrode_pos[j]
                    
                    # Вычисляем среднюю проводимость вдоль линии
                    t_values = np.linspace(0, 1, 50)
                    path_points = np.outer(1-t_values, pos_i) + np.outer(t_values, pos_j)
                    
                    # Интерполяция проводимости вдоль пути
                    path_conductivity = griddata(
                        points, conductivity, 
                        path_points, 
                        method='linear', 
                        fill_value=base_conductivity
                    )
                    
                    avg_conductivity = np.nanmean(path_conductivity)
                    
                    # Измеренное напряжение (упрощенная модель)
                    measurements[i, j] = 1.0 / avg_conductivity
        
        return measurements
    
    def back_projection_reconstruction(self, measurements):
        """
        Реконструкция изображения методом обратной проекции
        
        Parameters:
        -----------
        measurements : numpy.ndarray
            Матрица измерений
            
        Returns:
        --------
        reconstructed_image : numpy.ndarray
            Реконструированное изображение
        """
        # Преобразование измерений в вектор изменений
        n = self.n_electrodes
        delta_v = np.zeros(n * (n-1) // 2)
        
        idx = 0
        for i in range(n):
            for j in range(i+1, n):
                delta_v[idx] = measurements[i, j]
                idx += 1
        
        # Генерация сетки для реконструкции
        points, triangles = self.generate_mesh()
        
        # Инициализация реконструированного изображения
        image = np.zeros(points.shape[0])
        
        # Алгоритм обратной проекции
        for i in range(n):
            for j in range(i+1, n):
                # Ток между электродами i и j
                pos_i = self.electrode_pos[i]
                pos_j = self.electrode_pos[j]
                
                # Вычисляем чувствительность вдоль линии между электродами
                for k, point in enumerate(points):
                    x, y = point
                    
                    # Проекция на линию между электродами
                    v_ij = pos_j - pos_i
                    v_ip = np.array([x, y]) - pos_i
                    
                    # Расстояние до линии
                    t = np.dot(v_ip, v_ij) / np.dot(v_ij, v_ij)
                    t_clamped = max(0, min(1, t))
                    
                    # Ближайшая точка на отрезке
                    closest_point = pos_i + t_clamped * v_ij
                    distance = np.linalg.norm(np.array([x, y]) - closest_point)
                    
                    # Функция чувствительности (убывает с расстоянием)
                    sensitivity = np.exp(-distance**2 / 0.1)
                    
                    # Индекс в delta_v для этой пары электродов
                    pair_idx = i * (n-1) + j - (i*(i+1))//2 - 1
                    if pair_idx < len(delta_v):
                        image[k] += sensitivity * delta_v[pair_idx]
        
        # Нормализация
        if np.max(np.abs(image)) > 0:
            image = (image - np.min(image)) / (np.max(image) - np.min(image))
        
        return points, triangles, image
    
    def gauss_newton_reconstruction(self, measurements, iterations=10, lambda_reg=0.1):
        """
        Реализация метода Гаусса-Ньютона для реконструкции EIT
        
        Parameters:
        -----------
        measurements : numpy.ndarray
            Матрица измерений
        iterations : int
            Количество итераций
        lambda_reg : float
            Параметр регуляризации
            
        Returns:
        --------
        reconstructed_image : numpy.ndarray
            Реконструированное изображение
        """
        n = self.n_electrodes
        points, triangles = self.generate_mesh()
        n_points = points.shape[0]
        
        # Преобразование измерений в вектор
        n_measurements = n * (n-1) // 2
        V = np.zeros(n_measurements)
        
        idx = 0
        for i in range(n):
            for j in range(i+1, n):
                V[idx] = measurements[i, j]
                idx += 1
        
        # Инициализация проводимости
        sigma = np.ones(n_points) * 1.0
        
        # Создание матрицы чувствительности (Якобиана)
        J = np.zeros((n_measurements, n_points))
        
        print("Calculation of the sensitivity matrix...")
        for m in range(n_measurements):
            # Восстанавливаем пару электродов
            i, j = self._get_electrode_pair(m, n)
            
            # Упрощенное вычисление чувствительности
            for p in range(n_points):
                x, y = points[p]
                pos_i = self.electrode_pos[i]
                pos_j = self.electrode_pos[j]
                
                # Расстояние до обоих электродов
                d_i = np.sqrt((x - pos_i[0])**2 + (y - pos_i[1])**2)
                d_j = np.sqrt((x - pos_j[0])**2 + (y - pos_j[1])**2)
                
                # Упрощенная модель чувствительности
                sensitivity = np.exp(-(d_i + d_j) / 0.5)
                J[m, p] = sensitivity
        
        # Регуляризация
        L = sparse.eye(n_points).tocsr()
        
        # Итеративный метод Гаусса-Ньютона
        for it in range(iterations):
            print(f"Iteration {it+1}/{iterations}")
            
            # Предсказанные измерения
            V_pred = J @ sigma
            
            # Невязка
            residual = V - V_pred
            
            # Решение нормальных уравнений с регуляризацией
            JtJ = J.T @ J
            JtJ_reg = JtJ + lambda_reg * L
            
            # Обновление проводимости
            delta_sigma = np.linalg.solve(JtJ_reg, J.T @ residual)
            sigma += delta_sigma
            
            # Ограничение значений проводимости
            sigma = np.clip(sigma, 0.1, 5.0)
            
            # Вывод невязки
            print(f"  The discrepancy: {np.linalg.norm(residual):.4f}")
        
        return points, triangles, sigma
    
    def _get_electrode_pair(self, idx, n_electrodes):
        """Восстановление пары электродов по индексу измерения"""
        i = 0
        while idx >= (n_electrodes - i - 1):
            idx -= (n_electrodes - i - 1)
            i += 1
        j = i + idx + 1
        return i, j
    
    def visualize(self, points, triangles, image, title="Reconstruction EIT"):
        """Visualization of the reconstructed image"""
        # Создаем сетку для интерполяции
        xi = np.linspace(-1, 1, 100)
        yi = np.linspace(-1, 1, 100)
        Xi, Yi = np.meshgrid(xi, yi)
        
        # Интерполяция на регулярную сетку
        Zi = griddata(points, image, (Xi, Yi), method='cubic', fill_value=0)
        
        # Маска для области вне круга
        mask = Xi**2 + Yi**2 > 1
        Zi[mask] = np.nan
        
        # Построение графиков
        fig, axes = plt.subplots(1, 2, figsize=(12, 5))
        
        # Треугольная сетка
        axes[0].triplot(points[:, 0], points[:, 1], triangles, linewidth=0.2, color='gray')
        scatter = axes[0].scatter(points[:, 0], points[:, 1], c=image, 
                                 cmap='viridis', s=20, edgecolors='k', linewidth=0.2)
        axes[0].scatter(self.electrode_pos[:, 0], self.electrode_pos[:, 1], 
                       c='red', s=50, marker='s', label='Electrodes')
        axes[0].set_aspect('equal')
        axes[0].set_title('Reconstruction on a triangular grid')
        axes[0].legend()
        plt.colorbar(scatter, ax=axes[0])
        
        # Интерполированное изображение
        im = axes[1].imshow(Zi, extent=(-1, 1, -1, 1), 
                           origin='lower', cmap='viridis')
        axes[1].scatter(self.electrode_pos[:, 0], self.electrode_pos[:, 1], 
                       c='red', s=50, marker='s')
        axes[1].set_aspect('equal')
        axes[1].set_title(title)
        plt.colorbar(im, ax=axes[1])
        
        plt.tight_layout()
        plt.show()

def load_eit_data(filepath):
    """
    Загрузка данных EIT из файла
    
    Parameters:
    -----------
    filepath : str
        Путь к файлу с данными
        
    Returns:
    --------
    measurements : numpy.ndarray
        Матрица измерений
    metadata : dict
        Метаданные измерений
    """
    import json
    
    # Для CSV формата
    if filepath.endswith('.csv'):
        data = np.loadtxt(filepath, delimiter=',')
        
        # Предполагаем формат: пары электродов и измерение
        n_electrodes = int(np.sqrt(data.shape[0]))
        measurements = np.zeros((n_electrodes, n_electrodes))
        
        for row in data:
            i, j, value = int(row[0]), int(row[1]), row[2]
            measurements[i, j] = value
            
        metadata = {'n_electrodes': n_electrodes}
        
    # Для JSON формата
    elif filepath.endswith('.json'):
        with open(filepath, 'r') as f:
            data_dict = json.load(f)
        
        measurements = np.array(data_dict['measurements'])
        metadata = data_dict.get('metadata', {})
    
    else:
        raise ValueError("Формат файла не поддерживается. Используйте .csv или .json")
    
    return measurements, metadata

# Пример использования с реальными данными
def process_real_data(filepath):
    """Обработка реальных данных EIT"""
    
    # Загрузка данных
    measurements, metadata = load_eit_data(filepath)
    n_electrodes = metadata.get('n_electrodes', 16)
    
    # Создание реконструктора
    reconstructor = SimpleEITReconstructor(n_electrodes=n_electrodes)
    
    # Реконструкция
    points, triangles, image = reconstructor.back_projection_reconstruction(measurements)
    
    # Визуализация
    reconstructor.visualize(points, triangles, image, "Реконструкция реальных данных")
    
    return image

# Пример использования
if __name__ == "__main__":
    # Создаем реконструктор
    reconstructor = SimpleEITReconstructor(n_electrodes=16, mesh_size=40)
    
    print("Simulating image of EIT...")
    # Симуляция измерений (в реальности здесь будут ваши данные)
    measurements = reconstructor.forward_simulate(
        anomaly_position=(0.4, 0.3),
        anomaly_radius=0.25,
        anomaly_conductivity=2.5
    )
    
    print("Reverse projection reconstruction...")
    # Реконструкция методом обратной проекции
    points_bp, triangles_bp, image_bp = reconstructor.back_projection_reconstruction(measurements)
    reconstructor.visualize(points_bp, triangles_bp, image_bp, 
                           "Reverse projection")
    
    print("Reconstruction by the Gauss-Newton method...")
    # Реконструкция методом Гаусса-Ньютона
    points_gn, triangles_gn, image_gn = reconstructor.gauss_newton_reconstruction(
        measurements, iterations=5, lambda_reg=0.01
    )
    reconstructor.visualize(points_gn, triangles_gn, image_gn,
                           "Gauss-Newton")
    
    # Визуализация измерений
    plt.figure(figsize=(8, 6))
    plt.imshow(measurements, cmap='viridis', aspect='auto')
    plt.colorbar(label='Measured voltage')
    plt.title('The measurement matrix EIT')
    plt.xlabel('Source electrode')
    plt.ylabel('Receiver electrode')
    plt.show()