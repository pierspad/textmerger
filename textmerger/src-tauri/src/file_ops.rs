use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::path::Path;
use std::sync::{LazyLock, Mutex};
use std::time::SystemTime;

use content_inspector::{ContentType, inspect};
use image::io::Reader as ImageReader;
use mime_guess::from_path;
use nom_exif::{MediaParser, MediaSource};
use serde_json::Value;

const MAX_FILE_SIZE: u64 = 10 * 1024 * 1024; // 10MB limit

const MEDIA_EXTENSIONS: &[&str] = &[
    "jpg", "jpeg", "png", "gif", "bmp", "webp", "mp4", "mov", "avi", "mkv", "webm", "m4v", "3gp",
];

// PDF text extraction is CPU-expensive and get_merged_content re-reads every
// file on each refresh: cache extracted text keyed by path, invalidated by (mtime, size).
static PDF_CACHE: LazyLock<Mutex<HashMap<String, (SystemTime, u64, String)>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub fn read_and_check_file(path: &str, output_mode: &str) -> Result<(String, u64), String> {
    let path_obj = Path::new(path);
    let ext = path_obj
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_lowercase();

    match ext.as_str() {
        "pdf" => return read_pdf(path),
        "ipynb" => return read_ipynb(path, output_mode),
        e if MEDIA_EXTENSIONS.contains(&e) => return read_metadata(path),
        _ => {}
    }

    let mut file = fs::File::open(path).map_err(|e| format!("Could not open file: {e}"))?;
    let metadata = file
        .metadata()
        .map_err(|e| format!("Could not read metadata: {e}"))?;

    if metadata.is_dir() {
        return Err(format!("Is a directory: {path}"));
    }

    let size = metadata.len();
    if size > MAX_FILE_SIZE {
        return Err(format!("File too large (>10MB): {path}"));
    }

    // Inspect first 1024 bytes on the stack without heap allocation
    let mut header = [0u8; 1024];
    let n = file
        .read(&mut header)
        .map_err(|e| format!("Error reading header: {e}"))?;

    if n == 0 {
        return Ok((String::new(), 0));
    }

    let encoding = inspect(&header[..n]);
    if encoding == ContentType::BINARY {
        return Err(format!("Binary file detected: {path}"));
    }

    let mut buffer = Vec::with_capacity(size as usize);
    buffer.extend_from_slice(&header[..n]);
    file.read_to_end(&mut buffer)
        .map_err(|e| format!("Error reading content: {e}"))?;

    let content = decode_text(buffer, encoding)?;

    Ok((content, size))
}

fn decode_text(buffer: Vec<u8>, encoding: ContentType) -> Result<String, String> {
    match encoding {
        ContentType::UTF_16LE | ContentType::UTF_16BE => {
            // content_inspector identifies UTF-16 by its BOM. Reject incomplete
            // code units and invalid surrogate pairs instead of replacing text.
            let bytes = &buffer[2..];
            if bytes.len() % 2 != 0 {
                return Err("File contains incomplete UTF-16 code unit".to_string());
            }
            let units = bytes.chunks_exact(2).map(|pair| {
                let pair = [pair[0], pair[1]];
                if encoding == ContentType::UTF_16LE {
                    u16::from_le_bytes(pair)
                } else {
                    u16::from_be_bytes(pair)
                }
            });
            char::decode_utf16(units)
                .collect::<Result<String, _>>()
                .map_err(|e| format!("File contains invalid UTF-16: {e}"))
        }
        _ => String::from_utf8(buffer).map_err(|e| format!("File contains invalid UTF-8: {e}")),
    }
}

// Notebook multiline fields may be one string or an array of strings.
fn append_notebook_text(output: &mut String, value: &Value) {
    if let Some(text) = value.as_str() {
        output.push_str(text);
    } else if let Some(lines) = value.as_array() {
        for line in lines {
            if let Some(text) = line.as_str() {
                output.push_str(text);
            }
        }
    }
}

fn read_metadata(path: &str) -> Result<(String, u64), String> {
    let path_obj = Path::new(path);
    let filename = path_obj.file_name().unwrap_or_default().to_string_lossy();
    let metadata_fs = fs::metadata(path).map_err(|e| e.to_string())?;
    let size = metadata_fs.len();
    let mime_type = from_path(path).first_or_octet_stream().to_string();

    let mut output = String::with_capacity(512);

    output.push_str("-------------------\n");
    output.push_str(path);
    output.push('\n');
    output.push_str("-------------------\n");
    output.push_str(&format!(
        "Name: {filename} | Size: {size} bytes | Type: {mime_type}\n"
    ));
    output.push_str("-------------------\n\n");
    output.push_str("Metadata:\n");

    if let Ok(reader) = ImageReader::open(path) {
        if let Ok(dims) = reader.into_dimensions() {
            output.push_str(&format!("Dimensions: {}x{}\n", dims.0, dims.1));
        }
    }

    let Ok(ms) = MediaSource::file_path(path) else {
        return Ok((output, size));
    };

    let mut parser = MediaParser::new();
    let iter: Result<nom_exif::ExifIter, _> = parser.parse(ms);
    if let Ok(iter) = iter {
        for entry in iter {
            let tag_str = entry
                .tag()
                .map(|t| t.to_string())
                .unwrap_or_else(|| "Unknown".to_string());
            let value = entry.get_value().map(|v| v.to_string()).unwrap_or_default();

            match tag_str.as_str() {
                "Duration" | "ImageWidth" | "ImageHeight" | "Make" | "Model" | "CreateDate"
                | "FrameRate" | "BitRate" => {
                    output.push_str(&format!("{tag_str}: {value}\n"));
                }
                _ => {}
            }
        }
    }

    Ok((output, size))
}

fn read_pdf(path: &str) -> Result<(String, u64), String> {
    let meta = fs::metadata(path).map_err(|e| e.to_string())?;
    let size = meta.len();
    let mtime = meta.modified().unwrap_or(SystemTime::UNIX_EPOCH);

    if let Ok(map) = PDF_CACHE.lock() {
        if let Some((cached_mtime, cached_size, text)) = map.get(path) {
            if *cached_mtime == mtime && *cached_size == size {
                return Ok((text.clone(), size));
            }
        }
    }

    let text = pdf_extract::extract_text(path).map_err(|e| e.to_string())?;

    if let Ok(mut map) = PDF_CACHE.lock() {
        map.insert(path.to_string(), (mtime, size, text.clone()));
    }

    Ok((text, size))
}

fn read_ipynb(path: &str, output_mode: &str) -> Result<(String, u64), String> {
    let content = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let size = content.len() as u64;
    let json: Value = serde_json::from_str(&content).map_err(|e| e.to_string())?;

    let mut output = String::with_capacity(content.len());

    let Some(cells) = json["cells"].as_array() else {
        return Ok((output, size));
    };

    for (i, cell) in cells.iter().enumerate() {
        let cell_type = cell["cell_type"].as_str().unwrap_or("unknown");
        let source = &cell["source"];

        output.push_str("-------------------\n");
        output.push_str(&format!(
            "Begin Cell {} - {}\n",
            i + 1,
            cell_type.to_uppercase()
        ));

        append_notebook_text(&mut output, source);
        if !output.ends_with('\n') {
            output.push('\n');
        }

        if output_mode != "none" {
            if let Some(outputs) = cell["outputs"].as_array() {
                if !outputs.is_empty() {
                    output.push_str("\nCell Outputs:\n");
                    let mut output_text = String::new();
                    for out in outputs {
                        if let Some(text) = out.get("text") {
                            append_notebook_text(&mut output_text, text);
                        } else if let Some(text) =
                            out.get("data").and_then(|data| data.get("text/plain"))
                        {
                            append_notebook_text(&mut output_text, text);
                        }
                    }

                    if output_mode == "reduced" {
                        let mut line_iter = output_text.lines();
                        let first_10: Vec<&str> = line_iter.by_ref().take(10).collect();
                        if line_iter.next().is_some() {
                            for (idx, line) in first_10.iter().enumerate() {
                                if idx > 0 {
                                    output.push('\n');
                                }
                                output.push_str(line);
                            }
                            output.push_str("\n\n... [Output reduced] ...\n");
                        } else {
                            output.push_str(&output_text);
                        }
                    } else {
                        output.push_str(&output_text);
                    }

                    if !output.ends_with('\n') {
                        output.push('\n');
                    }
                }
            }
        }

        output.push_str(&format!(
            "End Cell {} - {}\n",
            i + 1,
            cell_type.to_uppercase()
        ));
        output.push_str("-------------------\n\n");
    }

    Ok((output, size))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

    static NEXT_FILE: AtomicU64 = AtomicU64::new(0);
    struct Fixture(PathBuf);
    impl Fixture {
        fn new(ext: &str, bytes: &[u8]) -> Self {
            let path = std::env::temp_dir().join(format!(
                "textmerger-test-{}-{}.{}",
                std::process::id(),
                NEXT_FILE.fetch_add(1, Ordering::Relaxed),
                ext
            ));
            let mut file = fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&path)
                .unwrap();
            file.write_all(bytes).unwrap();
            Self(path)
        }
        fn read(&self, mode: &str) -> Result<(String, u64), String> {
            read_and_check_file(self.0.to_str().unwrap(), mode)
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_file(&self.0);
        }
    }

    #[test]
    fn utf16_both_byte_orders_preserve_unicode_and_byte_size() {
        let expected = "Hello, caffè — 日本語 🦀\n";
        for little_endian in [true, false] {
            let mut bytes = if little_endian {
                vec![0xff, 0xfe]
            } else {
                vec![0xfe, 0xff]
            };
            for unit in expected.encode_utf16() {
                bytes.extend_from_slice(&if little_endian {
                    unit.to_le_bytes()
                } else {
                    unit.to_be_bytes()
                });
            }
            assert_eq!(
                Fixture::new("txt", &bytes).read("none").unwrap(),
                (expected.to_string(), bytes.len() as u64)
            );
        }
    }
    #[test]
    fn malformed_utf16_is_rejected() {
        for bytes in [&[0xff, 0xfe, 0x41][..], &[0xfe, 0xff, 0xd8, 0x00][..]] {
            assert!(
                Fixture::new("txt", bytes)
                    .read("none")
                    .unwrap_err()
                    .contains("UTF-16")
            );
        }
    }
    #[test]
    fn plain_text_and_binary_behavior_is_preserved() {
        let text = "Plain UTF-8: caffè 🦀\n";
        assert_eq!(
            Fixture::new("unknown", text.as_bytes())
                .read("none")
                .unwrap()
                .0,
            text
        );
        assert!(
            Fixture::new("bin", &[0, 1, 2, 0, 255])
                .read("none")
                .is_err()
        );
        assert!(
            Fixture::new("txt", &[0x80, 0x81, 0x82])
                .read("none")
                .is_err()
        );
        assert_eq!(
            Fixture::new("txt", &[]).read("none").unwrap(),
            (String::new(), 0)
        );
    }
    #[test]
    fn notebook_string_and_array_fields_produce_identical_output() {
        let variants = [
            serde_json::json!({"cells": [{"cell_type": "code", "source": "print(1)\n", "outputs": [
                {"text": "stream\n"}, {"data": {"text/plain": "result\n"}}]}]}),
            serde_json::json!({"cells": [{"cell_type": "code", "source": ["print(1)\n"], "outputs": [
                {"text": ["stream\n"]}, {"data": {"text/plain": ["result\n"]}}]}]}),
        ];
        let files: Vec<_> = variants
            .iter()
            .map(|v| Fixture::new("ipynb", v.to_string().as_bytes()))
            .collect();
        for mode in ["none", "reduced", "full"] {
            let output = files[0].read(mode).unwrap().0;
            assert_eq!(output, files[1].read(mode).unwrap().0);
            assert!(output.contains("print(1)"));
            assert_eq!(output.contains("stream\nresult"), mode != "none");
        }
    }
    #[test]
    fn reduced_notebook_output_keeps_ten_lines() {
        let lines: String = (1..=12).map(|i| format!("line {i}\n")).collect();
        let json = serde_json::json!({"cells": [{"cell_type": "code", "source": [], "outputs": [{"text": lines}]}]});
        let file = Fixture::new("ipynb", json.to_string().as_bytes());
        let reduced = file.read("reduced").unwrap().0;
        assert!(reduced.contains("line 10\n"));
        assert!(!reduced.contains("line 11"));
        assert!(reduced.contains("[Output reduced]"));
        let full = file.read("full").unwrap().0;
        assert!(full.contains("line 12"));
        assert!(!full.contains("[Output reduced]"));
    }
}
