//! Windows 后台测试进程：GUI 子系统、不创建窗口、Release 不挂载控制台。
//! 用于验证 `windows_subsystem = "windows"` 行为，与 RustDesk 主程序分离。

#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use std::{
    fs::{self, OpenOptions},
    path::PathBuf,
    time::Duration,
};

const TICK_SECS: u64 = 30;

fn main() {
    #[cfg(windows)]
    detach_console_if_any();

    let log_path = init_file_log();
    tracing::info!(
        target: "audit",
        event = "agent_bg_start",
        pid = std::process::id(),
        log = %log_path.display(),
    );

    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .thread_name("agent-bg")
        .build()
        .expect("tokio runtime");

    rt.block_on(async {
        let mut interval = tokio::time::interval(Duration::from_secs(TICK_SECS));
        loop {
            tokio::select! {
                _ = interval.tick() => {
                    tracing::info!(
                        target: "audit",
                        event = "heartbeat",
                        pid = std::process::id(),
                    );
                }
                _ = tokio::signal::ctrl_c() => {
                    tracing::info!(target: "audit", event = "agent_bg_stop", reason = "ctrl_c");
                    break;
                }
            }
        }
    });
}

#[cfg(windows)]
fn detach_console_if_any() {
    use windows::Win32::System::Console::{AttachConsole, FreeConsole, ATTACH_PARENT_PROCESS};
    unsafe {
        if AttachConsole(ATTACH_PARENT_PROCESS).is_ok() {
            let _ = FreeConsole();
        }
    }
}

#[cfg(not(windows))]
fn detach_console_if_any() {}

fn init_file_log() -> PathBuf {
    let log_dir = log_directory();
    let _ = fs::create_dir_all(&log_dir);
    let log_path = log_dir.join("agent-bg.log");

    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .expect("open log file");

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .with_target(false)
        .with_ansi(false)
        .with_writer(std::sync::Mutex::new(file))
        .init();

    log_path
}

fn log_directory() -> PathBuf {
    if let Ok(dir) = std::env::var("PROGRAMDATA") {
        return PathBuf::from(dir).join("RustDeskAgentTest").join("logs");
    }
    std::env::temp_dir().join("RustDeskAgentTest").join("logs")
}
