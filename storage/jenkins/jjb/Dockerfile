FROM python:2

WORKDIR /usr/src/app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY jobs jobs

RUN echo "hanging there ..." > fake.log
CMD ["tail", "-f", "fake.log"]
