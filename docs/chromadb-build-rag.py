import os
import argparse
import re
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

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
    Prevents function definitions from being split arbitrarily.
    """
    lines = text.split('\n')
    blocks = []
    current_block = []
    
    # Matches 'func ' or 'static func ' ignoring leading whitespace
    func_pattern = re.compile(r'^\s*(?:static\s+)?func\s+')
    
    # 1. Parse the script into semantic blocks
    for line in lines:
        if func_pattern.match(line):
            # If we hit a new function, save the previous block and start a new one
            if current_block:
                blocks.append('\n'.join(current_block))
            current_block = [line]
        else:
            current_block.append(line)
            
    # Append the final block
    if current_block:
        blocks.append('\n'.join(current_block))
        
    chunks = []
    current_chunk = ""
    
    # 2. Pack the semantic blocks into chunks
    for block in blocks:
        # If a single block (like a massive function) is larger than our chunk size limit
        if len(block) > chunk_size:
            # Flush the current chunk to the list before handling the massive block
            if current_chunk:
                chunks.append(current_chunk.strip())
                current_chunk = ""
            
            # Hard-chunk the massive block using standard overlap
            start = 0
            block_length = len(block)
            while start < block_length:
                end = start + chunk_size
                chunks.append(block[start:end].strip())
                start += chunk_size - overlap
                
        # If adding this block to the current chunk exceeds the size limit
        elif len(current_chunk) + len(block) > chunk_size and current_chunk:
            chunks.append(current_chunk.strip())
            current_chunk = block
            
        # Otherwise, append the block to the current chunk
        else:
            current_chunk = (current_chunk + "\n" + block).strip() if current_chunk else block

    # Append any remaining packed data
    if current_chunk:
        chunks.append(current_chunk.strip())
        
    # Remove any empty chunks that might have snuck through
    return [c for c in chunks if c.strip()]

def process_repository(repo_path, extensions, chunk_size, overlap):
    """Reads and chunks files, explicitly excluding our local RAG data folders."""
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

                    # Route to the smart chunker
                    if file.endswith('.gd'):
                        chunks = chunk_gdscript(content, chunk_size, overlap)
                    else:
                        chunks = chunk_text(content, chunk_size, overlap)

                    for i, chunk in enumerate(chunks):
                        documents.append(chunk)
                        metadatas.append({
                            "source": file_path, 
                            "filename": file,
                            "chunk_index": i
                        })
                        ids.append(f"doc_{chunk_counter}")
                        chunk_counter += 1
                        
                except Exception as e:
                    print(f"Skipping {file_path} due to read error: {e}")

    return documents, metadatas, ids

def main():
    parser = argparse.ArgumentParser(description="Prepare local knowledge bases for RAG.")
    parser.add_argument("--repo-path", type=str, required=True, help="Path to the files to embed")
    parser.add_argument("--db-type", choices=['main', 'godot'], default='main', help="Type of DB to build")
    
    # Defaults to docs/llm-rag-chromadb/{main, godot}
    base_db_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-chromadb")
    
    parser.add_argument("--host", type=str, default="http://localhost:1234/v1", help="LMStudio local server URL")
    parser.add_argument("--chunk-size", type=int, default=1000, help="Max characters per chunk")
    parser.add_argument("--chunk-overlap", type=int, default=200, help="Overlap for chunks")
    
    args = parser.parse_args()

    # Define settings per database type
    configs = {
        'main': {'ext': ['.gd', '.tres', '.tscn', '.md'], 'coll': 'repo_knowledgebase', 'path': os.path.join(base_db_dir, 'main')},
        'godot': {'ext': ['.rst'], 'coll': 'godot_docs', 'path': os.path.join(base_db_dir, 'godot')}
    }
    
    cfg = configs[args.db_type]
    
    print(f"Scanning {args.repo_path} for {cfg['ext']}...")
    documents, metadatas, ids = process_repository(args.repo_path, cfg['ext'], args.chunk_size, args.chunk_overlap)
    
    if not documents:
        print("No matching files found or read. Exiting.")
        return

    print(f"Found {len(documents)} chunks to embed for {args.db_type} database.")

    embedding_func = OpenAIEmbeddingFunction(
        api_key="lm-studio",
        api_base=args.host,
        model_name="text-embedding-qwen3-embedding-0.6b"
    )

    chroma_client = chromadb.PersistentClient(path=cfg['path'])
    
    collection = chroma_client.get_or_create_collection(
        name=cfg['coll'],
        embedding_function=embedding_func
    )

    print(f"Adding chunks to {cfg['coll']} collection...")
    
    batch_size = 25
    for i in range(0, len(documents), batch_size):
        end_idx = min(i + batch_size, len(documents))
        collection.add(
            documents=documents[i:end_idx],
            metadatas=metadatas[i:end_idx],
            ids=ids[i:end_idx]
        )
        print(f"Processed batch {i} to {end_idx}...")

    print(f"Success! {args.db_type} database saved to {cfg['path']}.")

if __name__ == "__main__":
    main()