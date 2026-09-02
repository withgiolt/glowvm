/// Conn – port of ElixirWorkers.Conn (base, no bindings/effects)
import gleam/dict.{type Dict}
import gleam/json
import gleam/option.{type Option, None, Some}
import glowvm/url

pub type Conn {
  Conn(
    method: String,
    url: String,
    path: String,
    query_string: String,
    query_params: Dict(String, String),
    path_segments: List(String),
    path_params: Dict(String, String),
    headers: Dict(String, String),
    body: String,
    parsed_body: String,
    status: Option(Int),
    resp_headers: Dict(String, String),
    resp_body: Option(String),
    halted: Bool,
  )
}

/// Build enriched Conn from raw request fields
pub fn new(
  method: String,
  url_str: String,
  headers: Dict(String, String),
  body: String,
) -> Conn {
  let parsed = url.parse_path(url_str)
  let path = parsed.path
  let qs = parsed.query_string
  Conn(
    method: method,
    url: url_str,
    path: path,
    query_string: qs,
    query_params: url.decode_query(qs),
    path_segments: url.split_path(path),
    path_params: dict.new(),
    headers: headers,
    body: body,
    parsed_body: "",
    status: None,
    resp_headers: dict.new(),
    resp_body: None,
    halted: False,
  )
}

// ---------------------------------------------------------------------------
// Response builders
// ---------------------------------------------------------------------------

pub fn html(conn: Conn, status: Int, body: String) -> Conn {
  conn
  |> put_resp_header("content-type", "text/html; charset=utf-8")
  |> send_resp(status, body)
}

pub fn json_response(conn: Conn, status: Int, data: json.Json) -> Conn {
  conn
  |> put_resp_header("content-type", "application/json")
  |> send_resp(status, json.to_string(data))
}

pub fn text(conn: Conn, status: Int, body: String) -> Conn {
  conn
  |> put_resp_header("content-type", "text/plain; charset=utf-8")
  |> send_resp(status, body)
}

pub fn redirect(conn: Conn, url: String, status: Int) -> Conn {
  conn
  |> put_resp_header("location", url)
  |> send_resp(status, "")
}

pub fn put_resp_header(conn: Conn, key: String, value: String) -> Conn {
  Conn(..conn, resp_headers: dict.insert(conn.resp_headers, key, value))
}

pub fn send_resp(conn: Conn, status: Int, body: String) -> Conn {
  Conn(..conn, status: Some(status), resp_body: Some(body))
}

pub fn halt(conn: Conn) -> Conn {
  Conn(..conn, halted: True)
}

// ---------------------------------------------------------------------------
// Final output
// ---------------------------------------------------------------------------

/// Build the response JSON string to write to stdout
/// Mirrors Elixir Conn.to_response but simplified (no _needs/_effects)
pub fn to_response_json(conn: Conn) -> String {
  let status = case conn.status {
    Some(s) -> s
    None -> 200
  }
  let body = case conn.resp_body {
    Some(b) -> b
    None -> ""
  }
  json.object([
    #("status", json.int(status)),
    #("headers", json.dict(conn.resp_headers, fn(k) { k }, json.string)),
    #("body", json.string(body)),
  ])
  |> json.to_string
}
