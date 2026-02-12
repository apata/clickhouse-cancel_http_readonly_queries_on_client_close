# Minimal repro for Clickhouse option `cancel_http_readonly_queries_on_client_close`

This is a minimal repro for showing that the option `cancel_http_readonly_queries_on_client_close` does not work with https queries when the client disconnects in a particular way.

## Setup

```sh
docker compose up --build -d
```

## Steps to reproduce

#### 1. Make a long-running **https** request, cancel the request gracefully

```sh
curl -k -m 1 'https://localhost:8443/?cancel_http_readonly_queries_on_client_close=1&query=SELECT+count(*)+FROM+numbers(1000000000)+WHERE+sipHash64(number)+%25+1000000+%3D+0'
```

This command should timeout in the terminal. If it does not, increase the number within `numbers(...)`.

#### 2. Make a long-running **https** request, cancel the request abruptly

```sh
timeout 1s curl -k -m 2 'https://localhost:8443/?cancel_http_readonly_queries_on_client_close=1&query=SELECT+count(*)+FROM+numbers(1000000000)+WHERE+sipHash64(number)+%25+2000000+%3D+0'
```

#### 3. Make a long-running **http** query with client side timeout

```sh
curl -m 1 'http://localhost:8123/?cancel_http_readonly_queries_on_client_close=1&query=SELECT+count(*)+FROM+numbers(1000000000)+WHERE+sipHash64(number)+%25+3000000+%3D+0'
```

#### 4. Check the queries in `system.query_log` table

```sh
docker compose exec clickhouse clickhouse-client "FROM system.query_log SELECT query_duration_ms, query, type, exception, exception_code, Settings, is_secure WHERE (query LIKE '%sipHash%') AND (query NOT LIKE '%like%') AND type > 1 ORDER BY event_time DESC LIMIT 3 FORMAT PrettyCompact"
```

## Expected result

All queries are canceled on the client dropping out.

## Actual result

The query from the https request that's allowed to time out gracefully is not canceled.
The other queries are canceled on the client dropping out.

The database query yields something like:

```
Row 1:
──────
query_duration_ms: 1001
query:             SELECT count(*) FROM numbers(1000000000) WHERE sipHash64(number) % 3000000 = 0

type:              ExceptionWhileProcessing
exception:         Code: 394. DB::Exception: Query was cancelled. (QUERY_WAS_CANCELLED) (version 26.1.2.11 (official build))
exception_code:    394
Settings:          {'readonly':'2','cancel_http_readonly_queries_on_client_close':'1'}
is_secure:         0

Row 2:
──────
query_duration_ms: 988
query:             SELECT count(*) FROM numbers(1000000000) WHERE sipHash64(number) % 2000000 = 0

type:              ExceptionWhileProcessing
exception:         Code: 394. DB::Exception: Query was cancelled. (QUERY_WAS_CANCELLED) (version 26.1.2.11 (official build))
exception_code:    394
Settings:          {'readonly':'2','cancel_http_readonly_queries_on_client_close':'1'}
is_secure:         1

Row 3:
──────
query_duration_ms: 8498
query:             SELECT count(*) FROM numbers(1000000000) WHERE sipHash64(number) % 1000000 = 0

type:              QueryFinish
exception:
exception_code:    0
Settings:          {'readonly':'2','cancel_http_readonly_queries_on_client_close':'1'}
is_secure:         1
```
