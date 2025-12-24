import numpy as np
import matplotlib.pyplot as plt
from scipy import sparse
from scipy.sparse.linalg import spsolve
from scipy.spatial import Delaunay
import matplotlib.tri as tri
from scipy.interpolate import griddata
import csv
import json
import sys
import os

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
    
    def process_measurements(self, raw_measurements, method='normalize'):
        """
        Предобработка измерений EIT: удаление шума, обработка выбросов, нормализация
        
        Parameters:
        -----------
        raw_measurements : numpy.ndarray
            Сырые измерения (полная матрица NxN)
        method : str
            Метод обработки: 'normalize', 'baseline', 'diff'
            
        Returns:
        --------
        processed_measurements : numpy.ndarray
            Обработанные измерения
        """
        n = self.n_electrodes
        
        # 1. Создаем копию, чтобы не изменять исходные данные
        measurements = raw_measurements.copy()
        
        # 2. Обработка диагональных элементов (измерения на токовых электродах)
        # Для каждого электрода i, измерение V[i,i] обычно не используется
        # или содержит информацию о контактном сопротивлении
        for i in range(n):
            # Вариант 1: Заменить на среднее соседних измерений
            # Вариант 2: Установить в 0
            # Вариант 3: Оставить как есть
            measurements[i, i] = 0.0  # Устанавливаем в 0
            
        # 3. Нормализация измерений
        if method == 'normalize':
            # Нормализуем каждое измерение относительно максимального значения
            max_val = np.max(np.abs(measurements))
            if max_val > 0:
                measurements = measurements / max_val
                
        elif method == 'baseline' and hasattr(self, 'baseline_measurements'):
            # Вычитание фоновых измерений
            measurements = measurements - self.baseline_measurements
            
        elif method == 'diff':
            # Используем разность напряжений между противоположными парами
            diff_measurements = np.zeros((n, n))
            for i in range(n):
                for j in range(n):
                    if i != j:
                        # Разность между измерением и "симметричным"
                        opp_j = (j + n//2) % n
                        diff_measurements[i, j] = measurements[i, j] - measurements[i, opp_j]
            measurements = diff_measurements
            
        # 4. Удаление выбросов (используем медианный фильтр для каждой строки)
        for i in range(n):
            row = measurements[i, :]
            median = np.median(row)
            std = np.std(row)
            # Заменяем значения, отклоняющиеся более чем на 3 сигмы
            outliers = np.abs(row - median) > 3 * std
            measurements[i, outliers] = median
            
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
        
        print("Вычисление матрицы чувствительности...")
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
            print(f"Итерация {it+1}/{iterations}")
            
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
            print(f"  Невязка: {np.linalg.norm(residual):.4f}")
        
        return points, triangles, sigma
    
    def _get_electrode_pair(self, idx, n_electrodes):
        """Восстановление пары электродов по индексу измерения"""
        i = 0
        while idx >= (n_electrodes - i - 1):
            idx -= (n_electrodes - i - 1)
            i += 1
        j = i + idx + 1
        return i, j
    
    def visualize(self, points, triangles, image, title="Реконструкция EIT", 
                 save_path=None, show_electrodes=True):
        """Визуализация реконструированного изображения"""
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
        fig, axes = plt.subplots(1, 2, figsize=(14, 6))
        
        # Треугольная сетка
        axes[0].triplot(points[:, 0], points[:, 1], triangles, linewidth=0.2, color='gray')
        scatter = axes[0].scatter(points[:, 0], points[:, 1], c=image, 
                                 cmap='viridis', s=20, edgecolors='k', linewidth=0.2)
        if show_electrodes:
            axes[0].scatter(self.electrode_pos[:, 0], self.electrode_pos[:, 1], 
                           c='red', s=50, marker='s', label='Электроды')
        axes[0].set_aspect('equal')
        axes[0].set_title('Реконструкция на треугольной сетке')
        if show_electrodes:
            axes[0].legend()
        plt.colorbar(scatter, ax=axes[0], label='Относительная проводимость')
        
        # Интерполированное изображение
        im = axes[1].imshow(Zi, extent=(-1, 1, -1, 1), 
                           origin='lower', cmap='viridis')
        if show_electrodes:
            axes[1].scatter(self.electrode_pos[:, 0], self.electrode_pos[:, 1], 
                           c='red', s=50, marker='s')
        axes[1].set_aspect('equal')
        axes[1].set_title(title)
        axes[1].set_xlabel('X')
        axes[1].set_ylabel('Y')
        plt.colorbar(im, ax=axes[1], label='Относительная проводимость')
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Изображение сохранено в {save_path}")
        
        plt.show()
        
        return fig, axes
    
    def visualize_measurements(self, measurements, title="Матрица измерений EIT"):
        """Визуализация матрицы измерений"""
        fig, ax = plt.subplots(1, 2, figsize=(12, 5))
        
        # Полная матрица
        im1 = ax[0].imshow(measurements, cmap='viridis', aspect='auto')
        ax[0].set_title(f'{title} (полная)')
        ax[0].set_xlabel('Электрод приемника')
        ax[0].set_ylabel('Электрод источника')
        plt.colorbar(im1, ax=ax[0], label='Напряжение')
        
        # Только используемые пары (без диагонали)
        usable_meas = measurements.copy()
        np.fill_diagonal(usable_meas, np.nan)
        im2 = ax[1].imshow(usable_meas, cmap='viridis', aspect='auto')
        ax[1].set_title(f'{title} (используемые пары)')
        ax[1].set_xlabel('Электрод приемника')
        ax[1].set_ylabel('Электрод источника')
        plt.colorbar(im2, ax=ax[1], label='Напряжение')
        
        plt.tight_layout()
        plt.show()


def load_eit_data(filepath, n_electrodes=None, format_type='auto'):
    """
    Загрузка данных EIT из файла
    
    Parameters:
    -----------
    filepath : str
        Путь к файлу с данными
    n_electrodes : int, optional
        Количество электродов (если None, определяется автоматически)
    format_type : str
        Тип формата: 'auto', 'pairs', 'matrix', 'full_matrix'
        
    Returns:
    --------
    measurements : numpy.ndarray
        Матрица измерений NxN
    metadata : dict
        Метаданные измерений
    """
    metadata = {'filename': os.path.basename(filepath)}
    
    # Для CSV формата
    if filepath.endswith('.csv'):
        try:
            with open(filepath, 'r') as f:
                # Читаем первые несколько строк для определения формата
                lines = [f.readline() for _ in range(5)]
                f.seek(0)
                
                # Определение формата
                if format_type == 'auto':
                    # Проверяем, есть ли заголовок
                    first_line = lines[0].strip().split(',')
                    
                    if len(first_line) == 2:
                        format_type = 'matrix'
                    elif any(h in first_line[0].lower() for h in ['source', 'electrode', 'src']):
                        format_type = 'pairs'
                    else:
                        # Пытаемся определить по данным
                        try:
                            float(first_line[0])
                            if len(first_line) >= 3:
                                format_type = 'pairs'
                            else:
                                format_type = 'matrix'
                        except:
                            format_type = 'pairs'  # По умолчанию
                
                reader = csv.reader(f)
                
                if format_type == 'pairs':
                    # Формат: source, receiver, voltage (возможно с заголовком)
                    data_dict = {}
                    max_electrode = -1
                    row_count = 0
                    
                    for row_idx, row in enumerate(reader):
                        if not row:
                            continue
                            
                        # Пропускаем строки с заголовком, если они есть
                        if row_idx == 0 and not row[0].replace('.', '').replace('-', '').isdigit():
                            continue
                        
                        if len(row) >= 3:
                            try:
                                src = int(float(row[0]))
                                rec = int(float(row[1]))
                                voltage = float(row[2])
                                
                                max_electrode = max(max_electrode, src, rec)
                                
                                # Сохраняем измерение
                                if src not in data_dict:
                                    data_dict[src] = {}
                                data_dict[src][rec] = voltage
                                
                                row_count += 1
                            except ValueError as e:
                                print(f"Предупреждение: ошибка в строке {row_idx}: {e}")
                                continue
                    
                    # Определяем количество электродов
                    if n_electrodes is None:
                        n_electrodes = max_electrode + 1
                        print(f"Автоопределено количество электродов: {n_electrodes}")
                    
                    # Создаем матрицу измерений
                    measurements = np.zeros((n_electrodes, n_electrodes))
                    
                    for src in range(n_electrodes):
                        for rec in range(n_electrodes):
                            if src in data_dict and rec in data_dict[src]:
                                measurements[src, rec] = data_dict[src][rec]
                    
                    metadata.update({
                        'n_electrodes': n_electrodes,
                        'format': 'pairs',
                        'total_measurements': row_count
                    })
                    
                elif format_type == 'matrix':
                    # Формат матрицы: каждая строка - измерения для одного источника
                    data = []
                    row_count = 0
                    
                    for row_idx, row in enumerate(reader):
                        if not row:
                            continue
                            
                        # Пропускаем заголовок
                        if row_idx == 0 and not row[0].replace('.', '').replace('-', '').isdigit():
                            continue
                        
                        # Конвертируем строку в числа
                        try:
                            row_data = [float(x) if x else 0.0 for x in row]
                            data.append(row_data)
                            row_count += 1
                        except ValueError as e:
                            print(f"Предупреждение: ошибка в строке {row_idx}: {e}")
                            continue
                    
                    measurements = np.array(data)
                    
                    if n_electrodes is None:
                        n_electrodes = measurements.shape[0]
                        print(f"Автоопределено количество электродов: {n_electrodes}")
                    
                    # Проверяем размеры
                    if measurements.shape[0] != measurements.shape[1]:
                        print(f"Предупреждение: матрица не квадратная ({measurements.shape}). Обрезаем до меньшего размера.")
                        min_dim = min(measurements.shape[0], measurements.shape[1])
                        measurements = measurements[:min_dim, :min_dim]
                        n_electrodes = min_dim
                    
                    metadata.update({
                        'n_electrodes': n_electrodes,
                        'format': 'matrix',
                        'shape': measurements.shape
                    })
                
        except Exception as e:
            raise ValueError(f"Ошибка при чтении CSV файла: {e}")
    
    # Для JSON формата
    elif filepath.endswith('.json'):
        try:
            with open(filepath, 'r') as f:
                data_dict = json.load(f)
            
            if 'measurements' in data_dict:
                measurements = np.array(data_dict['measurements'])
                n_electrodes = measurements.shape[0]
            else:
                raise ValueError("JSON файл должен содержать ключ 'measurements'")
            
            metadata = data_dict.get('metadata', {})
            metadata['n_electrodes'] = n_electrodes
            metadata['format'] = 'json'
            
        except Exception as e:
            raise ValueError(f"Ошибка при чтении JSON файла: {e}")
    
    else:
        raise ValueError("Формат файла не поддерживается. Используйте .csv или .json")
    
    print(f"Загружено: {metadata['n_electrodes']} электродов, матрица {measurements.shape}")
    print(f"Диапазон значений: [{np.min(measurements):.4f}, {np.max(measurements):.4f}]")
    print(f"Среднее значение: {np.mean(measurements):.4f}")
    
    return measurements, metadata


def analyze_measurements(measurements):
    """
    Анализ матрицы измерений
    
    Parameters:
    -----------
    measurements : numpy.ndarray
        Матрица измерений NxN
        
    Returns:
    --------
    analysis : dict
        Результаты анализа
    """
    n = measurements.shape[0]
    
    analysis = {
        'n_electrodes': n,
        'total_measurements': n * n,
        'diagonal_values': np.diag(measurements),
        'off_diagonal_mean': np.mean(measurements[~np.eye(n, dtype=bool)]),
        'off_diagonal_std': np.std(measurements[~np.eye(n, dtype=bool)]),
        'symmetry_error': np.mean(np.abs(measurements - measurements.T)) / np.mean(np.abs(measurements)),
        'row_means': np.mean(measurements, axis=1),
        'col_means': np.mean(measurements, axis=0)
    }
    
    # Проверка на симметричность
    is_symmetric = np.allclose(measurements, measurements.T, rtol=1e-3)
    analysis['is_symmetric'] = is_symmetric
    
    # Количество значимых измерений (больше шума)
    noise_threshold = analysis['off_diagonal_std'] * 0.1
    significant_count = np.sum(np.abs(measurements[~np.eye(n, dtype=bool)]) > noise_threshold)
    analysis['significant_measurements'] = significant_count
    
    return analysis


def reconstruct_from_file(filepath, n_electrodes=None, reconstruction_method='back_projection', 
                         save_results=False, output_dir='results'):
    """
    Полный пайплайн реконструкции EIT из файла
    
    Parameters:
    -----------
    filepath : str
        Путь к файлу с данными
    n_electrodes : int, optional
        Количество электродов
    reconstruction_method : str
        Метод реконструкции: 'back_projection' или 'gauss_newton'
    save_results : bool
        Сохранять ли результаты
    output_dir : str
        Директория для сохранения результатов
        
    Returns:
    --------
    results : dict
        Результаты реконструкции
    """
    print("=" * 60)
    print(f"РЕКОНСТРУКЦИЯ EIT ИЗ ФАЙЛА: {filepath}")
    print("=" * 60)
    
    # Создаем директорию для результатов
    if save_results and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # 1. Загрузка данных
    print("\n1. Загрузка данных...")
    measurements, metadata = load_eit_data(filepath, n_electrodes)
    
    # 2. Анализ данных
    print("\n2. Анализ измерений...")
    analysis = analyze_measurements(measurements)
    
    print(f"   Количество электродов: {analysis['n_electrodes']}")
    print(f"   Среднее значение вне диагонали: {analysis['off_diagonal_mean']:.4f}")
    print(f"   Стандартное отклонение: {analysis['off_diagonal_std']:.4f}")
    print(f"   Ошибка симметрии: {analysis['symmetry_error']:.4f}")
    print(f"   Матрица {'симметрична' if analysis['is_symmetric'] else 'не симметрична'}")
    
    # 3. Создание реконструктора
    print(f"\n3. Создание реконструктора...")
    reconstructor = SimpleEITReconstructor(
        n_electrodes=analysis['n_electrodes'],
        mesh_size=40
    )
    
    # 4. Предобработка измерений
    print("\n4. Предобработка измерений...")
    processed_measurements = reconstructor.process_measurements(
        measurements, 
        method='normalize'
    )
    
    # 5. Визуализация исходных данных
    print("\n5. Визуализация измерений...")
    reconstructor.visualize_measurements(processed_measurements, "Обработанные измерения")
    
    # 6. Реконструкция изображения
    print(f"\n6. Реконструкция методом: {reconstruction_method}...")
    
    if reconstruction_method == 'back_projection':
        points, triangles, image = reconstructor.back_projection_reconstruction(
            processed_measurements
        )
    elif reconstruction_method == 'gauss_newton':
        points, triangles, image = reconstructor.gauss_newton_reconstruction(
            processed_measurements, 
            iterations=5, 
            lambda_reg=0.01
        )
    else:
        raise ValueError(f"Неизвестный метод реконструкции: {reconstruction_method}")
    
    # 7. Визуализация результата
    print("\n7. Визуализация реконструкции...")
    title = f"Реконструкция EIT: {os.path.basename(filepath)} ({reconstruction_method})"
    
    if save_results:
        save_path = os.path.join(output_dir, f"reconstruction_{os.path.splitext(os.path.basename(filepath))[0]}.png")
    else:
        save_path = None
    
    fig, axes = reconstructor.visualize(
        points, triangles, image, 
        title=title,
        save_path=save_path
    )
    
    # 8. Сохранение результатов
    results = {
        'metadata': metadata,
        'analysis': analysis,
        'measurements': measurements,
        'processed_measurements': processed_measurements,
        'points': points,
        'triangles': triangles,
        'image': image,
        'reconstructor': reconstructor
    }
    
    if save_results:
        # Сохраняем данные реконструкции
        np.savez(
            os.path.join(output_dir, f"reconstruction_{os.path.splitext(os.path.basename(filepath))[0]}.npz"),
            points=points,
            triangles=triangles,
            image=image,
            measurements=measurements
        )
        
        # Сохраняем метаданные
        with open(os.path.join(output_dir, f"metadata_{os.path.splitext(os.path.basename(filepath))[0]}.json"), 'w') as f:
            json.dump({
                'metadata': metadata,
                'analysis': {k: (float(v) if isinstance(v, (np.float32, np.float64)) else v) 
                           for k, v in analysis.items()}
            }, f, indent=2)
        
        print(f"\nРезультаты сохранены в директории: {output_dir}")
    
    print("\n" + "=" * 60)
    print("РЕКОНСТРУКЦИЯ ЗАВЕРШЕНА")
    print("=" * 60)
    
    return results


def main():
    """Основная функция"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Реконструкция изображений EIT из файла')
    parser.add_argument('filepath', type=str, help='Путь к файлу с данными EIT')
    parser.add_argument('--electrodes', '-n', type=int, default=None, 
                       help='Количество электродов (если не указано, определяется автоматически)')
    parser.add_argument('--method', '-m', type=str, default='back_projection',
                       choices=['back_projection', 'gauss_newton'],
                       help='Метод реконструкции')
    parser.add_argument('--save', '-s', action='store_true',
                       help='Сохранять результаты в файлы')
    parser.add_argument('--output', '-o', type=str, default='results',
                       help='Директория для сохранения результатов')
    
    args = parser.parse_args()
    
    # Проверяем существование файла
    if not os.path.exists(args.filepath):
        print(f"Ошибка: файл {args.filepath} не найден")
        return
    
    try:
        # Запускаем реконструкцию
        results = reconstruct_from_file(
            filepath=args.filepath,
            n_electrodes=args.electrodes,
            reconstruction_method=args.method,
            save_results=args.save,
            output_dir=args.output
        )
        
        return results
        
    except Exception as e:
        print(f"Ошибка при выполнении реконструкции: {e}")
        import traceback
        traceback.print_exc()
        return None


if __name__ == "__main__":
    # Если файл передан как аргумент командной строки
#    if len(sys.argv) > 1:
#        main()
#    else:
#        # Демонстрационный режим: создаем тестовые данные и реконструируем
#        print("Запуск в демонстрационном режиме...")
#        
#        # Создаем тестовый CSV файл
#        test_data = []
#        n_electrodes = 16
#        
#        for i in range(n_electrodes):
#            for j in range(n_electrodes):
#                if i == j:
#                    # Измерения на токовых электродах (обычно высокие значения)
#                    voltage = 0.5 + np.random.normal(0, 0.1)
#                else:
#                    # Обычные измерения
#                    distance = abs(i - j) / n_electrodes
#                    voltage = 1.0 / (1.0 + distance) + np.random.normal(0, 0.05)
#                
#                test_data.append([i, j, voltage])
#        
#        # Сохраняем тестовый файл
#        with open('test_eit_data.csv', 'w', newline='') as f:
#            writer = csv.writer(f)
#            writer.writerow(['source', 'receiver', 'voltage'])
#            writer.writerows(test_data)
#        
#        print("Создан тестовый файл: test_eit_data.csv")
        
        # Запускаем реконструкцию
        results = reconstruct_from_file(
            filepath='test_eit_data_LEFT.csv',
            n_electrodes=16,
            reconstruction_method='back_projection',
            save_results=False
        )