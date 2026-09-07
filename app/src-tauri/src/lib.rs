use parking_lot::Mutex;
use portable_pty::{native_pty_system, CommandBuilder, PtySize};
use serde::Serialize;
use std::collections::HashMap;
use std::io::{Read, Write};
use std::process::Command;
use std::sync::Arc;
use tauri::{Emitter, State};

struct PtyState {
    sessions: Mutex<HashMap<String, Arc<Mutex<Box<dyn portable_pty::MasterPty + Send>>>>>,
}

#[derive(Serialize)]
struct GhAuthStatus {
    authenticated: bool,
    user: Option<String>,
    host: String,
}

#[derive(Serialize)]
struct HealthStatus {
    status: String,
    product: String,
    seed: String,
    tauri: bool,
}

#[tauri::command]
fn health_check() -> HealthStatus {
    HealthStatus {
        status: "green".into(),
        product: "cockpit".into(),
        seed: "cockpit-20260907".into(),
        tauri: true,
    }
}

#[tauri::command]
fn gh_auth_status() -> GhAuthStatus {
    let output = Command::new("gh")
        .args(["auth", "status", "-h", "github.com"])
        .output();
    match output {
        Ok(o) => {
            let text = String::from_utf8_lossy(&o.stderr).to_string()
                + &String::from_utf8_lossy(&o.stdout);
            let user = text
                .split_whitespace()
                .collect::<Vec<_>>()
                .windows(2)
                .find(|w| w[0].contains("account"))
                .map(|w| w[1].to_string());
            GhAuthStatus {
                authenticated: text.contains("Logged in"),
                user,
                host: "github.com".into(),
            }
        }
        Err(_) => GhAuthStatus {
            authenticated: false,
            user: None,
            host: "github.com".into(),
        },
    }
}

#[tauri::command]
fn pty_spawn(
    state: State<PtyState>,
    app: tauri::AppHandle,
    id: String,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    let pty_system = native_pty_system();
    let pair = pty_system
        .open(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| e.to_string())?;
    let cmd = CommandBuilder::new("bash");
    let _child = pair.slave.spawn_command(cmd).map_err(|e| e.to_string())?;
    drop(pair.slave);
    let master = Arc::new(Mutex::new(pair.master));
    state.sessions.lock().insert(id.clone(), Arc::clone(&master));

    let reader_master = Arc::clone(&master);
    let emit_id = id.clone();
    std::thread::spawn(move || {
        let mut reader = reader_master.lock().try_clone_reader().ok();
        if let Some(mut r) = reader.take() {
            let mut buf = [0u8; 4096];
            loop {
                match r.read(&mut buf) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        let data = String::from_utf8_lossy(&buf[..n]).to_string();
                        let _ = app.emit(&format!("pty-data-{emit_id}"), data);
                    }
                }
            }
        }
    });
    Ok(())
}

#[tauri::command]
fn pty_write(state: State<PtyState>, id: String, data: String) -> Result<(), String> {
    let sessions = state.sessions.lock();
    let master = sessions.get(&id).ok_or("pty not found")?;
    master
        .lock()
        .take_writer()
        .map_err(|e| e.to_string())?
        .write_all(data.as_bytes())
        .map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .manage(PtyState {
            sessions: Mutex::new(HashMap::new()),
        })
        .invoke_handler(tauri::generate_handler![
            health_check,
            gh_auth_status,
            pty_spawn,
            pty_write
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
