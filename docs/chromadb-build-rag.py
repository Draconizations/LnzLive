import os
import argparse
import re
import json
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

def load_config():
    config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rag_config.json")
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            return json.load(f)
    return { # Fallbacks
        "host": "http://localhost:1234/v1",
        "embedding_model": "text-embedding-qwen3-embedding-0.6b",
        "chunk_size": 1000,
        "chunk_overlap": 200
    }

def chunk_text(text, chunk_size, overlap):
    """Standard overlapping chunker for markdown, generic text, and serialized data."""
    chunks = []
    start = 0
    text_length = len(text)
    
    while start < text_length:
        end = start + chunk_size
        chunks.append(text[start:end])
        start += chunk_size - overlap
        
    return chunks

def chunk_gdscript(text, chunk_size, overlap):
    """
    Smart chunking for GDScript. 
    Groups file into the preamble (variables, signals) and isolated functions.
    """
    lines = text.split('\n')
    blocks = []
    current_block = []
    
    func_pattern = re.compile(r'^\s*(?:static\s+)?func\s+')
    
    for line in lines:
        if func_pattern.match(line):
            if current_block:
                blocks.append('\n'.join(current_block))
            current_block = [line]
        else:
            current_block.append(line)
            
    if current_block:
        blocks.append('\n'.join(current_block))
        
    chunks = []
    current_chunk = ""
    
    for block in blocks:
        if len(block) > chunk_size:
            if current_chunk:
                chunks.append(current_chunk.strip())
                current_chunk = ""
            start = 0
            block_length = len(block)
            while start < block_length:
                end = start + chunk_size
                chunks.append(block[start:end].strip())
                start += chunk_size - overlap
        elif len(current_chunk) + len(block) > chunk_size and current_chunk:
            chunks.append(current_chunk.strip())
            current_chunk = block
        else:
            current_chunk = (current_chunk + "\n" + block).strip() if current_chunk else block

    if current_chunk:
        chunks.append(current_chunk.strip())
        
    return [c for c in chunks if c.strip()]

def process_repository(repo_path, extensions, chunk_size, overlap):
    documents = []
    metadatas = []
    ids = []
    exclude_dirs = {'llm-rag-chromadb', 'llm-rag-sessions', 'chroma_db'}
    chunk_counter = 0 

    for root, dirs, files in os.walk(repo_path):
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        for file in files:
            if any(file.endswith(ext) for ext in extensions):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()

                    chunks = chunk_gdscript(content, chunk_size, overlap) if file.endswith('.gd') else chunk_text(content, chunk_size, overlap)

                    for i, chunk in enumerate(chunks):
                        documents.append(chunk)
                        metadatas.append({"source": file_path, "filename": file, "chunk_index": i})
                        ids.append(f"doc_{chunk_counter}_{file}")
                        chunk_counter += 1
                        
                except Exception as e:
                    print(f"Skipping {file_path}: {e}")

    return documents, metadatas, ids

def main():
    config = load_config()
    parser = argparse.ArgumentParser(description="Prepare local knowledge bases for RAG.")
    parser.add_argument("--repo-path", type=str, required=True, help="Path to the files to embed")
    parser.add_argument("--db-type", choices=['main', 'godot'], default='main', help="Type of DB to build")
    args = parser.parse_args()

    base_db_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-chromadb")
    
    configs = {
        'main': {'ext': ['.gd', '.tres', '.tscn', '.md'], 'coll': 'repo_knowledgebase', 'path': os.path.join(base_db_dir, 'main')},
        'godot': {'ext': ['.rst'], 'coll': 'godot_docs', 'path': os.path.join(base_db_dir, 'godot')}
    }
    cfg = configs[args.db_type]
    
    print(f"Scanning {args.repo_path} for {cfg['ext']}...")
    documents, metadatas, ids = process_repository(args.repo_path, cfg['ext'], config["chunk_size"], config["chunk_overlap"])
    
    if not documents:
        print("No files found or read. Exiting.")
        return

    print(f"Found {len(documents)} chunks. Building database...")

    embedding_func = OpenAIEmbeddingFunction(
        api_key="lm-studio",
        api_base=config["host"],
        model_name=config["embedding_model"]
    )

    chroma_client = chromadb.PersistentClient(path=cfg['path'])
    collection = chroma_client.get_or_create_collection(name=cfg['coll'], embedding_function=embedding_func)

    batch_size = 50
    for i in range(0, len(documents), batch_size):
        end_idx = min(i + batch_size, len(documents))
        collection.add(
            documents=documents[i:end_idx],
            metadatas=metadatas[i:end_idx],
            ids=ids[i:end_idx]
        )
    print(f"Success! Database saved to {cfg['path']}.")

if __name__ == "__main__":
    main()