# Stage 1: Node.js 의존성
FROM node:18 AS node-deps
WORKDIR /app
COPY frontend/package.json ./
RUN npm init -y && \
    npm install react react-dom next express axios lodash moment && \
    npm install webpack webpack-cli babel-loader @babel/core @babel/preset-env && \
    npm install typescript @types/react @types/node && \
    npm cache clean --force

# Stage 2: 프론트엔드 빌드
FROM node-deps AS frontend-build
WORKDIR /app/frontend
# 대량의 JavaScript 파일 생성
RUN mkdir -p src/components && \
    for i in $(seq 1 30); do \
      mkdir -p src/modules/module$i; \
      echo "// Large component file $i" > src/components/Component$i.js; \
      echo "export const Component$i = () => {" >> src/components/Component$i.js; \
      echo "  const data = [];" >> src/components/Component$i.js; \
      for j in $(seq 1 1000); do \
        echo "  data.push({ id: $j, value: 'item-$j' });" >> src/components/Component$i.js; \
      done; \
      echo "  return data;" >> src/components/Component$i.js; \
      echo "};" >> src/components/Component$i.js; \
    done && \
    echo "console.log('Build complete');" > src/index.js && \
    echo '{"scripts":{"build":"echo Building..."}}' > package.json && \
    npm run build

# Stage 3: Go 백엔드 빌드 - 버전 업그레이드
FROM golang:1.22-alpine AS go-deps
WORKDIR /go/src/app
# go.mod 파일 생성 - 특정 버전 지정으로 충돌 방지
RUN echo "module example/backend" > go.mod && \
    echo "go 1.22" >> go.mod && \
    go get github.com/gin-gonic/gin && \
    go get github.com/go-sql-driver/mysql && \
    go get github.com/lib/pq && \
    go get go.mongodb.org/mongo-driver/mongo && \
    go get github.com/spf13/viper && \
    go get github.com/prometheus/client_golang/prometheus

# Stage 4: 백엔드 빌드
FROM go-deps AS backend-build
WORKDIR /go/src/app

# 메인 파일 생성
RUN echo 'package main' > main.go && \
    echo '' >> main.go && \
    echo 'import "fmt"' >> main.go && \
    echo '' >> main.go && \
    echo 'func main() {' >> main.go && \
    echo '  fmt.Println("Hello")' >> main.go && \
    echo '}' >> main.go

# 대량의 Go 소스 파일 생성
RUN for i in $(seq 1 20); do \
      echo "package main" > module$i.go && \
      echo "" >> module$i.go && \
      echo "import \"fmt\"" >> module$i.go && \
      echo "" >> module$i.go && \
      echo "func init$i() {" >> module$i.go && \
      for j in $(seq 1 200); do \
        echo "  fmt.Println(\"Module $i initialized component $j\")" >> module$i.go; \
      done && \
      echo "}" >> module$i.go; \
    done && \
    # 의도적으로 무거운 빌드 활성화
    CGO_ENABLED=0 GOOS=linux go build -o /tmp/app

# Stage 5: 무거운 데이터 생성 (대용량 파일)  <-- 번호 수정
FROM ubuntu:22.04 AS data-build
WORKDIR /data
RUN apt-get update && \
    # 인위적으로 큰 파일 생성 (100MB)
    dd if=/dev/urandom of=large_file_1 bs=1M count=100 && \
    # 여러 개의 중간 크기 파일 생성
    for i in $(seq 1 5); do \
      dd if=/dev/urandom of=medium_file_$i bs=1M count=20; \
    done

# 최종 이미지
FROM ubuntu:22.04
WORKDIR /app
RUN apt-get update && \
    apt-get install -y nodejs && \
    apt-get clean && \
    mkdir -p /app/bin /app/frontend /app/backend /app/data

# 각 스테이지에서 빌드된 결과물 복사
COPY --from=frontend-build /app/frontend /app/frontend
COPY --from=backend-build /tmp/app /app/bin/app
COPY --from=data-build /data /app/data

# 이미지 메타데이터 추가
LABEL maintainer="Test User <test@example.com>"
LABEL version="1.0"
LABEL description="Heavy multi-stage build example for caching tests"

CMD ["/app/bin/app"]
