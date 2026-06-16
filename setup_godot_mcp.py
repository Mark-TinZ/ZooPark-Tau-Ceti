import os
import json
from pathlib import Path

def main():
    print("Настраиваем MCP-клиенты для работы с Godot...")

    gemini_home = Path.home() / ".gemini"
    gemini_cli_settings = gemini_home / "settings.json"
    antigravity_settings = gemini_home / "antigravity" / "mcp_config.json"

    mcp_server_config = {
        "godot": {
            "command": "npx",
            "args": ["-y", "@tugcantopaloglu/godot-mcp", "--project-path", "/home/mihail/Developer/Godot/zoo-park"],
            "env": {
                "DEBUG": "true"
            }
        }
    }

    def update_mcp_config(filepath):
        print(f"Обновление конфига: {filepath}")
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        data = {}
        if filepath.exists():
            try:
                data = json.loads(filepath.read_text())
            except json.JSONDecodeError:
                pass
        
        if "mcpServers" not in data:
            data["mcpServers"] = {}
            
        data["mcpServers"]["godot"] = mcp_server_config["godot"]
        
        filepath.write_text(json.dumps(data, indent=2))
        print(f"Конфиг {filepath} успешно обновлен.")

    try:
        update_mcp_config(gemini_cli_settings)
        update_mcp_config(antigravity_settings)
    except Exception as e:
        print(f"Ошибка при обновлении конфигов MCP: {e}")

    print("\nГотово! Конфигурация обновлена.")

if __name__ == "__main__":
    main()
