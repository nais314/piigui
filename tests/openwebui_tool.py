import requests
from typing import Dict, Any

class Tools:
    def __init__(self):
        # Base URL of your minimal framework-less Nim server
        self.nim_server_url = "http://localhost:55501"

    def send_nim_command(self, command: str) -> str:
        """
        Executes a control command on the native Nim backend server.
        Use this tool whenever the user explicitly requests to trigger, 
        run, restart, or execute a system process/action.

        :param command: The explicit action payload string (e.g., 'restart_process', 'shutdown_system')
        :return: A success or error response string from the Nim runtime.
        """
        url = f"{self.nim_server_url}/command"
        headers = {"Content-Type": "application/json"}
        payload = {"command": command}

        try:
            response = requests.post(url, json=payload, headers=headers, timeout=5)
            if response.status_code == 200:
                data = response.json()
                return f"Success! Nim server executed action: {data.get('executed')}"
            else:
                return f"Error: Nim server responded with HTTP {response.status_code}: {response.text}"
        except requests.exceptions.RequestException as e:
            return f"Failed to connect to Nim server at {url}. Error: {str(e)}"

    def check_nim_status(self) -> str:
        """
        Checks the heartbeat status and system availability of the Nim web server backend.
        :return: Health status report payload string.

        Test Case (Command):"Go ahead and execute a full restart_process sequence on the machine."
        """
        url = f"{self.nim_server_url}/status"
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                return f"System Status: {data.get('status')} | Message: {data.get('message')}"
            return f"Status failure. HTTP Code: {response.status_code}"
        except requests.exceptions.RequestException as e:
            return f"Cannot reach Nim server. Error: {str(e)}"
