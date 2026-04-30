use portable_pty::{native_pty_system, CommandBuilder, PtySize, Child};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use uuid::Uuid;

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
    size: PtySize,
}

impl TerminalManager {
    pub fn new() -> Self {
        Self {
            instances: HashMap::new(),
            children: HashMap::new(),
            writers: HashMap::new(),
            readers: HashMap::new(),
            size: PtySize {
                rows: 24,
                cols: 80,
                pixel_width: 0,
                pixel_height: 0,
            },
        }
    }

    pub fn create_instance(&mut self, cwd: Option<String>, shell: Option<String>) -> Result<TerminalInstance, String> {
        let pty_system = native_pty_system();

        let pair = pty_system.openpty(self.size).map_err(|e| e.to_string())?;

        let shell = shell.unwrap_or_else(|| {
            std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".to_string())
        });

        let cwd = cwd.unwrap_or_else(|| {
            std::env::current_dir()
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_else(|_| "/".to_string())
        });

        let mut cmd = CommandBuilder::new(&shell);
        cmd.cwd(&cwd);
        cmd.env("TERM", "xterm-256color");

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

        self.instances.insert(id, instance.clone());
        self.children.insert(id, child);
        self.readers.insert(id, Arc::new(Mutex::new(reader)));
        self.writers.insert(id, Arc::new(Mutex::new(writer)));

        Ok(instance)
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

    pub fn read(&self, id: Uuid, timeout_ms: u64) -> Result<String, String> {
        if let Some(reader) = self.readers.get(&id) {
            let mut reader = reader.lock().unwrap();
            let mut buffer = vec![0u8; 8192];
            let deadline = std::time::Instant::now().checked_add(Duration::from_millis(timeout_ms));

            let mut result = Vec::new();
            loop {
                match reader.read(&mut buffer) {
                    Ok(0) => break,
                    Ok(n) => {
                        result.extend_from_slice(&buffer[..n]);
                        if let Some(d) = deadline {
                            if std::time::Instant::now() >= d {
                                break;
                            }
                        }
                    }
                    Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        if let Some(d) = deadline {
                            if std::time::Instant::now() >= d {
                                break;
                            }
                        }
                        thread::sleep(Duration::from_millis(10));
                        continue;
                    }
                    Err(e) => return Err(e.to_string()),
                }
            }
            Ok(String::from_utf8_lossy(&result).to_string())
        } else {
            Ok(String::new())
        }
    }

    pub fn resize(&mut self, _id: Uuid, rows: u16, cols: u16) -> Result<(), String> {
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
            child.kill().map_err(|e| e.to_string())?;
            self.instances.remove(&id);
            self.readers.remove(&id);
            self.writers.remove(&id);
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