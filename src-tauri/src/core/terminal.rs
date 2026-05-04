use portable_pty::{native_pty_system, CommandBuilder, PtySize, Child, MasterPty};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use uuid::Uuid;

fn build_user_path() -> String {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/".to_string());
    let base_paths = vec![
        "/usr/local/bin".to_string(),
        "/opt/homebrew/bin".to_string(),
        format!("{}/.local/bin", home),
        format!("{}/.cargo/bin", home),
        format!("{}/.nvm/versions/node/current/bin", home),
        format!("{}/.pnpm-home", home),
        "/usr/bin".to_string(),
        "/bin".to_string(),
        "/usr/sbin".to_string(),
        "/sbin".to_string(),
    ];

    let current_path = std::env::var("PATH").unwrap_or_default();
    let mut all_paths: Vec<String> = base_paths;
    for p in current_path.split(':') {
        let p = p.to_string();
        if !all_paths.contains(&p) {
            all_paths.push(p);
        }
    }
    all_paths.join(":")
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalInstance {
    pub id: Uuid,
    pub name: String,
    pub cwd: String,
}

pub struct TerminalManager {
    instances: HashMap<Uuid, TerminalInstance>,
    children: HashMap<Uuid, Box<dyn Child + Send>>,
    writers: HashMap<Uuid, Arc<Mutex<Box<dyn Write + Send>>>>,
    readers: HashMap<Uuid, Arc<Mutex<Box<dyn Read + Send>>>>,
    ptys: HashMap<Uuid, Box<dyn MasterPty + Send>>,
    size: PtySize,
}

impl TerminalManager {
    pub fn new() -> Self {
        Self {
            instances: HashMap::new(),
            children: HashMap::new(),
            writers: HashMap::new(),
            readers: HashMap::new(),
            ptys: HashMap::new(),
            size: PtySize {
                rows: 24,
                cols: 80,
                pixel_width: 0,
                pixel_height: 0,
            },
        }
    }

    pub fn create_instance(&mut self, cwd: Option<String>, shell: Option<String>, command: Option<String>) -> Result<(TerminalInstance, Arc<Mutex<Box<dyn Read + Send>>>), String> {
        let pty_system = native_pty_system();

        let pair = pty_system.openpty(self.size).map_err(|e| e.to_string())?;

        let cwd = cwd.unwrap_or_else(|| {
            std::env::current_dir()
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_else(|_| "/".to_string())
        });

        let user_path = build_user_path();

        let cmd = if let Some(cmd_str) = command {
            let parts: Vec<&str> = cmd_str.split_whitespace().collect();
            if parts.is_empty() {
                return Err("Empty command".to_string());
            }
            let mut builder = CommandBuilder::new(parts[0]);
            if parts.len() > 1 {
                builder.args(&parts[1..]);
            }
            builder.cwd(&cwd);
            builder.env("TERM", "xterm-256color");
            builder.env("PATH", &user_path);
            builder
        } else {
            let shell_val = shell.unwrap_or_else(|| {
                std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".to_string())
            });
            let mut builder = CommandBuilder::new(&shell_val);
            builder.arg("-l");
            builder.cwd(&cwd);
            builder.env("TERM", "xterm-256color");
            builder.env("PATH", &user_path);
            builder
        };

        let child = pair.slave.spawn_command(cmd).map_err(|e| e.to_string())?;

        let reader = pair.master.try_clone_reader().map_err(|e| e.to_string())?;
        let writer = pair.master.take_writer().map_err(|e| e.to_string())?;

        let id = Uuid::new_v4();
        let name = format!("Terminal {}", self.instances.len() + 1);

        let instance = TerminalInstance {
            id,
            name,
            cwd,
        };

        let reader_arc = Arc::new(Mutex::new(reader));
        self.instances.insert(id, instance.clone());
        self.children.insert(id, child);
        self.readers.insert(id, reader_arc.clone());
        self.writers.insert(id, Arc::new(Mutex::new(writer)));
        self.ptys.insert(id, pair.master);

        Ok((instance, reader_arc))
    }

    pub fn write(&self, id: Uuid, data: &str) -> Result<(), String> {
        if let Some(writer) = self.writers.get(&id) {
            let mut writer = writer.lock().unwrap();
            writer.write_all(data.as_bytes()).map_err(|e| e.to_string())?;
            writer.flush().map_err(|e| e.to_string())?;
            Ok(())
        } else {
            Err("Terminal not found".to_string())
        }
    }

    pub fn resize(&mut self, id: Uuid, rows: u16, cols: u16) -> Result<(), String> {
        if let Some(pty) = self.ptys.get_mut(&id) {
            pty.resize(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            }).map_err(|e| e.to_string())?;
        }
        self.size = PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        };
        Ok(())
    }

    pub fn kill(&mut self, id: Uuid) -> Result<(), String> {
        if let Some(mut child) = self.children.remove(&id) {
            let _ = child.kill();
            let _ = child.wait();
            self.instances.remove(&id);
            self.readers.remove(&id);
            self.writers.remove(&id);
            self.ptys.remove(&id);
            Ok(())
        } else {
            Err("Terminal not found".to_string())
        }
    }

    #[allow(dead_code)]
    pub fn get_instance(&self, id: Uuid) -> Option<&TerminalInstance> {
        self.instances.get(&id)
    }

    pub fn get_all_instances(&self) -> Vec<TerminalInstance> {
        self.instances.values().cloned().collect()
    }

    #[allow(dead_code)]
    pub fn is_running(&self, _id: Uuid) -> bool {
        true
    }
}

impl Default for TerminalManager {
    fn default() -> Self {
        Self::new()
    }
}