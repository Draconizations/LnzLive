import os
import argparse
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

def chunk_text(text, chunk_size=1000, overlap=200):
    """Splits text into overlapping chunks to maintain context."""
    chunks = []
    start = 0
    text_length = len(text)
    
    while start < text_length:
        end = start + chunk_size
        chunks.append(text[start:end])
        start += chunk_size - overlap
        
    return chunks

def process_repository(repo_path, extensions):
    """Reads and chunks files matching the given extensions."""
    documents = []
    metadatas = []
    ids = []
    
    chunk_counter = 0 

    for root, _, files in os.walk(repo_path):
        for file in files:
            if any(file.endswith(ext) for ext in extensions):
                file_path = os.path.join(root, file)
                
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()

                    chunks = chunk_text(content)

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
    parser = argparse.ArgumentParser(description="Prepare a local GitHub repo for RAG using ChromaDB and LMStudio.")
    parser.add_argument("--repo-path", type=str, required=True, help="Path to the cloned GitHub repository")
    
    # Dynamically sets the default path to be docs/chroma_db relative to where this script lives
    default_db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chroma_db")
    parser.add_argument("--db-path", type=str, default=default_db_path, help="Folder to save the ChromaDB database")
    
    parser.add_argument("--collection", type=str, default="repo_knowledgebase", help="Name of the ChromaDB collection")
    parser.add_argument("--host", type=str, default="http://localhost:1234/v1", help="LMStudio local server URL")
    
    args = parser.parse_args()

    target_extensions = ['.gd', '.tres', '.tscn', '.md']
    
    print(f"Scanning {args.repo_path} for {target_extensions}...")
    documents, metadatas, ids = process_repository(args.repo_path, target_extensions)
    
    if not documents:
        print("No matching files found or read. Exiting.")
        return

    print(f"Found {len(documents)} chunks to embed.")

    embedding_func = OpenAIEmbeddingFunction(
        api_key="lm-studio",
        api_base="http://localhost:1234/v1",
        model_name="text-embedding-qwen3-embedding-0.6b"
    )

    chroma_client = chromadb.PersistentClient(path=args.db_path)
    
    collection = chroma_client.get_or_create_collection(
        name=args.collection,
        embedding_function=embedding_func
    )

    print("Adding chunks to ChromaDB (this may take a while depending on your hardware)...")
    
    batch_size = 25
    for i in range(0, len(documents), batch_size):
        end_idx = min(i + batch_size, len(documents))
        collection.add(
            documents=documents[i:end_idx],
            metadatas=metadatas[i:end_idx],
            ids=ids[i:end_idx]
        )
        print(f"Processed batch {i} to {end_idx}...")

    print(f"Success! Database saved to {args.db_path}.")

if __name__ == "__main__":
    main()