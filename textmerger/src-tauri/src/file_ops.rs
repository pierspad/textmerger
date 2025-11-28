use std::fs;
use std::path::Path;
use content_inspector::{inspect, ContentType};

use serde_json::Value;
use std::io::Read;
use nom_exif::{MediaParser, MediaSource};
use mime_guess::from_path;
use image::io::Reader as ImageReader;

pub fn read_and_check_file(path: &str, show_outputs: bool) -> Result<String, String> {
    let path_obj = Path::new(path);
    
    if !path_obj.exists() {
        return Err(format!("File not found: {}", path));
    }

    if path_obj.is_dir() {
        return Err(format!("Is a directory: {}", path));
    }
    let ext = path_obj.extension().and_then(|s| s.to_str()).unwrap_or("").to_lowercase();

    if ext == "pdf" {
        return read_pdf(path);
    }

    if ext == "ipynb" {
        return read_ipynb(path, show_outputs);
    }

    // Check for media files (video/image)
    let media_extensions = ["jpg", "jpeg", "png", "gif", "bmp", "webp", "mp4", "mov", "avi", "mkv", "webm", "m4v", "3gp"];
    if media_extensions.contains(&ext.as_str()) {
        return read_metadata(path);
    }

    let mut file = fs::File::open(path).map_err(|e| e.to_string())?;
    let mut buffer = [0; 1024];
    let n = file.read(&mut buffer).unwrap_or(0);
    
    if n == 0 {
        return Ok(String::new());
    }

    if inspect(&buffer[..n]) == ContentType::BINARY {
        return Err(format!("Binary file detected: {}", path));
    }
    let metadata = fs::metadata(path).map_err(|e| e.to_string())?;
    if metadata.len() > 10 * 1024 * 1024 {
        return Err(format!("File too large (>10MB): {}", path));
    }

    fs::read_to_string(path).map_err(|e| e.to_string())
}

fn read_metadata(path: &str) -> Result<String, String> {
    let path_obj = Path::new(path);
    let filename = path_obj.file_name().unwrap_or_default().to_string_lossy();
    let metadata_fs = fs::metadata(path).map_err(|e| e.to_string())?;
    let size = metadata_fs.len();
    let mime_type = from_path(path).first_or_octet_stream().to_string();
    
    let mut output = String::new();
    
    output.push_str("-------------------\n");
    output.push_str(&format!("{}\n", path));
    output.push_str("-------------------\n");
    output.push_str(&format!("Name: {} | Size: {} bytes | Type: {}\n", filename, size, mime_type));
    output.push_str("-------------------\n\n");
    
    output.push_str("Metadata:\n");
    
    // Optimize: Read only dimensions without loading the full image
    if let Ok(reader) = ImageReader::open(path) {
        if let Ok(dims) = reader.into_dimensions() {
             output.push_str(&format!("Dimensions: {}x{}\n", dims.0, dims.1));
        }
    }

    let mut parser = MediaParser::new();
    if let Ok(ms) = MediaSource::file_path(path) {
        let iter: Result<nom_exif::ExifIter, _> = parser.parse(ms);
        if let Ok(iter) = iter {
            for entry in iter {
                let tag_str = entry.tag().map(|t| t.to_string()).unwrap_or_else(|| "Unknown".to_string());
                let value = entry.get_value().map(|v| v.to_string()).unwrap_or("".to_string());
                
                match tag_str.as_str() {
                    "Duration" | "ImageWidth" | "ImageHeight" | "Make" | "Model" | "CreateDate" | "FrameRate" | "BitRate" => {
                         output.push_str(&format!("{}: {}\n", tag_str, value));
                    }
                    _ => {}
                }
            }
        }
    }
    
    Ok(output)
}

fn read_pdf(path: &str) -> Result<String, String> {
    pdf_extract::extract_text(path).map_err(|e| e.to_string())
}

fn read_ipynb(path: &str, show_outputs: bool) -> Result<String, String> {
    let content = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let json: Value = serde_json::from_str(&content).map_err(|e| e.to_string())?;
    
    let mut output = String::new();
    
    if let Some(cells) = json["cells"].as_array() {
        for (i, cell) in cells.iter().enumerate() {
            let cell_type = cell["cell_type"].as_str().unwrap_or("unknown");
            let source = cell["source"].as_array();
            
            output.push_str("-------------------\n");
            output.push_str(&format!("Begin Cell {} - {}\n", i + 1, cell_type.to_uppercase()));
            
            if let Some(lines) = source {
                for line in lines {
                    if let Some(l) = line.as_str() {
                        output.push_str(l);
                    }
                }
                if !output.ends_with('\n') {
                    output.push('\n');
                }
            }

            if show_outputs {
                if let Some(outputs) = cell["outputs"].as_array() {
                    if !outputs.is_empty() {
                        output.push_str("\nCell Outputs:\n");
                        for out in outputs {
                            if let Some(text) = out["text"].as_array() {
                                for line in text {
                                    if let Some(l) = line.as_str() {
                                        output.push_str(l);
                                    }
                                }
                            } else if let Some(data) = out.get("data") {
                                if let Some(text_plain) = data.get("text/plain") {
                                    if let Some(lines) = text_plain.as_array() {
                                        for line in lines {
                                            if let Some(l) = line.as_str() {
                                                output.push_str(l);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if !output.ends_with('\n') {
                            output.push('\n');
                        }
                    }
                }
            }

            output.push_str(&format!("End Cell {} - {}\n", i + 1, cell_type.to_uppercase()));
            output.push_str("-------------------\n\n");
        }
    }
    
    Ok(output)
}
