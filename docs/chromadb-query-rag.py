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
        
    combined = "\n".join(f"- {s}" for s in summaries[-3:])
    return f"\n\n--- PREVIOUS SESSION MEMORY ---\n{combined}\n-------------------------------\n"

def query_llm(system_prompt, user_prompt, host, model_name):
    """Sends the RAG prompt to LM Studio and streams the output with robust error handling."""
    url = f"{host.rstrip('/')}/chat/completions"
    headers = {"Content-Type": "application/json"}
    
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
    print("Condensing session memory...")
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


def get_collection(db_name, coll_name, embedding_func):
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
        "planner": (
            "You are a meticulous Project Manager specialized in Godot development. "
            "Your priority is breaking down complex features into actionable milestones. "
            "Always organize tasks by logical order of operations (dependency management), "
            "estimate technical effort, and ensure the development roadmap remains coherent."
        ),
        "interviewer": (
            "You are a Technical Consultant. Your job is to elicit high-quality requirements. "
            "Before suggesting solutions, ask one probing, insightful question at a time to uncover "
            "edge cases, performance constraints, or user-experience goals. Do not overwhelm the user; "
            "guide the conversation step-by-step."
        ),
        "architect": (
            "You are a Lead Software Architect. Your focus is on long-term system stability, "
            "decoupling, and scalability. When analyzing code, look for opportunities to unify "
            "math logic into global utilities (like LnzLiveUtils). Always prioritize maintainable "
            "patterns and explain the 'why' behind your structural decisions."
        ),
        "coder": (
            "You are a Senior Godot/GDScript Engineer. Your code must be production-ready: "
            "DRY (Don't Repeat Yourself), memory-efficient, and well-commented. "
            "Always assume the user wants high-performance code, and if a logic pattern is "
            "inefficient, point it out immediately and suggest the optimized GDScript alternative."
        ),
        "user": (
            "You are a Power User who uses LnzLive editor to hex edit models."
            "You care deeply about quality-of-life improvements, new features that make hexing easier, and UI/UX flow."
        )
    }
    return roles.get(role, roles["user"])

def main():
    parser = argparse.ArgumentParser(description="Query your repository knowledgebase using local RAG.")
    parser.add_argument("--query", type=str, required=True, help="The question you want to ask your codebase")
    parser.add_argument("--session", type=str, default=None, help="Name or tag for the conversation session")
    parser.add_argument("--host", type=str, default="http://localhost:1234/v1", help="LMStudio local server URL")
    parser.add_argument("--num_results", type=int, nargs='+', default=[2], 
                        help="Chunks to retrieve per DB (e.g., --num_results 2 4 1)")
    parser.add_argument("--include", nargs='+', choices=['main', 'godot', 'lnz'], default=['main'],
                        help="List of DBs to search (e.g., --include godot lnz)")
    parser.add_argument("--role", choices=['planner', 'interviewer', 'architect', 'coder', 'user'], default='user')
    parser.add_argument("--file_types", nargs='+', help="Filter main DB by extension (e.g., gd tres md)")
    
    # NEW ARGUMENTS
    parser.add_argument("--script", nargs='+', help="List of scripts to prioritize in the context (e.g., player.gd LnzLiveUtils.gd)")
    parser.add_argument("--interactive", action="store_true", help="Enable interactive selection of which chunks to feed the LLM")
    
    args = parser.parse_args()
    LLM_MODEL = "qwen/qwen3.6-35b-a3b"
    
    # 1. Initialize Embedding Function
    embedding_func = OpenAIEmbeddingFunction(
        api_key="lm-studio", api_base=args.host, model_name="text-embedding-qwen3-embedding-0.6b"
    )

    # 2. Session Setup
    if not args.session: args.session = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    session_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-sessions")
    os.makedirs(session_dir, exist_ok=True)
    session_file_condensed = os.path.join(session_dir, f"{args.session}.md")
    session_file_full = os.path.join(session_dir, f"{args.session}.full.md")
    session_memory_string = load_condensed_history(session_file_condensed)

    # 3. Search ALL collections
    context_str = ""
    candidates = []
    
    print(f"\nSearching {args.include}...")
    for i, db_key in enumerate(args.include):
        limit = args.num_results[i] if i < len(args.num_results) else args.num_results[-1]
        oversample_limit = limit * 3 # Request 3x to ensure we find enough matches after filtering
        
        try:
            db_map = {
                'main': ('main', 'repo_knowledgebase'),
                'godot': ('godot', 'godot_docs'),
                'lnz': ('lnz', 'lnz_docs')
            }
            db_path, coll_name = db_map[db_key]
            
            path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "llm-rag-chromadb", db_path)
            client = chromadb.PersistentClient(path=path)
            col = client.get_collection(name=coll_name, embedding_function=embedding_func)
            
            res = col.query(query_texts=[args.query], n_results=oversample_limit, include=['documents', 'metadatas', 'distances'])
            
            if res['documents'] and res['documents'][0]:
                for doc, meta, dist in zip(res['documents'][0], res['metadatas'][0], res['distances'][0]):
                    source_name = meta.get('filename', 'Unknown')
                    
                    # EXTENSION FILTER LOGIC
                    if args.file_types and db_key == 'main':
                        if not any(source_name.endswith(f".{ext.lstrip('.')}") for ext in args.file_types):
                            continue

                    # SCRIPT PRIORITY LOGIC
                    is_priority = False
                    if args.script and any(script.lower() in source_name.lower() for script in args.script):
                        is_priority = True
                    
                    candidates.append({
                        'db': db_key,
                        'file': source_name,
                        'chunk': meta.get('chunk_index', 0),
                        'doc': doc,
                        'sim': 1.0 - dist,
                        'priority': is_priority
                    })
        except Exception as e:
            print(f"Could not load {db_key}: {e}")

    # 4. Sort and Present Results
    # Sort first by priority (True > False), then by semantic similarity score
    candidates.sort(key=lambda x: (x['priority'], x['sim']), reverse=True)

    print("\n--- Found Chunks ---")
    for idx, c in enumerate(candidates):
        priority_flag = "[PRIORITY] " if c['priority'] else ""
        print(f"[{idx}] {priority_flag}{c['file']} (Chunk {c['chunk']}) | Sim: {c['sim']:.4f} | Source: {c['db']}")
    
    # 5. Selection Logic
    if args.interactive:
        selection = input("\nEnter indices to include (e.g., 0 2 3) or 'all': ").strip()
        if selection.lower() == 'all':
            indices = range(len(candidates))
        else:
            indices = [int(i) for i in selection.split() if i.isdigit()]
    else:
        # Auto-select the top N results based on the sum of the --num_results limits
        total_limit = sum(args.num_results)
        indices = list(range(min(total_limit, len(candidates))))
        print(f"\nAuto-selecting top {len(indices)} chunks.")
        
    # BUILD CONTEXT FROM SELECTION
    for i in indices:
        if i < len(candidates):
            c = candidates[i]
            context_str += f"\n--- Start of Snippet from {c['file']} (Chunk {c['chunk']}) ---\n{c['doc']}\n---\n"
            if not args.interactive:
                print(f" -> Added: {c['file']} (Chunk {c['chunk']})")

    # 6. Finalize Prompt and Call LLM
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