use rayon::prelude::*;
use glob::Pattern;
use std::path::Path;
use std::collections::HashSet;

mod file_ops;

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct FileNode {
    path: String,
    name: String,
    char_count: usize,
    size_bytes: u64,
    extension: String,
    hidden: bool,
}

#[derive(serde::Serialize)]
struct AddFilesResult {
    files: Vec<FileNode>,
    errors: Vec<String>,
}

struct FilterPatterns {
    exclude: Vec<Pattern>,
    hide: Vec<Pattern>,
}

impl FilterPatterns {
    fn new(excluded_patterns: &[String], hidden_patterns: &[String]) -> Self {
        let exclude = excluded_patterns.iter()
            .filter_map(|p| Pattern::new(p).ok())
            .collect();
        let hide = hidden_patterns.iter()
            .filter_map(|p| Pattern::new(p).ok())
            .collect();
        Self { exclude, hide }
    }

    fn is_excluded(&self, name: &str) -> bool {
        self.exclude.iter().any(|p| p.matches(name))
    }

    fn is_hidden(&self, name: &str) -> bool {
        self.hide.iter().any(|p| p.matches(name))
    }
}

fn escape_html(input: &str) -> String {
    let mut output = String::with_capacity(input.len() + 10);
    for c in input.chars() {
        match c {
            '<' => output.push_str("&lt;"),
            '>' => output.push_str("&gt;"),
            '&' => output.push_str("&amp;"),
            '"' => output.push_str("&quot;"),
            '\'' => output.push_str("&#x27;"),
            _ => output.push(c),
        }
    }
    output
}

fn collect_directory_files(path: &str, recursive: bool, filter: &FilterPatterns) -> Vec<String> {
    let mut files = Vec::new();
    let path_obj = Path::new(path);

    if !path_obj.is_dir() {
        return files;
    }

    if recursive {
        let walker = walkdir::WalkDir::new(path).into_iter();
        for entry in walker.filter_entry(|e| {
            let name = e.file_name().to_str().unwrap_or("");
            !filter.is_excluded(name) && !name.starts_with('.')
        }).filter_map(|e| e.ok()) {
            let p = entry.path();
            if p.is_file() {
                if let Some(path_str) = p.to_str() {
                    files.push(path_str.to_string());
                }
            }
        }
    } else {
        if let Ok(entries) = std::fs::read_dir(path) {
            for entry in entries.filter_map(|e| e.ok()) {
                let p = entry.path();
                let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
                if p.is_file() && !filter.is_excluded(name) && !name.starts_with('.') {
                    if let Some(path_str) = p.to_str() {
                        files.push(path_str.to_string());
                    }
                }
            }
        }
    }
    files
}

fn process_paths_parallel(paths: Vec<String>, filter: &FilterPatterns) -> AddFilesResult {
    let results: Vec<Result<FileNode, String>> = paths.into_par_iter()
        .map(|path| {
            match file_ops::read_and_check_file(&path, "none") {
                Ok((content, size_bytes)) => {
                    let path_obj = Path::new(&path);
                    let name = path_obj.file_name().unwrap_or_default().to_string_lossy().to_string();
                    let extension = path_obj.extension().unwrap_or_default().to_string_lossy().to_string();
                    
                    Ok(FileNode {
                        path,
                        name: name.clone(),
                        char_count: content.len(),
                        size_bytes,
                        extension,
                        hidden: filter.is_hidden(&name),
                    })
                },
                Err(e) => Err(e),
            }
        })
        .collect();

    let mut files = Vec::with_capacity(results.len());
    let mut errors = Vec::new();

    for res in results {
        match res {
            Ok(node) => files.push(node),
            Err(e) => errors.push(e),
        }
    }

    AddFilesResult { files, errors }
}

#[tauri::command]
fn add_files(paths: Vec<String>, excluded_patterns: Vec<String>, hidden_patterns: Vec<String>) -> Result<AddFilesResult, String> {
    let filter = FilterPatterns::new(&excluded_patterns, &hidden_patterns);
    let mut all_paths = Vec::new();
    
    for path in paths {
        let path_obj = Path::new(&path);
        if path_obj.is_dir() {
            all_paths.extend(collect_directory_files(&path, true, &filter));
        } else {
            let name = path_obj.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if !filter.is_excluded(name) {
                 all_paths.push(path);
            }
        }
    }

    Ok(process_paths_parallel(all_paths, &filter))
}

#[tauri::command]
fn scan_directory(path: String, recursive: bool, excluded_patterns: Vec<String>, hidden_patterns: Vec<String>) -> Result<AddFilesResult, String> {
    let filter = FilterPatterns::new(&excluded_patterns, &hidden_patterns);
    let all_paths = collect_directory_files(&path, recursive, &filter);
    Ok(process_paths_parallel(all_paths, &filter))
}

#[tauri::command]
fn get_merged_content(
    paths: Vec<String>, 
    hidden_paths: Vec<String>, 
    ipynb_output_mode: String, 
    load_full_large_files: bool, 
    force_full_load_paths: Vec<String>,
    large_file_threshold: usize
) -> Result<String, String> {
    let hidden_set: HashSet<&str> = hidden_paths.iter().map(|s| s.as_str()).collect();
    let force_set: HashSet<&str> = force_full_load_paths.iter().map(|s| s.as_str()).collect();

    let contents: Vec<String> = paths.par_iter().enumerate()
        .map(|(index, path)| {
            let path_str = path.as_str();
            
            if hidden_set.contains(path_str) {
                return format!(
                    "<div id=\"file-{}\" class=\"file-header\" data-path=\"{}\">\n-------------------\n{} \n-------------------\n</div>\n<pre><code>{}</code></pre>\n<hr/>\n", 
                    index,
                    escape_html(path_str),
                    path_str, 
                    "####il contenuto del file è stato temporaneamente omesso####"
                );
            }
            
            match file_ops::read_and_check_file(path, &ipynb_output_mode) {
                Ok((mut content, _size)) => {
                    let ext = std::path::Path::new(path).extension().and_then(|s| s.to_str()).unwrap_or("");
                    let char_count = content.len();
                    let mut is_truncated = false;
                    
                    let is_forced = force_set.contains(path_str) || force_set.iter().any(|&p| {
                        path_str.starts_with(p) && (
                            path_str.as_bytes().get(p.len()) == Some(&b'/') ||
                            path_str.as_bytes().get(p.len()) == Some(&b'\\')
                        )
                    });
                    
                    if !load_full_large_files && char_count > large_file_threshold && !is_forced {
                        let mut end = large_file_threshold;
                        while end > 0 && !content.is_char_boundary(end) {
                            end -= 1;
                        }
                        content.truncate(end);
                        content.push_str("\n\n[... The rest of the file was truncated due to its length ...]");
                        is_truncated = true;
                    }

                    format!(
                        "<div id=\"file-{}\" class=\"file-header\" data-path=\"{}\" data-truncated=\"{}\">\n-------------------\n{} \n-------------------\n</div>\n<pre><code class=\"language-{}\">{}</code></pre>\n<hr/>\n", 
                        index,
                        escape_html(path_str),
                        is_truncated,
                        path_str, 
                        ext, 
                        escape_html(&content)
                    )
                },
                Err(e) => format!("<div class=\"error\">Error reading {}: {}</div>", path, e),
            }
        })
        .collect();
        
    Ok(contents.join("\n"))
}

#[tauri::command]
fn exit_app() {
    std::process::exit(0);
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_log::Builder::default().build())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![add_files, get_merged_content, scan_directory, exit_app])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
