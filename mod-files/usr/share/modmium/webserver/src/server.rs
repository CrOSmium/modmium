use std::fmt;
use std::fs;
use std::io::{self, Read, Write};
use std::net::{Ipv4Addr, SocketAddrV4, TcpListener, TcpStream};
use std::path::Path;
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
const MAX_APPS_CONFIG: usize = 16 * 1024;
const MAX_CONNECTIONS: usize = 8;
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(3);
const WRITE_TIMEOUT: Duration = Duration::from_secs(3);
const EXPECTED_HOST: &str = "127.0.0.1:27182";
const WEBUI_ORIGIN: &str = "chrome://borealis-motd";
const BRIDGE_ORIGIN: &str = "http://127.0.0.1:27182";
const PROTOCOL: &str = "modmium.v1";
const WEBSOCKET_GUID: &[u8] = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
const MOSH_MENUS: &[(&str, &str)] = &[("misc", "/usr/bin/mosh-misc.sh")];
const UPDATE_SCRIPT: &str = "/usr/bin/update-modmium.sh";
const REPOSITORY_SCRIPT: &str = "/usr/bin/change-repo.sh";
const ENROLLMENT_SCRIPT: &str = "/usr/bin/toggle-enrollment.sh";
const FEATURES_SCRIPT: &str = "/usr/bin/features.sh";
const POLICIES_SCRIPT: &str = "/usr/bin/devpolicy-editor.sh";
const BOOTSPLASH_SCRIPT: &str = "/usr/bin/modify-bootsplash.sh";
const CR3NROLL_SCRIPT: &str = "/usr/bin/cr3nroll.sh";
const REVERT_SCRIPT: &str = "/usr/bin/emergency-revert.sh";
const NIX_SCRIPT: &str = "/usr/bin/nix-preinstall.sh";
const ASHLAND_SCRIPT: &str = "/usr/bin/ashland.sh";

const MOSH_ACTIONS: &[(&str, &str, &str, usize, usize)] = &[
    ("update.run", UPDATE_SCRIPT, "updateModmium", 1, 1),
    ("version.install", UPDATE_SCRIPT, "installCros", 6, 8),
    ("boot.swap", UPDATE_SCRIPT, "toggleBootPriority", 3, 3),
    ("shell.set", "/usr/bin/change-shell.sh", "changeShell", 1, 1),
    ("repository.set", REPOSITORY_SCRIPT, "changeRepo", 2, 2),
    ("repository.reset", REPOSITORY_SCRIPT, "resetRepo", 1, 1),
    ("enrollment.enable", ENROLLMENT_SCRIPT, "yesenroll", 2, 2),
    ("enrollment.disable", ENROLLMENT_SCRIPT, "noenroll", 2, 2),
    (
        "feature.chromebook-plus",
        FEATURES_SCRIPT,
        "chromebookPlus",
        0,
        0,
    ),
    ("feature.studio-mic", FEATURES_SCRIPT, "studioMic", 0, 0),
    ("feature.system-blur", FEATURES_SCRIPT, "systemBlur", 0, 0),
    ("policies.save", POLICIES_SCRIPT, "policies.save", 1, 1),
    ("policies.load", POLICIES_SCRIPT, "policies.load", 0, 0),
    ("policies.apply", POLICIES_SCRIPT, "policies.apply", 0, 0),
    ("policies.reset", POLICIES_SCRIPT, "policies.reset", 0, 0),
    ("bootsplash.replace", BOOTSPLASH_SCRIPT, "replace", 1, 1),
    (
        "bootsplash.custom",
        BOOTSPLASH_SCRIPT,
        "replace_custom",
        1,
        1,
    ),
    ("bootsplash.restore", BOOTSPLASH_SCRIPT, "restore", 0, 0),
    (
        "bootsplash.download",
        BOOTSPLASH_SCRIPT,
        "download_backup",
        0,
        0,
    ),
    ("bootsplash.remove", BOOTSPLASH_SCRIPT, "remove", 1, 1),
    ("cr3nroll.save", CR3NROLL_SCRIPT, "cr3nroll.save", 2, 2),
    ("cr3nroll.load", CR3NROLL_SCRIPT, "cr3nroll.load", 1, 1),
    (
        "cr3nroll.generate",
        CR3NROLL_SCRIPT,
        "cr3nroll.generate",
        4,
        4,
    ),
    ("cr3nroll.import", CR3NROLL_SCRIPT, "cr3nroll.import", 1, 1),
    ("cr3nroll.backup", CR3NROLL_SCRIPT, "cr3nroll.backup", 1, 1),
    ("revert.factory", REVERT_SCRIPT, "factoryReset", 2, 4),
    ("revert.os", REVERT_SCRIPT, "restoreOS", 1, 1),
    ("revert.mpkeys", REVERT_SCRIPT, "restoreMPkeys", 1, 3),
    ("nix.install", NIX_SCRIPT, "installNix", 0, 0),
    ("mix.update", NIX_SCRIPT, "updateMix", 0, 0),
    ("ashland.install", ASHLAND_SCRIPT, "installAshland", 0, 0),
    ("ashland.update", ASHLAND_SCRIPT, "updateAshland", 0, 0),
    (
        "ashland.uninstall",
        ASHLAND_SCRIPT,
        "uninstallAshland",
        0,
        0,
    ),
    ("ashland.toggle", ASHLAND_SCRIPT, "toggleAshland", 0, 0),
    ("ashland.autostart", ASHLAND_SCRIPT, "toggleAutostart", 0, 0),
    ("ashland.layout", ASHLAND_SCRIPT, "cycleLayout", 0, 0),
    ("ashland.gaps", ASHLAND_SCRIPT, "cycleGaps", 0, 0),
];

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
                let response = match std::str::from_utf8(&payload) {
                    Ok("health") => HEALTH_JSON.to_owned(),
                    Ok("state") => modmium_state(),
                    Ok("menus") => describe_mosh().unwrap_or_else(error_json),
                    Ok(request) if request.starts_with("run\t") => {
                        run_mosh_action(request).unwrap_or_else(error_json)
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

fn modmium_state() -> String {
    let branch = read_trimmed("/.branch").unwrap_or_else(|| "unknown".into());
    let version = read_trimmed("/usr/share/.version").unwrap_or_else(|| "unknown".into());
    let milestone = read_lsb_value("CHROMEOS_RELEASE_CHROME_MILESTONE").unwrap_or_default();
    let board = read_lsb_value("CHROMEOS_RELEASE_BOARD").unwrap_or_default();
    let shell = read_trimmed("/root/.modshell")
        .and_then(|path| Path::new(&path).file_name()?.to_str().map(str::to_owned))
        .unwrap_or_else(|| "bash".into());
    let owner = read_trimmed("/usr/share/.gitowner").unwrap_or_else(|| "CrOSmium".into());
    let repository = read_trimmed("/usr/share/.gitrepo").unwrap_or_else(|| "modmium".into());
    let apps = fs::read_to_string("/usr/local/config/apps.conf").unwrap_or_default();
    let policies =
        fs::read_to_string("/usr/local/share/policy-test-tool/dump.json").unwrap_or_default();

    let mut json = String::from("{\"type\":\"state\",\"branch\":");
    push_json_string(&mut json, &branch);
    json.push_str(",\"modmiumVersion\":");
    push_json_string(&mut json, &version);
    json.push_str(",\"chromeosVersion\":");
    push_json_string(&mut json, &milestone);
    json.push_str(",\"board\":");
    push_json_string(&mut json, &board);
    json.push_str(",\"shell\":");
    push_json_string(&mut json, &shell);
    json.push_str(",\"repository\":");
    push_json_string(
        &mut json,
        &format!("https://github.com/{owner}/{repository}"),
    );
    json.push_str(",\"appsConfig\":");
    push_json_string(&mut json, &apps);
    json.push_str(",\"devicePolicies\":");
    push_json_string(&mut json, &policies);
    json.push_str(",\"bootRoot\":");
    push_json_string(&mut json, &boot_root());
    push_string_array(&mut json, "bootsplashes", &bootsplashes());
    push_string_array(&mut json, "savedEnrollmentKeys", &saved_enrollment_keys());
    push_string_array(&mut json, "stableVersions", &stable_versions(&milestone));
    push_bool(
        &mut json,
        "enrollmentEnabled",
        !Path::new("/.deprovision").exists(),
    );
    push_bool(
        &mut json,
        "chromebookPlus",
        read_trimmed("/run/libsegmentation/feature_device_info").as_deref() == Some("CAMQAg=="),
    );
    push_bool(
        &mut json,
        "studioMic",
        Path::new("/usr/lib64/libforcefm.so").is_file()
            && file_contains("/usr/share/cros/init/cras-env.sh", "libforcefm.so"),
    );
    push_bool(
        &mut json,
        "systemBlur",
        Path::new("/usr/lib64/libfakephysmem.so").is_file()
            && file_contains("/etc/chrome_dev.conf", "libfakephysmem.so"),
    );
    push_bool(
        &mut json,
        "nixInstalled",
        Path::new("/usr/local/.nix_install_done").is_file(),
    );
    push_bool(
        &mut json,
        "ashlandInstalled",
        Path::new("/usr/local/bin/ashland").is_file(),
    );
    push_bool(
        &mut json,
        "ashlandAutostart",
        Path::new("/etc/init/ashland.conf").is_file(),
    );
    push_bool(
        &mut json,
        "ashlandRunning",
        command_succeeds("pgrep", &["-x", "ashland"]),
    );
    json.push('}');
    json
}

fn boot_root() -> String {
    let output = Command::new("rootdev").arg("-s").output().ok();
    let root = output
        .filter(|output| output.status.success())
        .and_then(|output| String::from_utf8(output.stdout).ok())
        .unwrap_or_default();
    if root.trim_end().ends_with('3') {
        "Root A"
    } else if root.trim_end().ends_with('5') {
        "Root B"
    } else {
        "Unknown"
    }
    .into()
}

fn bootsplashes() -> Vec<String> {
    let Ok(entries) = fs::read_dir("/bootsplash") else {
        return Vec::new();
    };
    let mut names: Vec<_> = entries
        .flatten()
        .filter_map(|entry| entry.file_name().into_string().ok())
        .filter(|name| name.ends_with(".png"))
        .collect();
    names.sort();
    names
}

fn stable_versions(current: &str) -> Vec<String> {
    let contents = fs::read_to_string("/usr/share/.stable_versions.txt").unwrap_or_default();
    let mut versions: Vec<_> = contents
        .split(',')
        .map(str::trim)
        .filter(|version| valid_milestone(version))
        .map(str::to_owned)
        .collect();
    if valid_milestone(current) && !versions.iter().any(|version| version == current) {
        versions.push(current.to_owned());
    }
    versions.sort_by_key(|version| std::cmp::Reverse(version.parse::<u16>().unwrap_or_default()));
    versions.dedup();
    versions
}

fn saved_enrollment_keys() -> Vec<String> {
    let Ok(output) = Command::new("vpd").args(["-i", "RW_VPD", "-l"]).output() else {
        return Vec::new();
    };
    let mut names = Vec::new();
    for line in String::from_utf8_lossy(&output.stdout).lines() {
        let Some(start) = line.find("saved_") else {
            continue;
        };
        let key = &line[start + 6..];
        let key = key.split('_').next().unwrap_or_default().trim_matches('"');
        if valid_key_name(key) && !names.iter().any(|name| name == key) {
            names.push(key.to_owned());
        }
    }
    names.sort();
    names
}

fn command_succeeds(program: &str, arguments: &[&str]) -> bool {
    Command::new(program)
        .args(arguments)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|status| status.success())
}

fn read_trimmed(path: &str) -> Option<String> {
    fs::read_to_string(path)
        .ok()
        .map(|text| text.trim().to_owned())
        .filter(|text| !text.is_empty())
}

fn read_lsb_value(name: &str) -> Option<String> {
    let contents = fs::read_to_string("/etc/lsb-release").ok()?;
    contents.lines().find_map(|line| {
        let (key, value) = line.split_once('=')?;
        (key == name).then(|| value.trim_matches('"').to_owned())
    })
}

fn file_contains(path: &str, needle: &str) -> bool {
    fs::read_to_string(path).is_ok_and(|contents| contents.contains(needle))
}

fn push_bool(json: &mut String, name: &str, value: bool) {
    use std::fmt::Write as _;
    let _ = write!(json, ",\"{name}\":{value}");
}

fn push_string_array(json: &mut String, name: &str, values: &[String]) {
    use std::fmt::Write as _;
    let _ = write!(json, ",\"{name}\":[");
    for (index, value) in values.iter().enumerate() {
        if index != 0 {
            json.push(',');
        }
        push_json_string(json, value);
    }
    json.push(']');
}

fn run_mosh_action(request: &str) -> io::Result<String> {
    let fields: Result<Vec<_>, _> = request.split('\t').skip(1).map(decode_field).collect();
    let fields = fields?;
    let action_id = fields
        .first()
        .ok_or_else(|| io::Error::other("missing action"))?;
    let arguments = &fields[1..];
    if action_id == "apps.save" {
        validate_action_arguments(action_id, arguments)?;
        save_apps_config(&arguments[0])?;
        return action_json(action_id);
    }
    if action_id == "account.create" {
        validate_action_arguments(action_id, arguments)?;
        return run_script_action(action_id, "/usr/bin/localacc.sh", arguments);
    }
    let &(_, script, function, min_arguments, max_arguments) = MOSH_ACTIONS
        .iter()
        .find(|(id, _, _, _, _)| *id == action_id)
        .ok_or_else(|| io::Error::other("action unavailable"))?;
    if !(min_arguments..=max_arguments).contains(&arguments.len()) {
        return Err(io::Error::other("wrong number of action arguments"));
    }
    validate_action_arguments(action_id, arguments)?;

    let mut command = Command::new(script);
    command
        .env("MOSH_FRONTEND", "gui")
        .env("MOSH_GUI_ACTION", function)
        .env("MOSH_GUI_ALLOWED", function)
        .env("TERM", "dumb")
        .env("PATH", "/bin:/usr/bin:/sbin:/usr/sbin:/opt/bin")
        .stdin(Stdio::null())
        .stderr(Stdio::null());
    for (index, argument) in arguments.iter().enumerate() {
        command.env(format!("MOSH_GUI_ARG_{index}"), argument);
    }
    command.stdout(Stdio::piped());
    let mut child = command.spawn()?;
    let marker = format!("MOSH1\tstarted\t{function}").into_bytes();
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
    if action_id == "update.run" {
        schedule_service_restart()?;
    }

    action_json(action_id)
}

fn schedule_service_restart() -> io::Result<()> {
    Command::new("/bin/sh")
        .args(["-c", "sleep 1; restart modmium-web"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    Ok(())
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

fn run_script_action(action_id: &str, script: &str, arguments: &[String]) -> io::Result<String> {
    let mut command = Command::new(script);
    command
        .env("MOSH_FRONTEND", "gui")
        .env("TERM", "dumb")
        .env("PATH", "/bin:/usr/bin:/sbin:/usr/sbin:/opt/bin")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    for (index, argument) in arguments.iter().enumerate() {
        command.env(format!("MOSH_GUI_ARG_{index}"), argument);
    }
    let status = command.status()?;
    if !status.success() {
        return Err(io::Error::other(format!("action failed with {status}")));
    }
    action_json(action_id)
}

fn action_json(action_id: &str) -> io::Result<String> {
    let mut json = String::from("{\"type\":\"action\",\"action\":");
    push_json_string(&mut json, action_id);
    json.push_str(",\"ok\":true}");
    Ok(json)
}

fn save_apps_config(contents: &str) -> io::Result<()> {
    use std::os::unix::fs::PermissionsExt;

    fs::create_dir_all("/usr/local/config")?;
    let temporary = format!("/usr/local/config/.apps.conf.{}", std::process::id());
    fs::write(&temporary, contents)?;
    fs::set_permissions(&temporary, fs::Permissions::from_mode(0o644))?;
    fs::rename(temporary, "/usr/local/config/apps.conf")
}

fn validate_action_arguments(action: &str, arguments: &[String]) -> io::Result<()> {
    let valid = match action {
        "apps.save" => arguments.len() == 1 && valid_apps_config(&arguments[0]),
        "account.create" => {
            arguments.len() == 5
                && valid_account_name(&arguments[0])
                && valid_domain(&arguments[1])
                && !arguments[2].is_empty()
                && arguments[2].len() <= 256
                && arguments[2] == arguments[3]
                && !arguments[4].trim().is_empty()
                && arguments[4].len() <= 128
        }
        "update.run" => {
            arguments.len() == 1 && matches!(arguments[0].as_str(), "stable" | "nightly")
        }
        "version.install" => {
            (6..=8).contains(&arguments.len())
                && valid_milestone(&arguments[0])
                && arguments[1..].iter().all(|argument| valid_choice(argument))
        }
        "boot.swap" => {
            arguments.len() == 3 && arguments.iter().all(|argument| valid_choice(argument))
        }
        "shell.set" => {
            let shell = &arguments[0];
            !shell.is_empty()
                && shell.len() <= 128
                && shell.bytes().all(|byte| {
                    byte.is_ascii_alphanumeric() || matches!(byte, b'/' | b'_' | b'.' | b'+' | b'-')
                })
        }
        "repository.set" => valid_github_url(&arguments[0]) && arguments[1] == "true",
        "repository.reset" => arguments[0] == "true",
        "enrollment.enable" | "enrollment.disable" => arguments == ["y", "y"],
        "bootsplash.replace" => arguments.len() == 1 && valid_filename(&arguments[0]),
        "bootsplash.custom" => arguments.len() == 1 && valid_relative_path(&arguments[0]),
        "bootsplash.remove" => arguments == ["y"],
        "policies.save" => arguments.len() == 1 && arguments[0].len() <= MAX_MESSAGE,
        "cr3nroll.save" => {
            arguments.len() == 2 && valid_key_name(&arguments[0]) && arguments[1] == "y"
        }
        "cr3nroll.load" => arguments.len() == 1 && valid_key_name(&arguments[0]),
        "cr3nroll.generate" => {
            arguments.len() == 4
                && arguments[0] == "y"
                && arguments[1] == "a"
                && arguments[2] == "y"
                && valid_key_name(&arguments[3])
        }
        "cr3nroll.import" | "cr3nroll.backup" => {
            arguments.len() == 1 && valid_device_path(&arguments[0])
        }
        "revert.factory" => {
            arguments.len() >= 2
                && valid_milestone(arguments.last().unwrap())
                && arguments[..arguments.len() - 1]
                    .iter()
                    .all(|argument| valid_choice(argument))
                && arguments[0] == "y"
        }
        "revert.mpkeys" => {
            arguments.iter().all(|argument| valid_choice(argument))
                && arguments.first().is_some_and(|argument| argument == "y")
        }
        "revert.os" => arguments.len() == 1 && valid_milestone(&arguments[0]),
        _ => arguments.is_empty() && MOSH_ACTIONS.iter().any(|item| item.0 == action),
    };
    if valid {
        Ok(())
    } else {
        Err(io::Error::other("invalid action arguments"))
    }
}

fn valid_choice(value: &str) -> bool {
    matches!(value, "y" | "n" | "stable" | "nightly")
}

fn valid_milestone(value: &str) -> bool {
    value
        .parse::<u16>()
        .is_ok_and(|milestone| (80..=999).contains(&milestone))
}

fn valid_filename(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && !value.contains('/')
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'.' | b'+' | b'-'))
}

fn valid_relative_path(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 512
        && !value.starts_with('/')
        && !value.split('/').any(|part| part == "..")
        && !value
            .bytes()
            .any(|byte| byte == 0 || byte == b'\r' || byte == b'\n')
}

fn valid_device_path(value: &str) -> bool {
    (value.starts_with("/home/user/") || value.starts_with("/mnt/stateful_partition/"))
        && value.len() <= 512
        && !value.split('/').any(|part| part == "..")
        && !value
            .bytes()
            .any(|byte| byte == 0 || byte == b'\r' || byte == b'\n')
}

fn valid_key_name(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'-'))
}

fn valid_account_name(value: &str) -> bool {
    !value.trim().is_empty()
        && value.len() <= 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
}

fn valid_domain(value: &str) -> bool {
    value.len() <= 253
        && value.contains('.')
        && !value.ends_with('.')
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'-'))
}

fn valid_apps_config(contents: &str) -> bool {
    if contents.len() > MAX_APPS_CONFIG {
        return false;
    }
    let mut entries = 0;
    for line in contents.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((command, name)) = line.split_once('|') else {
            return false;
        };
        if command.trim().is_empty() || name.trim().is_empty() {
            return false;
        }
        entries += 1;
    }
    entries <= 38
}

fn valid_github_url(url: &str) -> bool {
    let Some(path) = url.strip_prefix("https://github.com/") else {
        return false;
    };
    let mut parts = path.strip_suffix(".git").unwrap_or(path).split('/');
    let (Some(owner), Some(repository), None) = (parts.next(), parts.next(), parts.next()) else {
        return false;
    };
    [owner, repository].into_iter().all(|part| {
        !part.is_empty()
            && part.len() <= 100
            && part
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'.' | b'-'))
    })
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
    id: &'static str,
    title: String,
    items: Vec<MoshItem>,
}

fn describe_mosh() -> io::Result<String> {
    let mut menus = Vec::with_capacity(MOSH_MENUS.len());
    for &(id, script) in MOSH_MENUS {
        let output = Command::new(script)
            .env("MOSH_FRONTEND", "gui")
            .env("MOSH_GUI_ACTION", "")
            .env("TERM", "dumb")
            .env("PATH", "/bin:/usr/bin:/sbin:/usr/sbin:/opt/bin")
            .stdin(Stdio::null())
            .stderr(Stdio::null())
            .output()?;
        if !output.status.success() {
            return Err(io::Error::other(format!(
                "{script} exited with {}",
                output.status
            )));
        }
        menus.push(parse_mosh_menu(id, &output.stdout)?);
    }

    let mut json = String::from("{\"type\":\"menus\",\"menus\":[");
    for (menu_index, menu) in menus.iter().enumerate() {
        if menu_index != 0 {
            json.push(',');
        }
        json.push_str("{\"id\":");
        push_json_string(&mut json, menu.id);
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

fn parse_mosh_menu(id: &'static str, output: &[u8]) -> io::Result<MoshMenu> {
    let text = String::from_utf8_lossy(output);
    let mut title = None;
    let mut items = Vec::new();
    for line in text.lines() {
        let Some(record) = line.strip_prefix("MOSH1\t") else {
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
    Ok(MoshMenu { id, title, items })
}

fn valid_name(name: &str) -> bool {
    !name.is_empty()
        && name
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
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
            b"noise\nMOSH1\tmenu\tManager\nMOSH1\titem\tmanager.shell\tShell\ttext\tshell\t1\n",
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
    fn accepts_the_gui_action_arguments() {
        assert!(validate_action_arguments("shell.set", &["/bin/bash".into()]).is_ok());
        assert!(
            validate_action_arguments(
                "repository.set",
                &["https://github.com/CrOSmium/modmium".into(), "true".into()]
            )
            .is_ok()
        );
        assert!(
            validate_action_arguments(
                "apps.save",
                &["nano /usr/local/config/apps.conf | Edit apps.conf".into()]
            )
            .is_ok()
        );
        assert!(
            validate_action_arguments(
                "account.create",
                &[
                    "pilot".into(),
                    "modmium.dev".into(),
                    "password".into(),
                    "password".into(),
                    "Pilot".into(),
                ]
            )
            .is_ok()
        );
    }

    #[test]
    fn rejects_shell_words_and_non_github_repositories() {
        assert!(validate_action_arguments("shell.set", &["bash -c id".into()]).is_err());
        assert!(
            validate_action_arguments(
                "repository.set",
                &["https://example.com/owner/repo".into(), "true".into()]
            )
            .is_err()
        );
        assert!(validate_action_arguments("apps.save", &["missing separator".into()]).is_err());
        assert!(MOSH_ACTIONS.iter().all(|action| !action.0.contains("user")));
    }

    #[test]
    fn state_snapshot_contains_the_current_repository() {
        let state = modmium_state();
        assert!(state.starts_with("{\"type\":\"state\""));
        assert!(state.contains("\"repository\":\"https://github.com/"));
    }

    fn tcp_pair() -> (TcpStream, TcpStream) {
        let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0)).unwrap();
        let address = listener.local_addr().unwrap();
        let client = TcpStream::connect(address).unwrap();
        let (server, _) = listener.accept().unwrap();
        (client, server)
    }
}
