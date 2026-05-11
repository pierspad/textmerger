use rayon::prelude::*;
use glob::Pattern;
use std::path::Path;

mod file_ops;

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
struct FileNode {
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

#[tauri::command]
fn add_files(paths: Vec<String>, excluded_patterns: Vec<String>, hidden_patterns: Vec<String>) -> Result<AddFilesResult, String> {
    let patterns: Vec<Pattern> = excluded_patterns.iter()
        .filter_map(|p| Pattern::new(p).ok())
        .collect();
    let hide_patterns: Vec<Pattern> = hidden_patterns.iter()
        .filter_map(|p| Pattern::new(p).ok())
        .collect();

    let is_excluded = |name: &str| -> bool {
        patterns.iter().any(|p| p.matches(name))
    };

    let is_hidden = |name: &str| -> bool {
        hide_patterns.iter().any(|p| p.matches(name))
    };
    
    let mut all_paths = Vec::new();
    
    for path in paths {
        let path_obj = Path::new(&path);
        if path_obj.is_dir() {
            let walker = walkdir::WalkDir::new(&path).into_iter();
            for entry in walker.filter_entry(|e| {
                let name = e.file_name().to_str().unwrap_or("");
                !is_excluded(name) && !name.starts_with('.')
            }).filter_map(|e| e.ok()) {
                let p = entry.path();
                if p.is_file() {
                    if let Some(path_str) = p.to_str() {
                        all_paths.push(path_str.to_string());
                    }
                }
            }
        } else {
            let name = path_obj.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if !is_excluded(name) {
                 all_paths.push(path);
            }
        }
    }

    // Process files in parallel and collect results (ok or error)
    let results: Vec<Result<FileNode, String>> = all_paths.into_par_iter()
        .map(|path| {
            match file_ops::read_and_check_file(&path, "none") {
                Ok(content) => {
                    let path_obj = Path::new(&path);
                    let name = path_obj.file_name().unwrap_or_default().to_string_lossy().to_string();
                    let extension = path_obj.extension().unwrap_or_default().to_string_lossy().to_string();
                    let size_bytes = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
                    
                    Ok(FileNode {
                        path,
                        name: name.clone(),
                        char_count: content.len(),
                        size_bytes,
                        extension,
                        hidden: is_hidden(&name),
                    })
                },
                Err(e) => Err(e),
            }
        })
        .collect();

    let mut new_files = Vec::new();
    let mut errors = Vec::new();

    for res in results {
        match res {
            Ok(node) => new_files.push(node),
            Err(e) => errors.push(e),
        }
    }
    
    Ok(AddFilesResult {
        files: new_files,
        errors,
    })
}

#[tauri::command]
fn scan_directory(path: String, recursive: bool, excluded_patterns: Vec<String>, hidden_patterns: Vec<String>) -> Result<AddFilesResult, String> {
    let patterns: Vec<Pattern> = excluded_patterns.iter()
        .filter_map(|p| Pattern::new(p).ok())
        .collect();
    let hide_patterns: Vec<Pattern> = hidden_patterns.iter()
        .filter_map(|p| Pattern::new(p).ok())
        .collect();

    let is_excluded = |name: &str| -> bool {
        patterns.iter().any(|p| p.matches(name))
    };

    let is_hidden = |name: &str| -> bool {
        hide_patterns.iter().any(|p| p.matches(name))
    };

    let mut all_paths = Vec::new();
    let path_obj = Path::new(&path);

    if path_obj.is_dir() {
        if recursive {
            let walker = walkdir::WalkDir::new(&path).into_iter();
            for entry in walker.filter_entry(|e| {
                let name = e.file_name().to_str().unwrap_or("");
                !is_excluded(name) && !name.starts_with('.')
            }).filter_map(|e| e.ok()) {
                let p = entry.path();
                if p.is_file() {
                    if let Some(path_str) = p.to_str() {
                        all_paths.push(path_str.to_string());
                    }
                }
            }
        } else {
            if let Ok(entries) = std::fs::read_dir(&path) {
                for entry in entries.filter_map(|e| e.ok()) {
                    let p = entry.path();
                    let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
                    if p.is_file() && !is_excluded(name) && !name.starts_with('.') {
                        if let Some(path_str) = p.to_str() {
                            all_paths.push(path_str.to_string());
                        }
                    }
                }
            }
        }
    }

    // Process files in parallel and collect results
    let results: Vec<Result<FileNode, String>> = all_paths.into_par_iter()
        .map(|p_str| {
            match file_ops::read_and_check_file(&p_str, "none") {
                Ok(content) => {
                    let path_obj = Path::new(&p_str);
                    let name = path_obj.file_name().unwrap_or_default().to_string_lossy().to_string();
                    let extension = path_obj.extension().unwrap_or_default().to_string_lossy().to_string();
                    let size_bytes = std::fs::metadata(&p_str).map(|m| m.len()).unwrap_or(0);
                    
                    Ok(FileNode {
                        path: p_str,
                        name: name.clone(),
                        char_count: content.len(),
                        size_bytes,
                        extension,
                        hidden: is_hidden(&name),
                    })
                },
                Err(e) => Err(e),
            }
        })
        .collect();

    let mut new_files = Vec::new();
    let mut errors = Vec::new();

    for res in results {
        match res {
            Ok(node) => new_files.push(node),
            Err(e) => errors.push(e),
        }
    }
    
    Ok(AddFilesResult {
        files: new_files,
        errors,
    })
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
    // Read and merge in parallel
    let contents: Vec<String> = paths.par_iter().enumerate()
        .map(|(index, path)| {
            if hidden_paths.contains(path) {
                return format!(
                    "<div id='file-{}' class='file-header' data-path='{}'>\n-------------------\n{} \n-------------------\n</div>\n<pre><code>{}</code></pre>\n<hr/>\n", 
                    index,
                    html_escape::encode_double_quoted_attribute(path),
                    path, 
                    "####il contenuto del file è stato temporaneamente omesso####"
                );
            }
            match file_ops::read_and_check_file(path, &ipynb_output_mode) {
                Ok(mut content) => {
                    let ext = std::path::Path::new(path).extension().and_then(|s| s.to_str()).unwrap_or("");
                    let char_count = content.len();
                    let mut is_truncated = false;
                    
                    let is_forced = force_full_load_paths.iter().any(|p| path == p || path.starts_with(&format!("{}/", p)) || path.starts_with(&format!("{}\\", p)));
                    if !load_full_large_files && char_count > large_file_threshold && !is_forced {
                        // Find a safe character boundary
                        let mut end = large_file_threshold;
                        while end > 0 && !content.is_char_boundary(end) {
                            end -= 1;
                        }
                        content.truncate(end);
                        content.push_str("\n\n[... The rest of the file was truncated due to its length ...]");
                        is_truncated = true;
                    }

                    format!(
                        "<div id='file-{}' class='file-header' data-path='{}' data-truncated='{}'>\n-------------------\n{} \n-------------------\n</div>\n<pre><code class='language-{}'>{}</code></pre>\n<hr/>\n", 
                        index,
                        html_escape::encode_double_quoted_attribute(path),
                        is_truncated,
                        path, 
                        ext, 
                        html_escape::encode_text(&content)
                    )
                },
                Err(e) => format!("<div class='error'>Error reading {}: {}</div>", path, e),
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
