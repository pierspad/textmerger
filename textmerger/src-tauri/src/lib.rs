use glob::Pattern;
use rayon::iter::Either;
use rayon::prelude::*;
use std::borrow::Cow;
use std::collections::HashSet;
use std::path::Path;

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
        let exclude = excluded_patterns
            .iter()
            .filter_map(|p| Pattern::new(p).ok())
            .collect();
        let hide = hidden_patterns
            .iter()
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

fn escape_html(input: &str) -> Cow<'_, str> {
    if !input.contains(['<', '>', '&', '"', '\'']) {
        return Cow::Borrowed(input);
    }
    let mut output = String::with_capacity(input.len() + 16);
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
    Cow::Owned(output)
}

fn collect_directory_files(path: &str, recursive: bool, filter: &FilterPatterns) -> Vec<String> {
    let mut files = Vec::new();
    let path_obj = Path::new(path);

    if !path_obj.is_dir() {
        return files;
    }

    if recursive {
        let walker = walkdir::WalkDir::new(path).into_iter();
        for entry in walker
            .filter_entry(|e| {
                let name = e.file_name().to_str().unwrap_or_default();
                !filter.is_excluded(name) && !name.starts_with('.')
            })
            .filter_map(|e| e.ok())
        {
            if entry.file_type().is_file() {
                if let Some(path_str) = entry.path().to_str() {
                    files.push(path_str.to_string());
                }
            }
        }
    } else if let Ok(entries) = std::fs::read_dir(path) {
        for entry in entries.filter_map(|e| e.ok()) {
            let name = entry.file_name().to_str().unwrap_or_default().to_string();
            let is_file = entry.file_type().map_or(false, |ft| ft.is_file());
            if is_file && !filter.is_excluded(&name) && !name.starts_with('.') {
                if let Some(path_str) = entry.path().to_str() {
                    files.push(path_str.to_string());
                }
            }
        }
    }
    files
}

fn process_paths_parallel(paths: Vec<String>, filter: &FilterPatterns) -> AddFilesResult {
    let (files, errors): (Vec<FileNode>, Vec<String>) = paths
        .into_par_iter()
        .map(|path| match file_ops::read_and_check_file(&path, "none") {
            Ok((content, size_bytes)) => {
                let path_obj = Path::new(&path);
                let name = path_obj
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .into_owned();
                let extension = path_obj
                    .extension()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .into_owned();

                Ok(FileNode {
                    path,
                    hidden: filter.is_hidden(&name),
                    name,
                    char_count: content.chars().count(),
                    size_bytes,
                    extension,
                })
            }
            Err(e) => Err(e),
        })
        .partition_map(|res| match res {
            Ok(node) => Either::Left(node),
            Err(e) => Either::Right(e),
        });

    AddFilesResult { files, errors }
}

#[tauri::command]
fn add_files(
    paths: Vec<String>,
    excluded_patterns: Vec<String>,
    hidden_patterns: Vec<String>,
) -> Result<AddFilesResult, String> {
    let filter = FilterPatterns::new(&excluded_patterns, &hidden_patterns);
    let all_paths: Vec<String> = paths
        .into_par_iter()
        .flat_map(|path| {
            let path_obj = Path::new(&path);
            if path_obj.is_dir() {
                collect_directory_files(&path, true, &filter)
            } else {
                let name = path_obj.file_name().and_then(|n| n.to_str()).unwrap_or_default();
                if !filter.is_excluded(name) {
                    vec![path]
                } else {
                    Vec::new()
                }
            }
        })
        .collect();

    Ok(process_paths_parallel(all_paths, &filter))
}

#[tauri::command]
fn scan_directory(
    path: String,
    recursive: bool,
    excluded_patterns: Vec<String>,
    hidden_patterns: Vec<String>,
) -> Result<AddFilesResult, String> {
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
    large_file_threshold: usize,
    hidden_placeholder: String,
) -> Result<String, String> {
    let hidden_set: HashSet<&str> = hidden_paths.iter().map(|s| s.as_str()).collect();
    let force_set: HashSet<&str> = force_full_load_paths.iter().map(|s| s.as_str()).collect();

    let contents: Vec<String> = paths
        .par_iter()
        .enumerate()
        .map(|(index, path)| {
            let path_str = path.as_str();

            if hidden_set.contains(path_str) {
                return format!(
                    "<div id=\"file-{index}\" class=\"file-header\" data-path=\"{}\">\n-------------------\n{path_str} \n-------------------\n</div>\n<pre><code>{hidden_placeholder}</code></pre>\n<hr/>\n",
                    escape_html(path_str),
                );
            }

            match file_ops::read_and_check_file(path, &ipynb_output_mode) {
                Ok((mut content, _size)) => {
                    let ext = std::path::Path::new(path)
                        .extension()
                        .and_then(|s| s.to_str())
                        .unwrap_or_default();
                    // Count chars (not bytes) for consistency with the frontend
                    let char_count = content.chars().count();
                    let mut is_truncated = false;

                    let is_forced = force_set.contains(path_str)
                        || force_set.iter().any(|&p| {
                            path_str.strip_prefix(p).map_or(false, |rest| {
                                rest.starts_with('/') || rest.starts_with('\\')
                            })
                        });

                    if !load_full_large_files && char_count > large_file_threshold && !is_forced {
                        // Truncate at the Nth character (not byte) boundary
                        let end = content
                            .char_indices()
                            .nth(large_file_threshold)
                            .map(|(i, _)| i)
                            .unwrap_or(content.len());
                        content.truncate(end);
                        content.push_str(
                            "\n\n[... The rest of the file was truncated due to its length ...]",
                        );
                        is_truncated = true;
                    }

                    format!(
                        "<div id=\"file-{index}\" class=\"file-header\" data-path=\"{}\" data-truncated=\"{is_truncated}\">\n-------------------\n{path_str} \n-------------------\n</div>\n<pre><code class=\"language-{ext}\">{}</code></pre>\n<hr/>\n",
                        escape_html(path_str),
                        escape_html(&content)
                    )
                }
                Err(e) => format!(
                    "<div class=\"error\">Error reading {}: {}</div>",
                    escape_html(path),
                    escape_html(&e)
                ),
            }
        })
        .collect();

    let total_len: usize = contents.iter().map(|s| s.len() + 1).sum();
    let mut result = String::with_capacity(total_len);
    for (i, s) in contents.into_iter().enumerate() {
        if i > 0 {
            result.push('\n');
        }
        result.push_str(&s);
    }

    Ok(result)
}


#[tauri::command]
fn get_file_content(path: String, ipynb_output_mode: String) -> Result<String, String> {
    match file_ops::read_and_check_file(&path, &ipynb_output_mode) {
        Ok((content, _size)) => Ok(content),
        Err(e) => Err(e),
    }
}

#[tauri::command]
fn exit_app() {
    std::process::exit(0);
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    #[cfg(target_os = "linux")]
    {
        // SAFETY: WEBKIT_DISABLE_DMABUF_RENDERER is set during startup before GTK thread initialization.
        unsafe {
            std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        }
    }


    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_log::Builder::default().build())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            add_files,
            get_merged_content,
            scan_directory,
            exit_app,
            get_file_content
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

