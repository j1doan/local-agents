#!/bin/bash

### BEFORE FIRST RUN: `chmod +x llamacpp.sh`

cd /c/llama.cpp || exit 1

MODELS_DIR="/c/models"
PRESETS_FILE="$(dirname "$0")/models.ini"
SERVER_ARGS=(
    --host 127.0.0.1
    --port 8080
    --poll 100
    --prio 2
    --models-max 2
    --models-preset "$PRESETS_FILE"
)

TOOL_SYSTEM_PROMPT="You are a helpful assistant. You have access to tools — use them whenever relevant to the user's request. Always call a tool if one matches the task. Do not claim you cannot use tools. When a tool call is needed, respond ONLY with the tool call, no extra text before or after."

echo "                                             "
echo "  __________________________________________"
echo "< hello, please pick from the options below. >"
echo "  ------------------------------------------"
echo "       \   ^__^"
echo "        \  (oO)\_______"
echo "           (__)\       )\/\\"
echo "            V ||----w |"
echo "               ||     ||"
echo "                                             "
echo "1) Start llama-server (router mode)"
echo "2) llama-benchmark.exe"
echo

read -rp "Select an option (1-2): " choice

case "$choice" in
    1)
        echo "Starting llama-server in router mode..."
        echo "Presets file:    $PRESETS_FILE"
        echo "Max loaded models: 2"
        echo "Tool calling: ENABLED (reasoning-budget=0, jinja=on)"
        echo
        echo "Model management:"
        echo "  List available models:  curl http://127.0.0.1:8080/models"
        echo "  Load a model:          curl -X POST http://127.0.0.1:8080/models/load -H 'Content-Type: application/json' -d '{\"model\": \"your-model.gguf\"}'"
        echo "  Unload a model:        curl -X POST http://127.0.0.1:8080/models/unload -H 'Content-Type: application/json' -d '{\"model\": \"your-model.gguf\"}'"
        echo
        echo "Tool calling example (save to a file, e.g. tool_request.json):"
        echo '  {'
        echo '    "model": "YOUR_MODEL.gguf",'
        echo '    "messages": ['
        echo "      {\"role\": \"system\", \"content\": \"$TOOL_SYSTEM_PROMPT\"},"
        echo '      {"role": "user", "content": "What is the weather in Paris?"}'
        echo '    ],'
        echo '    "tools": ['
        echo '      {"type":"function","function":{"name":"get_weather","description":"Get current weather for a city","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}'
        echo '    ],'
        echo '    "tool_choice": "auto",'
        echo '    "temperature": 1.0,'
        echo '    "max_tokens": 512'
        echo '  }'
        echo
        echo '  curl -s http://127.0.0.1:8080/v1/chat/completions -H "Content-Type: application/json" -d @tool_request.json'
        echo

        ./llama-server.exe "${SERVER_ARGS[@]}" &

        echo "Waiting for llama.cpp server..."
        sleep 10
        start http://127.0.0.1:8080
        echo "Llama server running at http://127.0.0.1:8080/v1"
        wait
        ;;

    2)
        mapfile -t GGUF_FILES < <(find "$MODELS_DIR" -maxdepth 1 -name '*.gguf' -printf '%f\n' 2>/dev/null | sort)
        if [[ ${#GGUF_FILES[@]} -eq 0 ]]; then
            echo "No GGUF files found in $MODELS_DIR"
            exit 1
        fi

        echo "Available GGUFs:"
        echo
        for i in "${!GGUF_FILES[@]}"; do
            size=$(du -h "$MODELS_DIR/${GGUF_FILES[$i]}" | cut -f1)
            printf "  %2d) %-60s %s\n" $((i + 1)) "${GGUF_FILES[$i]}" "$size"
        done
        echo

        read -rp "Select model (1-${#GGUF_FILES[@]}): " idx
        [[ "$idx" =~ ^[0-9]+$ && idx -ge 1 && idx -le ${#GGUF_FILES[@]} ]] || { echo "Invalid selection."; exit 1; }
        BENCH_MODEL="$MODELS_DIR/${GGUF_FILES[$((idx - 1))]}"

        echo
        read -rp "GPU layers (0=CPU only, 999=all): " ngl
        ngl="${ngl:-999}"
        read -rp "Prompt tokens [512]: " pp
        pp="${pp:-512}"
        read -rp "Generate tokens [128]: " tg
        tg="${tg:-128}"
        read -rp "Repetitions [5]: " reps
        reps="${reps:-5}"

        echo
        echo "Benchmarking: $(basename "$BENCH_MODEL")"
        echo "  ngl=$ngl  pp=$pp  tg=$tg  reps=$reps"
        echo
        ./llama-bench.exe \
            -m "$BENCH_MODEL" \
            -ngl "$ngl" \
            -t 4 \
            -b 2048 \
            -ub 512 \
            -fa auto \
            -ctk q8_0 \
            -ctv q8_0 \
            -p "$pp" \
            -n "$tg" \
            -r "$reps" \
            -o md \
            --progress
        ;;

    *)
        echo "Invalid selection."
        exit 1
        ;;
esac
