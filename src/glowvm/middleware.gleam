/// Middleware – port of ElixirWorkers.Middleware (base only)
import gleam/dict
import glowvm/body
import glowvm/conn.{type Conn, Conn}

pub fn security_headers(conn: Conn) -> Conn {
  conn
  |> conn.put_resp_header("x-content-type-options", "nosniff")
  |> conn.put_resp_header("x-frame-options", "DENY")
  |> conn.put_resp_header(
    "strict-transport-security",
    "max-age=31536000; includeSubDomains",
  )
  |> conn.put_resp_header(
    "referrer-policy",
    "strict-origin-when-cross-origin",
  )
  |> conn.put_resp_header(
    "permissions-policy",
    "geolocation=(), microphone=(), camera=()",
  )
  |> conn.put_resp_header(
    "content-security-policy",
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'",
  )
}

/// Parse request body based on content-type, sets parsed_body on conn
pub fn parse_body(conn: Conn) -> Conn {
  let ct = case dict.get(conn.headers, "content-type") {
    Ok(v) -> v
    Error(Nil) ->
      case dict.get(conn.headers, "Content-Type") {
        Ok(v) -> v
        Error(Nil) -> ""
      }
  }
  let parsed = body.parse(conn.body, ct)
  // Even without full typed parsed_body, we store string
  Conn(..conn, parsed_body: parsed)
}

/// CORS – not used by default in base, but provided for completeness
pub fn cors(
  conn: Conn,
  origin: String,
  methods: String,
  headers: String,
  max_age: String,
) -> Conn {
  let conn =
    conn
    |> conn.put_resp_header("access-control-allow-origin", origin)
    |> conn.put_resp_header("access-control-allow-methods", methods)
    |> conn.put_resp_header("access-control-allow-headers", headers)
  case conn.method == "OPTIONS" {
    True ->
      conn
      |> conn.put_resp_header("access-control-max-age", max_age)
      |> conn.send_resp(204, "")
      |> conn.halt
    False -> conn
  }
}

pub fn cors_default(conn: Conn) -> Conn {
  cors(conn, "*", "GET,POST,PUT,DELETE,OPTIONS", "content-type,authorization", "86400")
}

/// Run list of middleware, stopping if halted
pub fn run(conn: Conn, mids: List(fn(Conn) -> Conn)) -> Conn {
  case mids {
    [] -> conn
    [mid, ..rest] ->
      case conn.halted {
        True -> conn
        False -> run(mid(conn), rest)
      }
  }
}

/// Default middleware stack – mirrors Elixir Router.middleware/0
pub fn default_stack() -> List(fn(Conn) -> Conn) {
  [security_headers, parse_body]
}
