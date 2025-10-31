import os
import mimetypes
import concurrent.futures
import json

try:
    from PyPDF2 import PdfReader
    PYPDF2_AVAILABLE = True
except ImportError:
    PYPDF2_AVAILABLE = False

DASH_LINE = "-------------------"


def get_supported_formats():
    formats = {
        'Programming': ['.py', '.java', '.cs', '.cpp', '.c', '.go', '.rs', '.rb',
                        '.php', '.swift', '.kt', '.scala', '.groovy', '.lua', '.pl', '.r'],
        'Web & Scripting': ['.html', '.htm', '.css', '.scss', '.sass', '.less',
                            '.js', '.jsx', '.ts', '.tsx', '.vue'],
        'Markup & Config': ['.xml', '.yaml', '.yml', '.json', '.toml', '.ini',
                            '.md', '.rst', '.tex', '.csv', '.sql', '.gitignore',
                            '.dockerignore', '.env', '.conf'],
        'Project Files': ['.gradle', '.maven', '.pom', '.project',
                          '.eslintrc', '.prettierrc', '.babelrc'],
        'Special Formats': ['.ipynb', '.pdf', '.rtf', '.log', '.txt']
    }
    return formats


def _get_metadata(path, mime_type):
    return {
        'name': os.path.basename(path),
        'size': os.path.getsize(path),
        'type': mime_type
    }


def _read_notebook_content(path):
    """Read Jupyter Notebook (.ipynb) files by parsing the JSON structure directly."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            notebook = json.load(f)
        
        # Validate that it's a Jupyter Notebook
        if not isinstance(notebook, dict) or 'cells' not in notebook:
            return "# Error: Invalid Jupyter Notebook format\n# The file does not contain the expected notebook structure"
        
        lines = []
        cell_num = 1
        
        for cell in notebook.get('cells', []):
            if not isinstance(cell, dict):
                continue
                
            cell_type = cell.get('cell_type', 'unknown')
            tipo_label = "CODE" if cell_type == "code" else cell_type.upper()
            
            lines.append(f"{DASH_LINE}\nBegin Cell {cell_num} - {tipo_label}")
            
            # Get cell source (can be a string or list of strings)
            source = cell.get('source', '')
            if isinstance(source, list):
                source = ''.join(source)
            elif not isinstance(source, str):
                source = str(source)
            
            lines.append(source)
            
            # For code cells, optionally show outputs
            if cell_type == "code" and cell.get('outputs'):
                outputs = cell.get('outputs', [])
                if outputs:
                    lines.append(f"\n{DASH_LINE}\nCell Outputs:")
                    for output in outputs:
                        if isinstance(output, dict):
                            # Handle different output types
                            output_type = output.get('output_type', '')
                            
                            if output_type == 'stream':
                                text = output.get('text', '')
                                if isinstance(text, list):
                                    text = ''.join(text)
                                lines.append(f"[Stream Output]\n{text}")
                            
                            elif output_type in ('execute_result', 'display_data'):
                                data = output.get('data', {})
                                if 'text/plain' in data:
                                    plain_text = data['text/plain']
                                    if isinstance(plain_text, list):
                                        plain_text = ''.join(plain_text)
                                    lines.append(f"[Result]\n{plain_text}")
                            
                            elif output_type == 'error':
                                ename = output.get('ename', 'Error')
                                evalue = output.get('evalue', '')
                                lines.append(f"[Error] {ename}: {evalue}")
            
            lines.append(f"End Cell {cell_num} - {tipo_label}\n{DASH_LINE}")
            cell_num += 1
        
        if cell_num == 1:
            return "# Empty Jupyter Notebook\n# No cells found in this notebook"
        
        return "\n".join(lines)
        
    except json.JSONDecodeError as e:
        return f"# Error: Invalid JSON format\n# {str(e)}\n# The file may be corrupted or not a valid Jupyter Notebook"
    except Exception as e:
        return f"# Error reading Jupyter Notebook\n# {str(e)}\n# The file may be corrupted or in an incompatible format"


def _read_pdf_content(path):
    if not PYPDF2_AVAILABLE:
        return "# PDF support not available\n# Install PyPDF2: pip install PyPDF2"
    
    try:
        reader = PdfReader(path)
        lines = []
        for i, page in enumerate(reader.pages):
            lines.append(f"{DASH_LINE}\nBegin Page {i + 1}")
            extracted_text = page.extract_text()
            if extracted_text:
                lines.append(extracted_text)
            lines.append("\nPossible images on this page (placeholder).\n")
            lines.append(f"End Page {i + 1}\n{DASH_LINE}")
        return "\n".join(lines)
    except Exception as e:
        return f"# Error reading PDF file\n# {str(e)}\n# The file may be corrupted, encrypted, or in an incompatible format"


def _process_file(path):
    if os.path.isdir(path):
        return path, {'content': None, 'metadata': {'name': os.path.basename(path), 'size': 0, 'type': 'folder'}}

    ext = os.path.splitext(path)[1].lower()
    if ext == '.ipynb':
        content = _read_notebook_content(path)
        return path, {'content': content, 'metadata': _get_metadata(path, 'application/x-ipynb+json')}
    if ext == '.pdf':
        content = _read_pdf_content(path)
        return path, {'content': content, 'metadata': _get_metadata(path, 'application/pdf')}

    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        mime_type, _ = mimetypes.guess_type(path)
        return path, {
            'content': content,
            'metadata': _get_metadata(path, mime_type if mime_type else 'text/plain')
        }
    except (UnicodeDecodeError, IOError):
        mime_type, _ = mimetypes.guess_type(path)
        return path, {
            'content': None,
            'metadata': _get_metadata(path, mime_type if mime_type else 'non testuale')
        }


def load_files(file_paths):
    all_files = []
    for path in file_paths:
        if os.path.isdir(path):
            for root, dirs, filenames in os.walk(path):
                dirs[:] = [d for d in dirs if not (d.startswith('.') or d == '__pycache__')]
                filtered_files = [
                    os.path.join(root, f) for f in filenames
                    if not (f.startswith('.') or f.endswith('.pyc') or f == '.DS_Store')
                ]
                all_files.extend(filtered_files)
        else:
            all_files.append(path)

    all_files = list(dict.fromkeys(all_files))
    files_content = {}

    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as executor:
        for path, data in executor.map(_process_file, all_files):
            files_content[path] = data

    return files_content
