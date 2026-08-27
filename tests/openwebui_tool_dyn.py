import os
import requests
from datetime import datetime
from pydantic import BaseModel, Field

import requests
import json
from typing import Dict, Any


class Tools:
    def __init__(self):
        # openwebui in docker Works perfectly because of --network=host
        self.base_url = "http://localhost:55501"

    # Add your custom tools using pure Python code here, make sure to add type hints and descriptions


    def get_available_system_commands(self) -> str:
        """
        Retrieves the real-time list of executable system commands, their usage descriptions, 
        and arguments directly from the backend Nim server manifest.
        Use this tool when the user asks what they can do, what commands exist, or when you need 
        to verify if a specific action is supported before executing it.
        
        :return: A JSON string containing the schema definitions of available actions.
        """
        try:
            response = requests.get(f"{self.base_url}/manifest", timeout=5)
            if response.status_code == 200:
                return json.dumps(response.json(), indent=2)
            return f"Error: Backend returned status code {response.status_code}"
        except Exception as e:
            return f"CRITICAL: Failed to discover backend manifest. Is Nim running? Details: {str(e)}"

    def execute_backend_command(self, command_name: str, arguments: dict = None) -> str:
        """
        Sends an execution request to the Nim backend for a valid command found in the manifest.
        
        :param command_name: The precise 'name' string key from the manifest (e.g., 'restart_process')
        :param arguments: A key-value dictionary representing any 'required_args' specified by the manifest.
        :return: Output execution status text from the server.
        """
        url = f"{self.base_url}/command"
        payload = {
            "command": command_name,
            "args": arguments or {}
        }
        
        try:
            response = requests.post(url, json=payload, timeout=10)
            if response.status_code == 200:
                res_data = response.json()
                return f"Execution successful! Command: '{res_data.get('executed')}' processing state completed successfully."
            return f"Execution Failed. Backend returned HTTP {response.status_code}: {response.text}"
        except Exception as e:
            return f"Network Error: Could not dispatch runtime request. Details: {str(e)}"
