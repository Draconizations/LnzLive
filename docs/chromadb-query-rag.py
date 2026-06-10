import os
import datetime
import argparse
import requests
import json
import re
import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

def load_config():
    config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rag_config.json")
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            return json.load(f)
    return {
        "host": "http://localhost:1234/v1",
        "llm_model": "qwen/qwen3.6-35b-a3b",
        "embedding_model": "text-embedding-qwen3-embedding-0.6b",
        "max_context_tokens": 8192,
        "history_token_budget": 3000
    }

def estimate_tokens(text):
    """Heuristic: roughly 4 characters per token."""
    return len(text) // 4

def init_session_file(filepath):
    """Creates the base structure for the Session Anchor."""
    if not os.path.exists(filepath):
        with open(filepath, "w", encoding="utf-8") as f:
            f.write("### SESSION ANCHOR\nNo anchor established yet.\n\n### RECENT LOGS\n")

def compress_memory(session_file, host, model_name, budget):
    """
    Checks if the session file is too large. If so, takes the older half of the raw logs,
    asks the LLM to update a highly-structured Session Anchor, and rewrites the file.
    """
    if not os.path.exists(session_file):
        return
        
    with open(session_file, "r", encoding="utf-8") as f:
        content = f.read()

    # If we are under budget, do nothing.
    if estimate_tokens(content) < budget:
        return

    print("\n[System] Context budget reached. Updating Session Anchor...")
    
    # Split the file into the Anchor and the raw turns
    parts = content.split("### RECENT LOGS\n")
    current_anchor = parts[0].replace("### SESSION ANCHOR\n", "").strip() if len(parts) > 0 else ""
    raw_logs = parts[-1].strip().split('\n---\n')
    
    # Clean up empty splits
    raw_logs = [log for log in raw_logs if log.strip()]
    
    # Keep the most recent 2 turns raw, compress the rest
    if len(raw_logs) <= 2:
        return
        
    logs_to_compress = "\n---\n".join(raw_logs[:-2])
    logs_to_keep = "\n---\n".join(raw_logs[-2:]) + "\n---\n"
    
    system_prompt = (
        "You are maintaining a technical Session Anchor for a Godot development environment. "
        "Update the existing anchor with the specific details from the older logs provided. "
        "You MUST output exactly four sections. Do not lose specific variable names, file names, or math logic.\n\n"
        "1. [INTENT] The current overarching development goal.\n"
        "2. [FILES_TOUCHED] Exact file paths (e.g., PaintballSettings.gd) and functions modified.\n"
        "3. [DECISIONS] Specific math, regex, or logic patterns resolved.\n"
        "4. [PENDING] Any unresolved questions or next steps."
    )
    
    user_prompt = f"PREVIOUS ANCHOR:\n{current_anchor}\n\nOLDER LOGS TO COMPRESS:\n{logs_to_compress}"
    
    url = f"{host.rstrip('/')}/chat/completions"
    headers = {"Content-Type": "application/json"}
    data = {
        "model": model_name,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "temperature": 0.1,
        "stream": False
    }
    
    try:
        response = requests.post(url, headers=headers, json=data)
        if response.status_code == 200:
            new_anchor = response.json()['choices'][0]['message']['content'].strip()
            
            # Print to terminal for user verification
            print("\n================ NEW SESSION ANCHOR ================\n")
            print(new_anchor)
            print("\n====================================================\n")
            
            # Rewrite the session file with the new structure
            with open(session_file, "w", encoding="utf-8") as f:
                f.write(f"### SESSION ANCHOR\n{new_anchor}\n\n### RECENT LOGS\n{logs_to_keep}")
        else:
            print(f"[System] Anchor update failed. Server returned: {response.status_code}")
    except Exception as e:
        print(f"[System] Failed to update Session Anchor: {e}")

def load_smart_history(filepath):
    """Loads the formatted memory file (Anchor + Logs) for the LLM prompt."""
    if not os.path.exists(filepath):
        return ""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read().strip()
    if not content:
        return ""
    return f"\n\n--- PREVIOUS SESSION MEMORY ---\n{content}\n-------------------------------\n"

def extract_keywords(query):
    """Extracts significant words from the query for exact matching."""
    return [w for w in re.split(r'[^a-zA-Z0-9_]', query) if len(w) > 3]

def hybrid_score(doc_text, filename, query_keywords, base_similarity):
    """Boosts Chroma's semantic similarity score based on exact keyword matches."""
    score = base_similarity
    doc_text_lower = doc_text.lower()
    filename_lower = filename.lower()
    
    for word in query_keywords:
        word_lower = word.lower()
        if word_lower in filename_lower:
            score += 0.3 
            
        is_code_term = "_" in word or (not word.islower() and not word.isupper())
        match_count = doc_text_lower.count(word_lower)
        if match_count > 0:
            score += min(match_count * (0.05 if is_code_term else 0.01), 0.15) 
    return score

def query_llm(system_prompt, user_prompt, host, model_name):
    """Sends the RAG prompt to LM Studio and streams the output."""
    url = f"{host.rstrip('/')}/chat/completions"
    headers = {"Content-Type": "application/json"}
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ]
    
    data = {"model": model_name, "messages": messages, "temperature": 0.2, "stream": True}
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
        print("\n----------------")
        return full_response
    except Exception as e:
        print(f"\nFailed to communicate with LLM server: {e}")
        return ""

def get_role_prompt(role):
    roles = {
        "architect": "You are a Lead Software Architect specializing in Godot. Analyze the code structural integrity and logic.",
        "coder": "You are a Senior Godot Engineer. Provide production-ready, highly optimized GDScript.",
        "user": "You are a highly technical assistant helping a developer navigate their Godot codebase."
    }
    return roles.get(role, roles["user"])

def main():
    config = load_config()
    parser = argparse.ArgumentParser(description="Query your repository using local Hybrid RAG.")
    parser.add_argument("--query", type=str, required=True, help="Your question")
    parser.add_argument("--session", type=str, default=None, help="Session name for memory")
    parser.add_argument("--num_results", type=int, default=3, help="Final chunks to feed the LLM")
    parser.add_argument("--include", nargs='+', choices=['main', 'godot'], default=['main'])
    parser.add_argument("--role", choices=['architect', 'coder', 'user'], default='user')
    parser.add_argument("--file_types", nargs='+', help="Filter by extension (e.g., gd tres)")
    parser.add_argument("--script", nargs='+', help="Specific scripts to prioritize")
    
    args = parser.parse_args()
    
    embedding_func = OpenAIEmbeddingFunction(
        api_key="lm-studio", api_base=config["host"], model_name=config["embedding_model"]
    )

    # 1. Manage Session Memory
    if not args.session: args.session = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    session_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-sessions")
    os.makedirs(session_dir, exist_ok=True)
    session_file = os.path.join(session_dir, f"{args.session}.md")
    
    init_session_file(session_file)
    compress_memory(session_file, config["host"], config["llm_model"], config["history_token_budget"])
    session_memory_string = load_smart_history(session_file)

    # 2. Database Search (Hybrid)
    candidates = []
    query_keywords = extract_keywords(args.query)
    
    print(f"\nSearching {args.include}...")
    for db_key in args.include:
        oversample_limit = args.num_results * 5 
        
        try:
            db_map = {'main': ('main', 'repo_knowledgebase'), 'godot': ('godot', 'godot_docs')}
            db_path, coll_name = db_map[db_key]
            
            path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-chromadb", db_path)
            client = chromadb.PersistentClient(path=path)
            col = client.get_collection(name=coll_name, embedding_function=embedding_func)
            
            res = col.query(query_texts=[args.query], n_results=oversample_limit, include=['documents', 'metadatas', 'distances'])
            
            if res['documents'] and res['documents'][0]:
                for doc, meta, dist in zip(res['documents'][0], res['metadatas'][0], res['distances'][0]):
                    source_name = meta.get('filename', 'Unknown')
                    
                    if args.file_types and db_key == 'main':
                        if not any(source_name.endswith(f".{ext.lstrip('.')}") for ext in args.file_types):
                            continue

                    is_priority = False
                    if args.script and any(script.lower() in source_name.lower() for script in args.script):
                        is_priority = True
                    
                    base_sim = 1.0 - dist
                    final_score = hybrid_score(doc, source_name, query_keywords, base_sim)
                    
                    candidates.append({
                        'file': source_name, 'chunk': meta.get('chunk_index', 0),
                        'doc': doc, 'score': final_score, 'priority': is_priority
                    })
        except Exception as e:
            print(f"Could not load {db_key}: {e}")

    # Sort by Priority, then Hybrid Score
    candidates.sort(key=lambda x: (x['priority'], x['score']), reverse=True)

    # 3. Build Context
    context_str = ""
    indices = list(range(min(args.num_results, len(candidates))))
    
    for i in indices:
        c = candidates[i]
        context_str += f"\n--- {c['file']} (Chunk {c['chunk']}) ---\n{c['doc']}\n"
        print(f" -> Added: {c['file']} (Chunk {c['chunk']}) | Score: {c['score']:.3f}")

    # 4. Finalize Prompt and Call LLM
    base_role = get_role_prompt(args.role)
    system_prompt = (
        f"{base_role}\n"
        "Use the repository context and session memory provided to answer accurately.\n"
        f"CONTEXT:\n{context_str}\n{session_memory_string}"
    )

    total_estimated_tokens = estimate_tokens(system_prompt) + estimate_tokens(args.query)
    if total_estimated_tokens > config["max_context_tokens"]:
        print(f"\n[Warning] Nearing context limit (~{total_estimated_tokens} tokens). Proceeding anyway...")

    llm_response = query_llm(system_prompt, args.query, config["host"], config["llm_model"])

    # 5. Append to Recent Logs
    if llm_response:
        with open(session_file, "a", encoding="utf-8") as f:
            f.write(f"USER: {args.query}\n\nASSISTANT: {llm_response}\n---\n")

if __name__ == "__main__":
    main()