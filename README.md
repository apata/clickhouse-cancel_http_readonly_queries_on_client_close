# Clickhouse option cancel_http_readonly_queries_on_client_close

## Intro

This is a minimal repro for showing that the option `cancel_http_readonly_queries_on_client_close` does not work with https queries.

## Setup

- run `docker compose up --build -d`

## Steps to reproduce

- run `curl -k -m 1 'https://localhost:8443/?readonly=1&cancel_http_readonly_queries_on_client_close=1&query=SELECT+count(*)+FROM+numbers(1000000000)+WHERE+sipHash64(number)+%25+1000000+%3D+0'`
  - this should timeout; if not, increase the number within `numbers(...)`
- run `curl -m 1 'http://localhost:8123/?cancel_http_readonly_queries_on_client_close=1&query=SELECT+count(*)+FROM+numbers(1000000000)+WHERE+sipHash64(number)+%25+2000000+%3D+0'` 
  - this should timeout; if not, increase the number within `numbers(...)`
- run `docker compose exec clickhouse clickhouse-client "FROM system.query_log SELECT query_duration_ms, query, type, exception, exception_code, Settings, is_secure WHERE (query LIKE '%sipHash%') AND (query NOT LIKE '%like%') AND type > 1 ORDER BY event_time DESC LIMIT 2 FORMAT PrettyCompact"`

## Expected result

Both queries are canceled on the client dropping out.

## Actual result

Only the http query is canceled on the client dropping out.

The database query yields something like:
```
Row 1:
──────
query_duration_ms: 1006
query:             SELECT count(*) FROM numbers(1000000000) WHERE sipHash64(number) % 2000000 = 0

type:              ExceptionWhileProcessing
exception:         Code: 394. DB::Exception: Query was cancelled. (QUERY_WAS_CANCELLED) (version 26.1.2.11 (official build))
exception_code:    394
Settings:          {'readonly':'2','cancel_http_readonly_queries_on_client_close':'1'}
is_secure:         0

Row 2:
──────
query_duration_ms: 8659
query:             SELECT count(*) FROM numbers(1000000000) WHERE sipHash64(number) % 1000000 = 0

type:              QueryFinish
exception:         
exception_code:    0
Settings:          {'readonly':'2','cancel_http_readonly_queries_on_client_close':'1'}
is_secure:         1
```