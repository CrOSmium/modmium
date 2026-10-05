use std::fmt;
use std::io::{self, Read, Write};
use std::net::{Ipv4Addr, SocketAddrV4, TcpListener, TcpStream};
use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};
use std::thread;
use std::time::Duration;

const ADDRESS: SocketAddrV4 = SocketAddrV4::new(Ipv4Addr::LOCALHOST, 27182);
const MAX_HANDSHAKE: usize = 8 * 1024;
const MAX_MESSAGE: usize = 16 * 1024;
const MAX_CONNECTIONS: usize = 8;
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(3);
const WRITE_TIMEOUT: Duration = Duration::from_secs(3);
const EXPECTED_HOST: &str = "127.0.0.1:27182";
const WEBUI_ORIGIN: &str = "chrome://borealis-motd";
const BRIDGE_ORIGIN: &str = "http://127.0.0.1:27182";
const PROTOCOL: &str = "modmium.v1";
const WEBSOCKET_GUID: &[u8] = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

const BRIDGE_HTML: &str = r#"<!doctype html><meta charset=utf-8><script>
const webuiOrigin = 'chrome://borealis-motd';
const socket = new WebSocket('ws://127.0.0.1:27182/v1', 'modmium.v1');
socket.onopen = () => parent.postMessage({type: 'ready'}, webuiOrigin);
socket.onmessage = event => parent.postMessage({type: 'response', body: event.data}, webuiOrigin);
addEventListener('message', event => {
  if (event.origin === webuiOrigin && event.source === parent &&
      event.data?.type === 'request' && typeof event.data.body === 'string' &&
      socket.readyState === WebSocket.OPEN) {
    socket.send(event.data.body);
  }
});
</script>"#;

const HEALTH_JSON: &str = concat!(
    "{\"apiVersion\":1,\"serviceVersion\":\"",
    env!("CARGO_PKG_VERSION"),
    "\",\"status\":\"ok\"}"
);

pub fn run() -> io::Result<()> {
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
        thread::Builder::new()
            .name("modmium-ws".into())
            .stack_size(64 * 1024)
            .spawn(move || {
                let _connection = connection;
                match serve(stream) {
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

fn serve(mut stream: TcpStream) -> Result<(), Error> {
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
                if payload == b"health" {
                    write_frame(&mut stream, 0x1, HEALTH_JSON.as_bytes())?;
                } else {
                    write_frame(&mut stream, 0x1, b"{\"error\":\"unknown request\"}")?;
                }
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

    fn tcp_pair() -> (TcpStream, TcpStream) {
        let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0)).unwrap();
        let address = listener.local_addr().unwrap();
        let client = TcpStream::connect(address).unwrap();
        let (server, _) = listener.accept().unwrap();
        (client, server)
    }
}
