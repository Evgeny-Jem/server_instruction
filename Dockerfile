# Используем официальный образ Python
FROM python:3.11.5

# Устанавливаем рабочую директорию в контейнере
WORKDIR /app

# Копируем зависимости и устанавливаем их
COPY requirements.txt .
RUN pip install --upgrade pip setuptools
RUN pip install -r requirements.txt
RUN chmod 755 .

# Копируем исходный код в контейнер
COPY . .

# Указываем команду для запуска приложения
CMD ["python", "app.py"] # Указываем название вашего главного файла
