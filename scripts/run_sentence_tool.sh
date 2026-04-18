#!/bin/bash
# Launch LLLB Sentence Tool
cd "$(dirname "$0")/.."
.venv/bin/streamlit run scripts/sentence_tool.py \
  --server.headless false \
  --browser.gatherUsageStats false
