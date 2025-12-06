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
}

#[derive(serde::Serialize)]
struct AddFilesResult {
    files: Vec<FileNode>,
    errors: Vec<String>,
}

#[tauri::command]
fn add_files(paths: Vec<String>, excluded_patterns: Vec<String>) -> Result<AddFilesResult, String> {
    let patterns: Vec<Pattern> = excluded_patterns.iter()
        .filter_map(|p| Pattern::new(p).ok())
        .collect();

    let is_excluded = |name: &str| -> bool {
        patterns.iter().any(|p| p.matches(name))
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
            match file_ops::read_and_check_file(&path, false) {
                Ok(content) => {
                    let path_obj = Path::new(&path);
                    let name = path_obj.file_name().unwrap_or_default().to_string_lossy().to_string();
                    let extension = path_obj.extension().unwrap_or_default().to_string_lossy().to_string();
                    let size_bytes = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
                    
                    Ok(FileNode {
                        path,
                        name,
                        char_count: content.len(),
                        size_bytes,
                        extension,
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
fn get_merged_content(paths: Vec<String>, show_outputs: bool) -> Result<String, String> {
    // Read and merge in parallel
    let contents: Vec<String> = paths.par_iter().enumerate()
        .map(|(index, path)| {
            match file_ops::read_and_check_file(path, show_outputs) {
                Ok(content) => {
                    let ext = std::path::Path::new(path).extension().and_then(|s| s.to_str()).unwrap_or("");
                    format!(
                        "<div id='file-{}' class='file-header' data-path='{}'>\n-------------------\n{} \n-------------------\n</div>\n<pre><code class='language-{}'>{}</code></pre>\n<hr/>\n", 
                        index,
                        html_escape::encode_double_quoted_attribute(path),
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
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![add_files, get_merged_content, exit_app])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
