---
name: credentials-manager
description: |
  Manage authentication credentials (API keys, tokens, usernames/passwords) across Claude Code sessions.
  Use this skill whenever the user provides credentials they want to save for later use, asks to retrieve
  stored credentials, lists saved credentials, or deletes credentials. Also trigger when the user mentions
  API keys, tokens, passwords, secrets, or authentication info in the context of storing or retrieving them.
  Trigger phrases include: "save this API key", "remember my token", "what credentials do I have",
  "use the API key I saved before", "delete my old credentials", "store this password".
  IMPORTANT: Also trigger when the user accesses a URL or API endpoint — check if stored credentials
  match the URL's domain and automatically apply them. This includes WebFetch, curl, API calls, etc.
  If the user provides a credential during a task (e.g., "my OpenAI key is sk-..."), proactively offer
  to save it for future sessions.
---

# Credentials Manager

Manage authentication credentials that persist across Claude Code sessions. Credentials are stored in a JSON file whose location is resolved at runtime based on the current working directory. Credentials can be associated with URLs/domains for automatic lookup.

## Storage Location (MANDATORY resolution)

The credentials file path is resolved per session using the rules below. **Always re-resolve at the start of each operation; never hardcode a single path.**

| 優先順位 | 条件 | パス |
|---------|------|------|
| 1（優先） | 現在のワーキングディレクトリ（または祖先ディレクトリ）に `.git` がある | `{repo_root}/.claude/.local/plugins/credentials-manager/credentials.json` |
| 2（フォールバック） | 上記に該当しない（リポジトリ外での作業） | `~/.claude/.local/plugins/credentials-manager/credentials.json` |

### Resolution procedure

1. Walk up from the current working directory to find the nearest ancestor containing `.git`. If found, use that ancestor as `{repo_root}`.
2. If not found, fall back to the user home directory.
3. Ensure the parent directory (`.claude/.local/plugins/credentials-manager/`) exists; create it if missing.
4. If the credentials file does not exist at the resolved path, treat it as an empty store (`{"credentials": {}}`) and create it on first write.

### Install-scope mapping

The resolved path naturally matches the user's install scope:

- **User-scope install** (cross-project use, no specific repo) → falls into rule 2 → `~/.claude/.local/plugins/credentials-manager/credentials.json`
- **Project-scope install** (working inside a repo) → falls into rule 1 → `{repo_root}/.claude/.local/plugins/credentials-manager/credentials.json`
- **Local-scope install** (same repo, machine-local) → same as project-scope

Project-stored credentials live alongside the repository and are isolated per project. User-stored credentials are shared across non-repo sessions.

### gitignore guidance

When the resolved path is inside a git repository, ensure `.claude/.local/` is listed in `.gitignore`. If it is not, warn the user before writing the file. Never commit `credentials.json`.

## Credential File Format

```json
{
  "credentials": {
    "<credential-name>": {
      "type": "api_key | token | password | custom",
      "value": "<the secret value>",
      "description": "What this credential is for",
      "urls": ["https://api.example.com/v1/*"],
      "domains": ["api.example.com"],
      "auth_method": "header:Authorization:Bearer",
      "created_at": "ISO 8601 timestamp",
      "updated_at": "ISO 8601 timestamp"
    }
  }
}
```

### Fields

- **type**: The kind of credential (`api_key`, `token`, `password`, or `custom`)
- **value**: The secret value itself
- **description**: Human-readable description of what this credential is for
- **urls**: (optional) List of URL patterns this credential applies to. Supports `*` wildcard for path matching (e.g., `https://api.example.com/v1/*`)
- **domains**: (optional) List of domains this credential applies to (e.g., `api.example.com`). Extracted automatically from URLs when saving.
- **auth_method**: (optional) How to send the credential in HTTP requests. Format: `header:<header-name>:<prefix>` or `query:<param-name>`. Examples:
  - `header:Authorization:Bearer` → `Authorization: Bearer <value>`
  - `header:X-API-Key:` → `X-API-Key: <value>`
  - `query:api_key` → `?api_key=<value>`
  - If not specified, defaults to `header:Authorization:Bearer`
- **created_at / updated_at**: ISO 8601 timestamps

## Operations

### Save a credential

When the user provides a credential to save:

1. Resolve the credentials file path using the rules above.
2. Read the existing file (create an empty store if it does not exist).
3. Ask the user for a name/identifier if not obvious from context.
4. Determine the type (`api_key`, `token`, `password`, or `custom`).
5. **If the credential was provided in the context of accessing a URL**, automatically populate:
   - `urls`: the full URL pattern (use `*` for variable path segments if appropriate)
   - `domains`: extract the domain from the URL
   - `auth_method`: infer from how the credential was used (e.g., if passed as a Bearer token, set `header:Authorization:Bearer`; if used as a query parameter, set `query:<param-name>`)
6. Add or update the entry in the JSON file.
7. Write the updated file back.
8. Confirm to the user, showing the credential name, type, associated URLs, and the **resolved storage path**, but NEVER the full value — show only the first 4 and last 4 characters with `***` in between (e.g., `sk-a****b3Fg`).

### Retrieve a credential

When the user needs a stored credential:

1. Resolve the credentials file path using the rules above.
2. Read the file.
3. Find the matching credential by name (case-insensitive partial matching is OK).
4. Return the value for use in the current task.
5. When displaying to the user, always mask the value (show first 4 + last 4 characters only).
6. When using programmatically (e.g., in a script or API call), use the full value.

### Auto-match credential by URL

When the user requests access to a URL or API endpoint and does NOT explicitly provide credentials:

1. Resolve the credentials file path and read it.
2. Extract the domain and full URL from the user's request.
3. Search stored credentials for a match:
   - First, check `domains` field for an exact domain match
   - Then, check `urls` field for a URL pattern match (with wildcard support)
   - Finally, check `description` field for URL/domain mentions as a fallback
4. **If exactly one match is found**: use it automatically. Inform the user: "Stored credential '<name>' (****) was automatically applied for <domain>."
5. **If multiple matches are found**: ask the user which credential to use, showing masked values.
6. **If no match is found**: proceed without credentials, or ask the user if they have credentials for this URL.

When applying the credential automatically, use the `auth_method` field to determine how to send it. If `auth_method` is not set, default to `Authorization: Bearer <value>`.

### List credentials

When the user asks what credentials are stored:

1. Resolve the credentials file path and read it.
2. Display a table with: name, type, description, associated domains, and masked value.
3. Show the last updated timestamp for each entry.
4. Indicate whether the source path is project-scoped or user-scoped.

### Delete a credential

When the user asks to remove a credential:

1. Resolve the credentials file path and read it.
2. Confirm the credential name with the user before deleting.
3. Remove the entry and write the file back.
4. Confirm deletion.

### Proactive detection

If during a conversation the user pastes or provides something that looks like a credential (API key patterns like `sk-...`, `ghp_...`, `xoxb-...`, bearer tokens, etc.) and it hasn't been saved yet, briefly suggest: "Would you like me to save this credential for future sessions?"

When saving proactively, capture any URL/domain context from the current conversation so the credential can be auto-matched later.

## Security Notes

- Credentials are stored as **plain text** in the local filesystem. This is acceptable for local development use but not suitable for production secrets management.
- Never display full credential values in conversation output — always mask them.
- Never include credential values in commit messages, logs, or any output that might be shared.
- When the credentials file is inside a git repository, verify that `.claude/.local/` is in `.gitignore` before writing.
- If the user asks to commit files that include `credentials.json`, warn them that this file contains secrets and should not be committed.

## Example Interactions

**Saving with URL association (inside a project repo):**
```
User: "https://api.example.com/v1/data にアクセスして。APIキーは abc-secret-123 を使って。"
→ Resolve path: <repo_root>/.claude/.local/plugins/credentials-manager/credentials.json
→ Save as: example-api-key, type: api_key
→ urls: ["https://api.example.com/v1/*"]
→ domains: ["api.example.com"]
→ auth_method: "header:Authorization:Bearer"
→ Response: "Saved credential 'example-api-key' (api_key): abc-****123 — associated with api.example.com (project-scoped)"
```

**Auto-match on subsequent access:**
```
User: "https://api.example.com/v1/users からデータを取得して。"
→ Resolve path, read credentials.json, match domain 'api.example.com'
→ Found: 'example-api-key'
→ Apply automatically with Bearer auth
→ Response: "Stored credential 'example-api-key' (abc-****123) を api.example.com に自動適用しました。"
```

**Saving without URL (outside a repo, user-scoped):**
```
User: "My OpenAI API key is sk-proj-abc123def456"
→ Resolve path: ~/.claude/.local/plugins/credentials-manager/credentials.json
→ Save as: openai-api-key, type: api_key
→ Response: "Saved credential 'openai-api-key' (api_key): sk-p****f456 (user-scoped)"
```

**Listing:**
```
User: "What credentials do I have saved?"
→ Resolve path, display table of stored credentials with masked values, associated domains, and source scope.
```
