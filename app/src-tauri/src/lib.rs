use serde::Serialize;

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
    pty_plugin: bool,
}

#[tauri::command]
fn health_check() -> HealthStatus {
    HealthStatus {
        status: "green".into(),
        product: "cockpit".into(),
        seed: "cockpit-20260907".into(),
        tauri: true,
        pty_plugin: true,
    }
}

#[tauri::command]
fn gh_auth_status() -> GhAuthStatus {
    let output = std::process::Command::new("gh")
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_pty::init())
        .invoke_handler(tauri::generate_handler![health_check, gh_auth_status])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
