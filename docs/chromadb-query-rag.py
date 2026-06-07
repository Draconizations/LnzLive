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


def get_collection(db_name, coll_name):
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-chromadb", db_name)
    client = chromadb.PersistentClient(path=path)
    return client.get_collection(name=coll_name, embedding_function=embedding_func)

def truncate_context(text, max_chars=12000):
    """Safety check: Truncate context to a safe limit if it gets too large."""
    if len(text) > max_chars:
        return "...[context truncated]..." + text[-max_chars:]
    return text

def get_role_prompt(role):
    roles = {
        "planner": "You are a project manager. Focus on milestones, timelines, and logical task order.",
        "interviewer": "You are an interviewer. Your goal is to understand the user's needs. Ask one insightful clarifying question at a time.",
        "architect": "You are a software architect. Focus on system design, scalability, and code structure.",
        "coder": "You are a senior developer. Focus on writing clean, efficient, and robust code snippets.",
        "user": "You are a helpful assistant."
    }
    return roles.get(role, roles["user"])

def main():
    parser = argparse.ArgumentParser(description="Query your repository knowledgebase using local RAG.")
    parser.add_argument("--query", type=str, required=True, help="The question you want to ask your codebase")
    parser.add_argument("--session", type=str, default=None, help="Name or tag for the conversation session")
    parser.add_argument("--host", type=str, default="http://localhost:1234/v1", help="LMStudio local server URL")
    parser.add_argument("--num_results", type=int, nargs='+', default=[2], 
                        help="Chunks to retrieve per DB (e.g., --num-chunks 2 4 1)")
    parser.add_argument("--include", nargs='+', choices=['main', 'godot', 'lnz'], default=['main'],
                        help="List of DBs to search (e.g., --include godot lnz)")
    parser.add_argument("--role", choices=['planner', 'interviewer', 'architect', 'coder', 'user'], default='user')
    parser.add_argument("--file_types", nargs='+', help="Filter main DB by extension (e.g., gd tres md)")
    
    args = parser.parse_args()
    LLM_MODEL = "qwen/qwen3.6-35b-a3b"
    
    # 1. Initialize Embedding Function
    embedding_func = OpenAIEmbeddingFunction(
        api_key="lm-studio", api_base=args.host, model_name="text-embedding-qwen3-embedding-0.6b"
    )

    # 2. Define our collection mapping
    # Note: 'main' is always included, extra dbs are appended if requested
    db_map = {'main': ('main', 'repo_knowledgebase')}
    if args.include:
        for inc in args.include:
            db_map[inc] = (inc, f"{inc}_docs")

    # 3. Session Setup
    if not args.session: args.session = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    session_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-sessions")
    os.makedirs(session_dir, exist_ok=True)
    session_file_condensed = os.path.join(session_dir, f"{args.session}.md")
    session_file_full = os.path.join(session_dir, f"{args.session}.full.md")
    session_memory_string = load_condensed_history(session_file_condensed)

    # 4. Search ALL collections
    context_str = ""
    print(f"Searching {args.include}...")
    
    for i, db_key in enumerate(args.include):
        limit = args.num_results[i] if i < len(args.num_results) else args.num_results[-1]
        
        try:
            db_map = {
                'main': ('main', 'repo_knowledgebase'),
                'godot': ('godot', 'godot_docs')
            }
            db_path, coll_name = db_map[db_key]
            
            path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-chromadb", db_path)
            client = chromadb.PersistentClient(path=path)
            col = client.get_collection(name=coll_name, embedding_function=embedding_func)
            
            oversample_limit = limit * 3
            res = col.query(query_texts=[args.query], n_results=limit, include=['documents', 'metadatas', 'distances'])
            
            if res['documents'] and res['documents'][0]:
                print(f"[{db_key.upper()} RESULTS (Seeking {limit} chunks from {limit * 3} candidates)]")
                
                count = 0
                for doc, meta, dist in zip(res['documents'][0], res['metadatas'][0], res['distances'][0]):
                    if count >= limit: break
                    
                    source_name = meta.get('filename', 'Unknown')
                    
                    # FILTER LOGIC (Keep only if match)
                    if args.file_types and db_key == 'main':
                        if not any(source_name.endswith(f".{ext.lstrip('.')}") for ext in args.file_types):
                            continue

                    # CONVERT DISTANCE TO SIMILARITY SCORE
                    # ChromaDB distance is usually squared L2 or cosine distance.
                    # For cosine distance, similarity = 1 - distance.
                    similarity = 1.0 - dist
                    
                    chunk_idx = meta.get('chunk_index', 0)
                    print(f" -> Found: {source_name} (Chunk: {chunk_idx}) | Similarity: {similarity:.4f}")
                    
                    context_str += f"\n--- Start of Snippet from {source_name} (Chunk {chunk_idx}) ---\n{doc}\n---\n"
                    count += 1
                        
                if count == 0:
                    print(f" -> No chunks matched the file filter for {db_key}.")
            else:
                print(f" -> No relevant chunks found in {db_key}.")
                
        except Exception as e:
            print(f"Could not load {db_key}: {e}")

    # 5. Finalize Prompt and Call LLM
    safe_memory = truncate_context(session_memory_string, max_chars=12000)
    base_role = get_role_prompt(args.role)
    system_prompt = (
        f"{base_role}\n"
        "Use the repository context and session memory provided to answer accurately.\n"
        f"CONTEXT:\n{context_str}\n{safe_memory}"
    )

    llm_response = query_llm(system_prompt, args.query, args.host, LLM_MODEL)

    if llm_response:
        summary = condense_interaction(args.query, llm_response, args.host, LLM_MODEL)
        with open(session_file_condensed, "a", encoding="utf-8") as f:
            f.write(f"### Condensed Interaction\n{summary}\n\n---\n\n")
        with open(session_file_full, "a", encoding="utf-8") as f:
            f.write(f"### User Query\n{args.query}\n\n### Response\n{llm_response}\n\n---\n\n")
            
        print(f"\nSaved condensed memory to {args.session}.md")
        print(f"Saved full transcript to {args.session}.full.md")

if __name__ == "__main__":
    main()