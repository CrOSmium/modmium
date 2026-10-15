use std::collections::{BTreeMap, HashMap};
use std::fmt;
use std::fs;
use std::io::{self, Read, Write};
use std::net::{Ipv4Addr, SocketAddrV4, TcpListener, TcpStream};
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::process::{Command, Stdio};
use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};
use std::thread;
use std::time::Duration;

const ADDRESS: SocketAddrV4 = SocketAddrV4::new(Ipv4Addr::LOCALHOST, 27182);
const MAX_HANDSHAKE: usize = 8 * 1024;
const MAX_MESSAGE: usize = 512 * 1024;
const MAX_PROVIDER_OUTPUT: usize = 2 * 1024 * 1024;
const MAX_ACTIONS: usize = 128;
const MAX_ARGUMENTS: usize = 16;
const MAX_ARGUMENT_SIZE: usize = 512 * 1024;
const MAX_CONNECTIONS: usize = 8;
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(3);
const WRITE_TIMEOUT: Duration = Duration::from_secs(3);
const EXPECTED_HOST: &str = "127.0.0.1:27182";
const WEBUI_ORIGIN: &str = "chrome://borealis-motd";
const BRIDGE_ORIGIN: &str = "http://127.0.0.1:27182";
const PROTOCOL: &str = "modmium.v1";
const WEBSOCKET_GUID: &[u8] = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
const TRUSTED_SCRIPTS: &str = include_str!("../trusted-scripts");

const BRIDGE_HTML: &str = r#"<!doctype html><meta charset=utf-8><script>
const webuiOrigin = 'chrome://borealis-motd';
let socket;
function connect() {
  socket = new WebSocket('ws://127.0.0.1:27182/v1', 'modmium.v1');
  socket.onopen = () => parent.postMessage({type: 'ready'}, webuiOrigin);
  socket.onmessage = event => parent.postMessage({type: 'response', body: event.data}, webuiOrigin);
  socket.onclose = () => setTimeout(connect, 500);
}
addEventListener('message', event => {
  if (event.origin === webuiOrigin && event.source === parent &&
      event.data?.type === 'request' && typeof event.data.body === 'string' &&
      socket.readyState === WebSocket.OPEN) {
    socket.send(event.data.body);
  }
});
connect();
</script>"#;

const HEALTH_JSON: &str = concat!(
    "{\"apiVersion\":1,\"serviceVersion\":\"",
    env!("CARGO_PKG_VERSION"),
    "\",\"status\":\"ok\"}"
);

pub fn run() -> io::Result<()> {
    let registry = Arc::new(load_registry()?);
    let listener = TcpListener::bind(ADDRESS)?;
    let active = Arc::new(AtomicUsize::new(0));
    eprintln!("modmium-web: listening on ws://{ADDRESS}/v1");

    for connection in listener.incoming() {
        let stream = match connection {
            Ok(stream) => stream,
            Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
            Err(error) => return Err(error),
        };
        if active.fetch_add(1, Ordering::Relaxed) >= MAX_CONNECTIONS {
            active.fetch_sub(1, Ordering::Relaxed);
            continue;
        }

        let connection = ActiveConnection(Arc::clone(&active));
        let registry = Arc::clone(&registry);
        thread::Builder::new()
            .name("modmium-ws".into())
            .stack_size(64 * 1024)
            .spawn(move || {
                let _connection = connection;
                match serve(stream, &registry) {
                    Err(Error::Io(error))
                        if !matches!(
                            error.kind(),
                            io::ErrorKind::BrokenPipe
                                | io::ErrorKind::ConnectionReset
                                | io::ErrorKind::UnexpectedEof
                                | io::ErrorKind::TimedOut
                                | io::ErrorKind::WouldBlock
                        ) =>
                    {
                        eprintln!("modmium-web: connection failed: {error}")
                    }
                    _ => {}
                }
            })?;
    }
    Ok(())
}

struct ActiveConnection(Arc<AtomicUsize>);

impl Drop for ActiveConnection {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::Relaxed);
    }
}

fn serve(mut stream: TcpStream, registry: &Registry) -> Result<(), Error> {
    stream.set_read_timeout(Some(HANDSHAKE_TIMEOUT))?;
    stream.set_write_timeout(Some(WRITE_TIMEOUT))?;
    stream.set_nodelay(true)?;

    let key = match read_request(&mut stream)? {
        Request::Bridge => {
            write_bridge(&mut stream)?;
            return Ok(());
        }
        Request::WebSocket(key) => key,
    };
    write_handshake(&mut stream, &key)?;
    stream.set_read_timeout(None)?;

    let mut payload = Vec::with_capacity(256);
    loop {
        match read_frame(&mut stream, &mut payload)? {
            Frame::Text => {
                let response = match std::str::from_utf8(&payload) {
                    Ok("health") => HEALTH_JSON.to_owned(),
                    Ok("state") => collect_state().unwrap_or_else(error_json),
                    Ok("menus") => describe_mosh(registry).unwrap_or_else(error_json),
                    Ok(request) if request.starts_with("run\t") => {
                        run_mosh_action(registry, request).unwrap_or_else(error_json)
                    }
                    _ => "{\"error\":\"unknown request\"}".to_owned(),
                };
                write_frame(&mut stream, 0x1, response.as_bytes())?;
            }
            Frame::Ping => write_frame(&mut stream, 0xa, &payload)?,
            Frame::Pong => {}
            Frame::Close => {
                write_frame(&mut stream, 0x8, &payload)?;
                return Ok(());
            }
        }
    }
}

#[derive(Clone)]
struct Action {
    script: &'static str,
    min_arguments: usize,
    max_arguments: usize,
}

struct MenuOwner {
    id: String,
    script: &'static str,
}

struct Registry {
    actions: HashMap<String, Action>,
    menus: Vec<MenuOwner>,
}

enum StateValue {
    String(String),
    Bool(bool),
    Strings(Vec<String>),
}

struct ScriptOutput {
    stdout: Vec<u8>,
    status: std::process::ExitStatus,
}

fn trusted_scripts() -> impl Iterator<Item = &'static str> {
    TRUSTED_SCRIPTS.lines().filter(|path| !path.is_empty())
}

fn load_registry() -> io::Result<Registry> {
    let mut actions = HashMap::new();
    let mut menus = Vec::new();

    for script in trusted_scripts() {
        let output = run_script(script, "describe", None, &[])?;
        if !output.status.success() {
            return Err(io::Error::other(format!(
                "{script} description failed with {}",
                output.status
            )));
        }
        parse_description(script, &output.stdout, &mut actions, &mut menus)?;
    }

    Ok(Registry { actions, menus })
}

fn parse_description(
    script: &'static str,
    output: &[u8],
    actions: &mut HashMap<String, Action>,
    menus: &mut Vec<MenuOwner>,
) -> io::Result<()> {
    for line in String::from_utf8_lossy(output).lines() {
        let Some(record) = mosh_record(line) else {
            continue;
        };
        let fields: Vec<_> = record.split('\t').collect();
        match fields.as_slice() {
            ["action", id, min, max] if valid_name(id) => {
                let min_arguments = parse_count(min)?;
                let max_arguments = parse_count(max)?;
                if min_arguments > max_arguments {
                    return Err(io::Error::other(format!("invalid argument range for {id}")));
                }
                let action = Action {
                    script,
                    min_arguments,
                    max_arguments,
                };
                if actions.insert((*id).to_owned(), action).is_some() {
                    return Err(io::Error::other(format!("duplicate MOSH action {id}")));
                }
                if actions.len() > MAX_ACTIONS {
                    return Err(io::Error::other("too many MOSH actions"));
                }
            }
            ["menu-owner", id] if valid_name(id) => {
                if menus.iter().any(|owner| owner.id == *id) {
                    return Err(io::Error::other(format!("duplicate MOSH menu {id}")));
                }
                menus.push(MenuOwner {
                    id: (*id).to_owned(),
                    script,
                });
            }
            _ => {
                return Err(io::Error::other(format!(
                    "invalid MOSH description from {script}"
                )));
            }
        }
    }
    Ok(())
}

fn parse_count(value: &str) -> io::Result<usize> {
    value
        .parse::<usize>()
        .ok()
        .filter(|count| *count <= MAX_ARGUMENTS)
        .ok_or_else(|| io::Error::other("invalid MOSH argument count"))
}

fn run_script(
    script: &'static str,
    mode: &str,
    action: Option<&str>,
    arguments: &[String],
) -> io::Result<ScriptOutput> {
    let mut command = script_command(script, mode, action, arguments)?;
    command.stdout(Stdio::piped());
    let mut child = command.spawn()?;
    let mut stdout = Vec::new();
    child
        .stdout
        .take()
        .ok_or_else(|| io::Error::other("MOSH output unavailable"))?
        .take((MAX_PROVIDER_OUTPUT + 1) as u64)
        .read_to_end(&mut stdout)?;
    if stdout.len() > MAX_PROVIDER_OUTPUT {
        let _ = child.kill();
        let _ = child.wait();
        return Err(io::Error::other("MOSH output is too large"));
    }
    let status = child.wait()?;
    Ok(ScriptOutput { stdout, status })
}

fn script_command(
    script: &'static str,
    mode: &str,
    action: Option<&str>,
    arguments: &[String],
) -> io::Result<Command> {
    ensure_trusted_script(script)?;
    let mut command = Command::new(script);
    command
        .env_clear()
        .env("MOSH_FRONTEND", "gui")
        .env("MOSH_GUI_MODE", mode)
        .env("MOSH_GUI_ACTION", action.unwrap_or_default())
        .env("MOSH_GUI_ALLOWED", action.unwrap_or_default())
        .env("MOSH_GUI_ARG_COUNT", arguments.len().to_string())
        .env("HOME", "/root")
        .env("LC_ALL", "C")
        .env("TERM", "dumb")
        .env("PATH", "/bin:/usr/bin:/sbin:/usr/sbin:/opt/bin")
        .stdin(Stdio::null())
        .stderr(Stdio::null());
    for (index, argument) in arguments.iter().enumerate() {
        command.env(format!("MOSH_GUI_ARG_{index}"), argument);
    }

    Ok(command)
}

fn ensure_trusted_script(path: &str) -> io::Result<()> {
    if !trusted_scripts().any(|script| script == path) {
        return Err(io::Error::other("untrusted MOSH script"));
    }
    ensure_safe_file(path)?;
    ensure_safe_file("/usr/lib/libmosh.sh")?;
    ensure_safe_file("/usr/share/misc/shflags")
}

fn ensure_safe_file(path: &str) -> io::Result<()> {
    let metadata = fs::symlink_metadata(path)?;
    if !metadata.file_type().is_file()
        || metadata.uid() != 0
        || metadata.permissions().mode() & 0o022 != 0
    {
        return Err(io::Error::other(format!("unsafe MOSH file {path}")));
    }
    Ok(())
}

fn collect_state() -> io::Result<String> {
    let mut fields = BTreeMap::new();
    for script in trusted_scripts() {
        let output = match run_script(script, "state", None, &[]) {
            Ok(output) => output,
            Err(error) => {
                eprintln!("modmium-web: {script} state unavailable: {error}");
                continue;
            }
        };
        if !output.status.success() {
            eprintln!("modmium-web: {script} state failed with {}", output.status);
            continue;
        }
        let mut provider_fields = BTreeMap::new();
        if let Err(error) = parse_state_records(script, &output.stdout, &mut provider_fields) {
            eprintln!("modmium-web: {script} returned invalid state: {error}");
            continue;
        }
        if let Err(error) = merge_state(&mut fields, provider_fields) {
            eprintln!("modmium-web: {script} state ignored: {error}");
        }
    }
    if fields.is_empty() {
        return Err(io::Error::other("Modmium state is unavailable"));
    }

    let mut json = String::from("{\"type\":\"state\"");
    for (name, value) in fields {
        json.push(',');
        push_json_string(&mut json, &name);
        json.push(':');
        match value {
            StateValue::String(value) => push_json_string(&mut json, &value),
            StateValue::Bool(value) => json.push_str(if value { "true" } else { "false" }),
            StateValue::Strings(values) => {
                json.push('[');
                for (index, value) in values.iter().enumerate() {
                    if index != 0 {
                        json.push(',');
                    }
                    push_json_string(&mut json, value);
                }
                json.push(']');
            }
        }
    }
    json.push('}');
    Ok(json)
}

fn merge_state(
    fields: &mut BTreeMap<String, StateValue>,
    provider_fields: BTreeMap<String, StateValue>,
) -> io::Result<()> {
    if let Some(name) = provider_fields
        .keys()
        .find(|name| fields.contains_key(*name))
    {
        return Err(io::Error::other(format!("duplicate MOSH state {name}")));
    }
    fields.extend(provider_fields);
    Ok(())
}

fn parse_state_records(
    script: &str,
    output: &[u8],
    fields: &mut BTreeMap<String, StateValue>,
) -> io::Result<()> {
    for line in String::from_utf8_lossy(output).lines() {
        let Some(record) = mosh_record(line) else {
            continue;
        };
        let parts: Vec<_> = record.split('\t').collect();
        match parts.as_slice() {
            ["state-list", name] if valid_name(name) => {
                if fields
                    .insert((*name).to_owned(), StateValue::Strings(Vec::new()))
                    .is_some()
                {
                    return Err(io::Error::other(format!("duplicate MOSH state {name}")));
                }
            }
            ["state", name, kind, value] if valid_name(name) => {
                if fields.contains_key(*name) {
                    return Err(io::Error::other(format!("duplicate MOSH state {name}")));
                }
                let value = decode_field(value)?;
                let value = match *kind {
                    "string" => StateValue::String(value),
                    "bool" => StateValue::Bool(match value.as_str() {
                        "1" | "true" => true,
                        "0" | "false" => false,
                        _ => return Err(io::Error::other("invalid MOSH boolean")),
                    }),
                    _ => return Err(io::Error::other("invalid MOSH state type")),
                };
                fields.insert((*name).to_owned(), value);
            }
            ["state-item", name, value] if valid_name(name) => {
                let value = decode_field(value)?;
                match fields.entry((*name).to_owned()) {
                    std::collections::btree_map::Entry::Vacant(entry) => {
                        entry.insert(StateValue::Strings(vec![value]));
                    }
                    std::collections::btree_map::Entry::Occupied(mut entry) => {
                        let StateValue::Strings(values) = entry.get_mut() else {
                            return Err(io::Error::other(format!(
                                "mixed MOSH state types for {name}"
                            )));
                        };
                        if !values.contains(&value) {
                            values.push(value);
                        }
                    }
                }
            }
            _ => {
                return Err(io::Error::other(format!(
                    "invalid MOSH state from {script}"
                )));
            }
        }
    }
    Ok(())
}

fn run_mosh_action(registry: &Registry, request: &str) -> io::Result<String> {
    let fields: Result<Vec<_>, _> = request.split('\t').skip(1).map(decode_field).collect();
    let fields = fields?;
    let action_id = fields
        .first()
        .ok_or_else(|| io::Error::other("missing action"))?;
    let arguments = &fields[1..];
    let action = registry
        .actions
        .get(action_id)
        .ok_or_else(|| io::Error::other("action unavailable"))?;
    if !(action.min_arguments..=action.max_arguments).contains(&arguments.len()) {
        return Err(io::Error::other("wrong number of action arguments"));
    }
    if arguments.len() > MAX_ARGUMENTS
        || arguments
            .iter()
            .any(|argument| argument.len() > MAX_ARGUMENT_SIZE || argument.contains(['\0', '\r']))
    {
        return Err(io::Error::other("invalid action arguments"));
    }

    let marker = format!("MOSH1\tstarted\t{action_id}").into_bytes();
    let mut command = script_command(action.script, "run", Some(action_id), arguments)?;
    command.stdout(Stdio::piped());
    let mut child = command.spawn()?;
    let started = stream_contains(
        child
            .stdout
            .take()
            .ok_or_else(|| io::Error::other("action output unavailable"))?,
        &marker,
    )?;
    let status = child.wait()?;
    if !status.success() {
        return Err(io::Error::other(format!("action failed with {}", status)));
    }
    if !started {
        return Err(io::Error::other("MOSH rejected the action"));
    }
    action_json(action_id)
}

fn stream_contains(mut output: impl Read, marker: &[u8]) -> io::Result<bool> {
    let mut found = false;
    let mut tail = Vec::with_capacity(marker.len());
    let mut buffer = [0; 4096];
    loop {
        let count = output.read(&mut buffer)?;
        if count == 0 {
            return Ok(found);
        }
        tail.extend_from_slice(&buffer[..count]);
        found |= tail.windows(marker.len()).any(|window| window == marker);
        if tail.len() > marker.len() {
            tail.drain(..tail.len() - marker.len());
        }
    }
}

fn action_json(action_id: &str) -> io::Result<String> {
    let mut json = String::from("{\"type\":\"action\",\"action\":");
    push_json_string(&mut json, action_id);
    json.push_str(",\"ok\":true}");
    Ok(json)
}

fn decode_field(field: &str) -> io::Result<String> {
    let mut decoded = Vec::with_capacity(field.len());
    let bytes = field.as_bytes();
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' {
            if index + 2 >= bytes.len() {
                return Err(io::Error::other("bad request encoding"));
            }
            let high =
                hex(bytes[index + 1]).ok_or_else(|| io::Error::other("bad request encoding"))?;
            let low =
                hex(bytes[index + 2]).ok_or_else(|| io::Error::other("bad request encoding"))?;
            decoded.push(high << 4 | low);
            index += 3;
        } else {
            decoded.push(bytes[index]);
            index += 1;
        }
    }
    String::from_utf8(decoded).map_err(|_| io::Error::other("request is not UTF-8"))
}

fn hex(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
}

struct MoshItem {
    id: String,
    label: String,
    control: String,
    view: String,
    enabled: bool,
}

struct MoshMenu {
    id: String,
    title: String,
    items: Vec<MoshItem>,
}

fn describe_mosh(registry: &Registry) -> io::Result<String> {
    let mut menus = Vec::with_capacity(registry.menus.len());
    for owner in &registry.menus {
        let output = run_script(owner.script, "menu", None, &[])?;
        if !output.status.success() {
            return Err(io::Error::other(format!(
                "{} exited with {}",
                owner.script, output.status
            )));
        }
        menus.push(parse_mosh_menu(&owner.id, &output.stdout)?);
    }

    let mut json = String::from("{\"type\":\"menus\",\"menus\":[");
    for (menu_index, menu) in menus.iter().enumerate() {
        if menu_index != 0 {
            json.push(',');
        }
        json.push_str("{\"id\":");
        push_json_string(&mut json, &menu.id);
        json.push_str(",\"title\":");
        push_json_string(&mut json, &menu.title);
        json.push_str(",\"items\":[");
        for (item_index, item) in menu.items.iter().enumerate() {
            if item_index != 0 {
                json.push(',');
            }
            json.push_str("{\"id\":");
            push_json_string(&mut json, &item.id);
            json.push_str(",\"label\":");
            push_json_string(&mut json, &item.label);
            json.push_str(",\"control\":");
            push_json_string(&mut json, &item.control);
            json.push_str(",\"view\":");
            push_json_string(&mut json, &item.view);
            json.push_str(if item.enabled {
                ",\"enabled\":true}"
            } else {
                ",\"enabled\":false}"
            });
        }
        json.push_str("]}");
    }
    json.push_str("]}");
    Ok(json)
}

fn parse_mosh_menu(id: &str, output: &[u8]) -> io::Result<MoshMenu> {
    let text = String::from_utf8_lossy(output);
    let mut title = None;
    let mut items = Vec::new();
    for line in text.lines() {
        let Some(record) = mosh_record(line) else {
            continue;
        };
        let fields: Vec<_> = record.split('\t').collect();
        match fields.as_slice() {
            ["menu", name] => title = Some((*name).to_owned()),
            ["item", item_id, label, control, view, enabled]
                if valid_name(item_id) && matches!(*enabled, "0" | "1") =>
            {
                items.push(MoshItem {
                    id: (*item_id).to_owned(),
                    label: (*label).to_owned(),
                    control: (*control).to_owned(),
                    view: (*view).to_owned(),
                    enabled: *enabled == "1",
                });
            }
            _ => return Err(io::Error::other(format!("invalid MOSH record from {id}"))),
        }
    }
    let title = title.ok_or_else(|| io::Error::other(format!("missing MOSH menu {id}")))?;
    Ok(MoshMenu {
        id: id.to_owned(),
        title,
        items,
    })
}

fn valid_name(name: &str) -> bool {
    !name.is_empty()
        && name
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
}

fn mosh_record(line: &str) -> Option<&str> {
    line.find("MOSH1\t")
        .map(|offset| &line[offset + "MOSH1\t".len()..])
}

fn push_json_string(json: &mut String, text: &str) {
    json.push('"');
    for character in text.chars() {
        match character {
            '"' => json.push_str("\\\""),
            '\\' => json.push_str("\\\\"),
            '\n' => json.push_str("\\n"),
            '\r' => json.push_str("\\r"),
            '\t' => json.push_str("\\t"),
            character if character.is_control() => {
                use std::fmt::Write as _;
                let _ = write!(json, "\\u{:04x}", character as u32);
            }
            character => json.push(character),
        }
    }
    json.push('"');
}

fn error_json(error: io::Error) -> String {
    let mut json = String::from("{\"error\":");
    push_json_string(&mut json, &error.to_string());
    json.push('}');
    json
}

enum Request {
    Bridge,
    WebSocket(String),
}

fn read_request(stream: &mut TcpStream) -> Result<Request, Error> {
    let mut bytes = [0_u8; MAX_HANDSHAKE];
    let mut length = 0;
    loop {
        let count = stream.read(&mut bytes[length..])?;
        if count == 0 {
            return Err(Error::BadHandshake);
        }
        length += count;
        if bytes[..length].ends_with(b"\r\n\r\n") {
            break;
        }
        if length == bytes.len() {
            return Err(Error::HandshakeTooLarge);
        }
    }

    let head = std::str::from_utf8(&bytes[..length]).map_err(|_| Error::BadHandshake)?;
    let mut lines = head.split("\r\n");
    let request_line = lines.next().ok_or(Error::BadHandshake)?;
    if request_line != "GET /v1 HTTP/1.1" && request_line != "GET /bridge HTTP/1.1" {
        return Err(Error::BadHandshake);
    }

    let mut host = None;
    let mut origin = None;
    let mut upgrade = false;
    let mut connection = false;
    let mut version = None;
    let mut key = None;
    let mut protocol = false;
    let mut destination = None;

    for line in lines.take_while(|line| !line.is_empty()) {
        let (name, value) = line.split_once(':').ok_or(Error::BadHandshake)?;
        let value = value.trim();
        if name.eq_ignore_ascii_case("host") {
            set_once(&mut host, value)?;
        } else if name.eq_ignore_ascii_case("origin") {
            set_once(&mut origin, value)?;
        } else if name.eq_ignore_ascii_case("upgrade") {
            upgrade = value.eq_ignore_ascii_case("websocket");
        } else if name.eq_ignore_ascii_case("connection") {
            connection = has_token(value, "upgrade");
        } else if name.eq_ignore_ascii_case("sec-websocket-version") {
            set_once(&mut version, value)?;
        } else if name.eq_ignore_ascii_case("sec-websocket-key") {
            set_once(&mut key, value)?;
        } else if name.eq_ignore_ascii_case("sec-websocket-protocol") {
            protocol = value.split(',').any(|token| token.trim() == PROTOCOL);
        } else if name.eq_ignore_ascii_case("sec-fetch-dest") {
            set_once(&mut destination, value)?;
        }
    }

    if host != Some(EXPECTED_HOST) {
        return Err(Error::Forbidden);
    }
    if request_line == "GET /bridge HTTP/1.1" {
        return if destination == Some("iframe") {
            Ok(Request::Bridge)
        } else {
            Err(Error::Forbidden)
        };
    }
    if origin != Some(BRIDGE_ORIGIN) {
        return Err(Error::Forbidden);
    }
    if !upgrade || !connection || version != Some("13") || !protocol {
        return Err(Error::BadHandshake);
    }

    let key = key.ok_or(Error::BadHandshake)?;
    if !valid_websocket_key(key) {
        return Err(Error::BadHandshake);
    }
    Ok(Request::WebSocket(key.to_owned()))
}

fn set_once<'a>(slot: &mut Option<&'a str>, value: &'a str) -> Result<(), Error> {
    if slot.replace(value).is_some() {
        return Err(Error::BadHandshake);
    }
    Ok(())
}

fn has_token(value: &str, expected: &str) -> bool {
    value
        .split(',')
        .any(|token| token.trim().eq_ignore_ascii_case(expected))
}

fn valid_websocket_key(key: &str) -> bool {
    if key.len() != 24
        || !key.ends_with("==")
        || !matches!(key.as_bytes()[21], b'A' | b'Q' | b'g' | b'w')
    {
        return false;
    }
    key[..22]
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || byte == b'+' || byte == b'/')
}

fn write_handshake(stream: &mut TcpStream, key: &str) -> io::Result<()> {
    let mut input = Vec::with_capacity(key.len() + WEBSOCKET_GUID.len());
    input.extend_from_slice(key.as_bytes());
    input.extend_from_slice(WEBSOCKET_GUID);
    let accept = base64(&sha1(&input));

    write!(
        stream,
        "HTTP/1.1 101 Switching Protocols\r\n\
         Upgrade: websocket\r\n\
         Connection: Upgrade\r\n\
         Sec-WebSocket-Accept: {accept}\r\n\
         Sec-WebSocket-Protocol: {PROTOCOL}\r\n\r\n"
    )?;
    stream.flush()
}

fn write_bridge(stream: &mut TcpStream) -> io::Result<()> {
    write!(
        stream,
        "HTTP/1.1 200 OK\r\n\
         Content-Type: text/html; charset=utf-8\r\n\
         Content-Length: {}\r\n\
         Cache-Control: no-store\r\n\
         Content-Security-Policy: default-src 'none'; script-src 'unsafe-inline'; connect-src ws://127.0.0.1:27182; frame-ancestors {WEBUI_ORIGIN}\r\n\
         Connection: close\r\n\r\n\
         {BRIDGE_HTML}",
        BRIDGE_HTML.len()
    )?;
    stream.flush()
}

enum Frame {
    Text,
    Ping,
    Pong,
    Close,
}

fn read_frame(stream: &mut TcpStream, payload: &mut Vec<u8>) -> Result<Frame, Error> {
    let mut head = [0_u8; 2];
    stream.read_exact(&mut head)?;

    if head[0] & 0x80 == 0 || head[0] & 0x70 != 0 || head[1] & 0x80 == 0 {
        return Err(Error::Protocol);
    }
    let opcode = head[0] & 0x0f;
    let mut length = u64::from(head[1] & 0x7f);
    if length == 126 {
        let mut extended = [0_u8; 2];
        stream.read_exact(&mut extended)?;
        length = u64::from(u16::from_be_bytes(extended));
        if length < 126 {
            return Err(Error::Protocol);
        }
    } else if length == 127 {
        let mut extended = [0_u8; 8];
        stream.read_exact(&mut extended)?;
        length = u64::from_be_bytes(extended);
    }

    let control = opcode & 0x08 != 0;
    if length > MAX_MESSAGE as u64 || (control && length > 125) {
        return Err(Error::MessageTooLarge);
    }

    let mut mask = [0_u8; 4];
    stream.read_exact(&mut mask)?;
    payload.resize(length as usize, 0);
    stream.read_exact(payload)?;
    for (index, byte) in payload.iter_mut().enumerate() {
        *byte ^= mask[index % 4];
    }

    match opcode {
        0x1 if std::str::from_utf8(payload).is_ok() => Ok(Frame::Text),
        0x8 if payload.is_empty()
            || (payload.len() >= 2 && std::str::from_utf8(&payload[2..]).is_ok()) =>
        {
            Ok(Frame::Close)
        }
        0x9 => Ok(Frame::Ping),
        0xa => Ok(Frame::Pong),
        _ => Err(Error::Protocol),
    }
}

fn write_frame(stream: &mut TcpStream, opcode: u8, payload: &[u8]) -> io::Result<()> {
    stream.write_all(&[0x80 | opcode])?;
    match payload.len() {
        0..=125 => stream.write_all(&[payload.len() as u8])?,
        126..=65535 => {
            stream.write_all(&[126])?;
            stream.write_all(&(payload.len() as u16).to_be_bytes())?;
        }
        _ => {
            stream.write_all(&[127])?;
            stream.write_all(&(payload.len() as u64).to_be_bytes())?;
        }
    }
    stream.write_all(payload)?;
    stream.flush()
}

fn sha1(message: &[u8]) -> [u8; 20] {
    let bit_length = (message.len() as u64) * 8;
    let mut padded = Vec::with_capacity((message.len() + 72) & !63);
    padded.extend_from_slice(message);
    padded.push(0x80);
    while padded.len() % 64 != 56 {
        padded.push(0);
    }
    padded.extend_from_slice(&bit_length.to_be_bytes());

    let mut state = [
        0x6745_2301_u32,
        0xefcd_ab89,
        0x98ba_dcfe,
        0x1032_5476,
        0xc3d2_e1f0,
    ];
    for block in padded.chunks(64) {
        let mut words = [0_u32; 80];
        for (word, bytes) in words[..16].iter_mut().zip(block.chunks(4)) {
            *word = u32::from_be_bytes(bytes.try_into().unwrap());
        }
        for i in 16..80 {
            words[i] = (words[i - 3] ^ words[i - 8] ^ words[i - 14] ^ words[i - 16]).rotate_left(1);
        }

        let [mut a, mut b, mut c, mut d, mut e] = state;
        for (i, word) in words.into_iter().enumerate() {
            let (f, k) = match i {
                0..=19 => ((b & c) | ((!b) & d), 0x5a82_7999),
                20..=39 => (b ^ c ^ d, 0x6ed9_eba1),
                40..=59 => ((b & c) | (b & d) | (c & d), 0x8f1b_bcdc),
                _ => (b ^ c ^ d, 0xca62_c1d6),
            };
            let next = a
                .rotate_left(5)
                .wrapping_add(f)
                .wrapping_add(e)
                .wrapping_add(k)
                .wrapping_add(word);
            e = d;
            d = c;
            c = b.rotate_left(30);
            b = a;
            a = next;
        }
        state[0] = state[0].wrapping_add(a);
        state[1] = state[1].wrapping_add(b);
        state[2] = state[2].wrapping_add(c);
        state[3] = state[3].wrapping_add(d);
        state[4] = state[4].wrapping_add(e);
    }

    let mut digest = [0_u8; 20];
    for (bytes, word) in digest.chunks_mut(4).zip(state) {
        bytes.copy_from_slice(&word.to_be_bytes());
    }
    digest
}

fn base64(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut encoded = String::with_capacity(bytes.len().div_ceil(3) * 4);
    for chunk in bytes.chunks(3) {
        let bits = u32::from(chunk[0]) << 16
            | u32::from(*chunk.get(1).unwrap_or(&0)) << 8
            | u32::from(*chunk.get(2).unwrap_or(&0));
        encoded.push(DIGITS[((bits >> 18) & 63) as usize] as char);
        encoded.push(DIGITS[((bits >> 12) & 63) as usize] as char);
        encoded.push(if chunk.len() > 1 {
            DIGITS[((bits >> 6) & 63) as usize] as char
        } else {
            '='
        });
        encoded.push(if chunk.len() > 2 {
            DIGITS[(bits & 63) as usize] as char
        } else {
            '='
        });
    }
    encoded
}

#[derive(Debug)]
enum Error {
    Io(io::Error),
    BadHandshake,
    Forbidden,
    HandshakeTooLarge,
    MessageTooLarge,
    Protocol,
}

impl From<io::Error> for Error {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

impl fmt::Display for Error {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(error) => error.fmt(formatter),
            Self::BadHandshake => formatter.write_str("bad HTTP request"),
            Self::Forbidden => formatter.write_str("forbidden client"),
            Self::HandshakeTooLarge => formatter.write_str("HTTP request is too large"),
            Self::MessageTooLarge => formatter.write_str("WebSocket message is too large"),
            Self::Protocol => formatter.write_str("WebSocket protocol error"),
        }
    }
}

impl std::error::Error for Error {}

#[cfg(test)]
mod tests {
    use super::*;

    fn handshake(origin: &str) -> String {
        format!(
            "GET /v1 HTTP/1.1\r\n\
             Host: 127.0.0.1:27182\r\n\
             Upgrade: websocket\r\n\
             Connection: keep-alive, Upgrade\r\n\
             Origin: {origin}\r\n\
             Sec-WebSocket-Version: 13\r\n\
             Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\
             Sec-WebSocket-Protocol: modmium.v1\r\n\r\n"
        )
    }

    #[test]
    fn computes_the_rfc_websocket_accept_value() {
        let mut input = b"dGhlIHNhbXBsZSBub25jZQ==".to_vec();
        input.extend_from_slice(WEBSOCKET_GUID);
        assert_eq!(base64(&sha1(&input)), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=");
    }

    #[test]
    fn accepts_the_bridge_handshake() {
        let (mut client, mut server) = tcp_pair();
        client
            .write_all(handshake(BRIDGE_ORIGIN).as_bytes())
            .unwrap();
        let Request::WebSocket(key) = read_request(&mut server).unwrap() else {
            panic!("expected a WebSocket request");
        };
        assert_eq!(key, "dGhlIHNhbXBsZSBub25jZQ==");
    }

    #[test]
    fn rejects_a_foreign_origin() {
        let (mut client, mut server) = tcp_pair();
        client
            .write_all(handshake("https://example.com").as_bytes())
            .unwrap();
        assert!(matches!(read_request(&mut server), Err(Error::Forbidden)));
    }

    #[test]
    fn unmasks_a_client_text_frame() {
        let (mut client, mut server) = tcp_pair();
        client
            .write_all(&[0x81, 0x86, 1, 2, 3, 4, 105, 103, 98, 104, 117, 106])
            .unwrap();
        let mut payload = Vec::new();
        assert!(matches!(
            read_frame(&mut server, &mut payload).unwrap(),
            Frame::Text
        ));
        assert_eq!(payload, b"health");
    }

    #[test]
    fn rejects_an_unmasked_client_frame() {
        let (mut client, mut server) = tcp_pair();
        client.write_all(b"\x81\x06health").unwrap();
        assert!(matches!(
            read_frame(&mut server, &mut Vec::new()),
            Err(Error::Protocol)
        ));
    }

    #[test]
    fn parses_a_mosh_menu() {
        let menu = parse_mosh_menu(
            "manager",
            b"\x1b]0;MOSH\x07MOSH1\tmenu\tManager\nMOSH1\titem\tmanager.shell\tShell\ttext\tshell\t1\n",
        )
        .unwrap();
        assert_eq!(menu.title, "Manager");
        assert_eq!(menu.items[0].id, "manager.shell");
        assert!(menu.items[0].enabled);
    }

    #[test]
    fn decodes_action_fields() {
        assert_eq!(
            decode_field("CrOSmium%2Fmodmium").unwrap(),
            "CrOSmium/modmium"
        );
        assert!(decode_field("bad%2").is_err());
    }

    #[test]
    fn finds_an_action_marker_across_output_chunks() {
        let mut output = vec![b'x'; 4094];
        output.extend_from_slice(b"MOSH1\tstarted\tupdateModmium\n");
        assert!(stream_contains(&output[..], b"MOSH1\tstarted\tupdateModmium").unwrap());
    }

    #[test]
    fn parses_typed_mosh_state() {
        let mut fields = BTreeMap::new();
        parse_state_records(
            "/usr/bin/example.sh",
            b"\x1b]0;MOSH\x07MOSH1\tstate\trepository\tstring\tCrOSmium%2Fmodmium\n\
              MOSH1\tstate\tashlandRunning\tbool\t1\n\
              MOSH1\tstate-item\tstableVersions\t152\n\
              MOSH1\tstate-item\tstableVersions\t151\n",
            &mut fields,
        )
        .unwrap();
        assert!(matches!(
            fields.get("repository"),
            Some(StateValue::String(value)) if value == "CrOSmium/modmium"
        ));
        assert!(matches!(
            fields.get("ashlandRunning"),
            Some(StateValue::Bool(true))
        ));
        assert!(matches!(
            fields.get("stableVersions"),
            Some(StateValue::Strings(values)) if values == &["152", "151"]
        ));
    }

    #[test]
    fn rejects_duplicate_and_mixed_mosh_state() {
        let mut fields = BTreeMap::new();
        assert!(
            parse_state_records(
                "/usr/bin/example.sh",
                b"MOSH1\tstate\tshell\tstring\tbash\nMOSH1\tstate\tshell\tstring\tzsh\n",
                &mut fields,
            )
            .is_err()
        );

        let mut fields = BTreeMap::new();
        assert!(
            parse_state_records(
                "/usr/bin/example.sh",
                b"MOSH1\tstate\tshell\tstring\tbash\nMOSH1\tstate-item\tshell\tzsh\n",
                &mut fields,
            )
            .is_err()
        );
    }

    #[test]
    fn rejects_one_duplicate_provider_without_losing_existing_state() {
        let mut fields =
            BTreeMap::from([("shell".to_owned(), StateValue::String("bash".to_owned()))]);
        let provider = BTreeMap::from([
            ("shell".to_owned(), StateValue::String("zsh".to_owned())),
            ("ashlandInstalled".to_owned(), StateValue::Bool(true)),
        ]);
        assert!(merge_state(&mut fields, provider).is_err());
        assert!(matches!(
            fields.get("shell"),
            Some(StateValue::String(value)) if value == "bash"
        ));
        assert!(!fields.contains_key("ashlandInstalled"));
    }

    #[test]
    fn caps_advertised_action_arguments() {
        assert_eq!(parse_count("16").unwrap(), 16);
        assert!(parse_count("17").is_err());
        assert!(parse_count("not-a-number").is_err());
    }

    #[test]
    fn builds_registry_from_mosh_descriptions() {
        let mut actions = HashMap::new();
        let mut menus = Vec::new();
        parse_description(
            "/usr/bin/example.sh",
            b"\x1b]0;MOSH\x07MOSH1\taction\trepository.set\t2\t2\nMOSH1\tmenu-owner\tmisc\n",
            &mut actions,
            &mut menus,
        )
        .unwrap();
        let action = actions.get("repository.set").unwrap();
        assert_eq!(action.script, "/usr/bin/example.sh");
        assert_eq!(action.min_arguments, 2);
        assert_eq!(action.max_arguments, 2);
        assert_eq!(menus[0].id, "misc");
    }

    #[test]
    fn rejects_duplicate_mosh_actions() {
        let mut actions = HashMap::new();
        let mut menus = Vec::new();
        parse_description(
            "/usr/bin/one.sh",
            b"MOSH1\taction\tupdate.run\t1\t1\n",
            &mut actions,
            &mut menus,
        )
        .unwrap();
        assert!(
            parse_description(
                "/usr/bin/two.sh",
                b"MOSH1\taction\tupdate.run\t1\t1\n",
                &mut actions,
                &mut menus,
            )
            .is_err()
        );
    }

    #[test]
    fn trusted_script_paths_are_unique_and_absolute() {
        let scripts: Vec<_> = trusted_scripts().collect();
        assert!(!scripts.is_empty());
        assert!(scripts.iter().all(|path| path.starts_with("/usr/bin/")));
        let mut unique = scripts.clone();
        unique.sort_unstable();
        unique.dedup();
        assert_eq!(unique.len(), scripts.len());
    }

    fn tcp_pair() -> (TcpStream, TcpStream) {
        let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0)).unwrap();
        let address = listener.local_addr().unwrap();
        let client = TcpStream::connect(address).unwrap();
        let (server, _) = listener.accept().unwrap();
        (client, server)
    }
}
