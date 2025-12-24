def read_right_file(filename):
    elr1 = []  # первый столбец: ElR1 (V)
    elr2 = []  # второй столбец: ElR2 (V)

    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()

            # пропускаем пустые строки и строки-комментарии
            if not line or line.startswith('%'):
                continue

            # делим по пробелам/табуляциям
            parts = line.split()
            if len(parts) < 2:
                # если вдруг строка битая
                continue

            # первые два столбца – в массивы (как числа с плавающей точкой)
            elr1.append(float(parts[0]))
            elr2.append(float(parts[1]))

    return elr1, elr2


if __name__ == "__main__":
    filename = "Right.txt"
    elr1, elr2 = read_right_file(filename)

    print("ElR1:", elr1)
    print("ElR2:", elr2)
