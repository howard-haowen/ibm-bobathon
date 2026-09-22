# Python 執行環境規範

執行所有 Python 程式時，必須使用 `uv run` 而非系統的 `python` 或 `python3`，確保相依套件隔離管理。

**正確**：`uv run script.py`、`uv run pytest`
**禁止**：`python script.py`、`python3 script.py`
