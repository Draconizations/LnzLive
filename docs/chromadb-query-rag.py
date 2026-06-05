import os
import datetime
import argparse
import requests
import json
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

def load_condensed_history(filepath):
    """Loads the CONDENSED history as a single string to inject into the system prompt."""
    if not os.path.exists(filepath):
        return ""
    
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
        
    blocks = content.split('\n---\n')
    summaries = []
    for block in blocks:
        if '### Condensed Interaction' in block:
            summary = block.replace('### Condensed Interaction', '').strip()
            if summary:
                summaries.append(summary)
                
    if not summaries:
        return ""
        
    # Combine the summaries into a single memory block
    combined = "\n".join(f"- {s}" for s in summaries[-3:]) # Keep the last 3 summaries
    return f"\n\n--- PREVIOUS SESSION MEMORY ---\n{combined}\n-------------------------------\n"

def query_llm(system_prompt, user_prompt, host, model_name):
    """Sends the RAG prompt to LM Studio and streams the output with robust error handling."""
    url = f"{host.rstrip('/')}/chat/completions"
    headers = {"Content-Type": "application/json"}
    
    # We now strictly send ONLY a System and a User message to keep Jinja templates happy
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ]
    
    data = {
        "model": model_name,
        "messages": messages,
        "temperature": 0.2, 
        "stream": True      
    }
    
    full_response = ""
    try:
        response = requests.post(url, headers=headers, json=data, stream=True)
        if response.status_code != 200:
            print(f"\nError from LLM Server: {response.text}")
            return ""

        print("\n--- Response ---")
        for line in response.iter_lines():
            if line:
                decoded_line = line.decode('utf-8').lstrip('data: ')
                if decoded_line.strip() == "[DONE]":
                    break
                try:
                    json_data = json.loads(decoded_line)
                    
                    if "error" in json_data:
                        print(f"\n\n[LM Studio Error]: {json_data['error']}")
                        break
                        
                    choices = json_data.get('choices', [])
                    if choices and 'delta' in choices[0]:
                        content = choices[0]['delta'].get('content', '')
                        print(content, end='', flush=True)
                        full_response += content 
                        
                except json.JSONDecodeError:
                    continue
                except Exception as ex:
                    print(f"\n[Parsing Error]: Unexpected format from server. Raw JSON: {json_data}")
                    break
                    
        print("\n----------------")
        return full_response
    except Exception as e:
        print(f"\nFailed to communicate with LLM server: {e}")
        return ""

def condense_interaction(user_query, full_response, host, model_name):
    """Makes a fast, background call to condense the interaction into a summary."""
    print("Condensing session memory in the background...")
    url = f"{host.rstrip('/')}/chat/completions"
    headers = {"Content-Type": "application/json"}
    
    system_prompt = (
        "You are a technical summarizer. Condense the following interaction into a single, dense paragraph. "
        "Keep ONLY the core architectural decisions, code patterns, specific file names mentioned, and functional logic. "
        "Remove all conversational filler, pleasantries, and redundant explanations."
    )
    
    interaction_text = f"USER ASKED: {user_query}\n\nASSISTANT ANSWERED: {full_response}"
    
    data = {
        "model": model_name,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": interaction_text}
        ],
        "temperature": 0.1, 
        "stream": False     
    }
    
    try:
        response = requests.post(url, headers=headers, json=data)
        if response.status_code == 200:
            return response.json()['choices'][0]['message']['content'].strip()
        return "Summary failed to generate."
    except Exception as e:
        print(f"Summarizer failed: {e}")
        return "Summary failed to generate."

def main():
    parser = argparse.ArgumentParser(description="Query your repository knowledgebase using local RAG.")
    parser.add_argument("--query", type=str, required=True, help="The question you want to ask your codebase")
    parser.add_argument("--session", type=str, default=None, help="Name or tag for the conversation session")
    default_db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chroma_db")
    parser.add_argument("--db-path", type=str, default=default_db_path, help="Folder where ChromaDB is saved")
    parser.add_argument("--collection", type=str, default="repo_knowledgebase", help="Name of your ChromaDB collection")
    parser.add_argument("--host", type=str, default="http://localhost:1234/v1", help="LMStudio local server URL")
    parser.add_argument("--num-results", type=int, default=4, help="Number of code snippets to retrieve")
    
    args = parser.parse_args()
    
    LLM_MODEL = "qwen/qwen3.6-35b-a3b"

    if not args.session:
        args.session = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        
    session_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chromadb-sessions")
    os.makedirs(session_dir, exist_ok=True)
    
    session_file_condensed = os.path.join(session_dir, f"{args.session}.md")
    session_file_full = os.path.join(session_dir, f"{args.session}.full.md")
    
    # Load history as a single string instead of a message list
    session_memory_string = load_condensed_history(session_file_condensed)
    if session_memory_string:
        print(f"Loaded condensed memories from {session_file_condensed}")
    else:
        print(f"Starting new dual-log session for '{args.session}'")

    embedding_func = OpenAIEmbeddingFunction(
        api_key="lm-studio",
        api_base=args.host,
        model_name="text-embedding-qwen3-embedding-0.6b" 
    )

    chroma_client = chromadb.PersistentClient(path=args.db_path)
    
    try:
        collection = chroma_client.get_collection(name=args.collection, embedding_function=embedding_func)
    except Exception as e:
        print(f"Could not find collection. Error: {e}")
        return

    print(f"Searching database for relevant code chunks...")
    results = collection.query(query_texts=[args.query], n_results=args.num_results)

    retrieved_docs = results['documents'][0]
    retrieved_metadata = results['metadatas'][0]
    context_str = ""

    if retrieved_docs:
        print("\nFound relevant snippets in:")
        for doc, meta in zip(retrieved_docs, retrieved_metadata):
            source_file = meta.get('source', 'Unknown File')
            print(f" - {source_file} (Chunk {meta.get('chunk_index', 0)})")
            context_str += f"\n--- Start of Snippet from {source_file} ---\n{doc}\n--- End of Snippet ---\n"

    # We now inject the memory string directly into the system prompt
    system_prompt = (
        "You are an expert AI software development assistant.\n"
        "You have access to specific snippets of code and documentation from the user's project repository below.\n"
        "Use ONLY the provided snippets and your previous session memory to answer the user's question accurately. "
        "If the snippets do not contain the information needed, state clearly that the context is insufficient.\n\n"
        f"CONTEXT FROM REPOSITORY:\n{context_str}"
        f"{session_memory_string}"
    )

    llm_response = query_llm(system_prompt, args.query, args.host, LLM_MODEL)

    if llm_response:
        summary = condense_interaction(args.query, llm_response, args.host, LLM_MODEL)
        
        with open(session_file_condensed, "a", encoding="utf-8") as f:
            f.write(f"### Condensed Interaction\n{summary}\n\n---\n\n")
            
        with open(session_file_full, "a", encoding="utf-8") as f:
            f.write(f"### User Query\n{args.query}\n\n")
            f.write(f"### Assistant Response\n{llm_response}\n\n---\n\n")
            
        print(f"\nSaved condensed memory to {args.session}.md")
        print(f"Saved full transcript to {args.session}.full.md")

if __name__ == "__main__":
    main()