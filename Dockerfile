FROM python:3.10-slim-buster
ENV PYTHONUNBUFFERED 1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    nginx \
    postgresql \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

RUN mkdir /code
WORKDIR /code
COPY . /code/

RUN service postgresql start && \
    su - postgres -c "psql -c \"CREATE DATABASE db;\"" && \
    su - postgres -c "psql -c \"CREATE USER admin WITH PASSWORD 'admin';\"" && \
    su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE db TO admin;\"" && \
    python manage.py migrate && sleep 5 && \
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin')" | python manage.py shell

RUN python manage.py collectstatic --noinput
RUN rm /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/sites-enabled/

EXPOSE 8000
EXPOSE 80

CMD service postgresql start && service nginx start && sleep 5 && gunicorn --bind 0.0.0.0:8000 project.wsgi
