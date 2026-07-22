# Local AI Setup Using Llama.cpp

> [!WARNING]
> This is **not** documentation. This is a memory aid for an idiot (me).
>
> If you're here because Google brought you here (how that's possible is beyond me), do yourself a favor and read the official documentation instead.

This README may or may not get updated (most likely the latter).

## Prerequisites

- Download and build Llama.cpp: https://github.com/ggml-org/llama.cpp.
- Download models from HuggingFace, ~2B if you have a potato or ~27B if you have a decent GPU.
- Make sure the models are a) In `.gguf` format and b) quantized to int4 if your rig can handle.

## Instructions

1. Put this repo in `llama.cpp` folder that was just made when you cloned it.
2. Change `models.ini` to point to the correct location of the model and the correct model name.
3. Run `llamacpp.sh`, make sure to `chmod +x` before the first run.
4. Once a server is started, go to `localhost`.
  1. Don't launch the script again unless you want another `llama-server.exe` instance running.
  2. Try to integtate tools using `tool_example.json`.
5. **Optional:** Integrate with OpenCode by following instructions in `opencode.jsonc`.
