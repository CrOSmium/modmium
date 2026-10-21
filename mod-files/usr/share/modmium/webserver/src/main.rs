mod server;

use std::process::ExitCode;

fn main() -> ExitCode {
    match server::run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("modmium-web: {error}");
            ExitCode::FAILURE
        }
    }
}
