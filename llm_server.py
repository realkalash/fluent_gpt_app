import os
from flask import Flask, request, jsonify
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

app = Flask(__name__)

# Load the model
model = None
tokenizer = None
model_path = None

@app.route('/load_model', methods=['POST'])
def load_model():
    global model, tokenizer, model_path
    data = request.json
    model_path = data.get('model_path')
    
    print(f"Received model path: {model_path}")
    
    if not model_path or not os.path.isdir(model_path):
        print(f"Invalid model path: {model_path}")
        return jsonify({"error": "Invalid model path"}), 400
    
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_path)
        model = AutoModelForCausalLM.from_pretrained(model_path)
        return jsonify({"message": "Model loaded successfully"}), 200
    except Exception as e:
        print(f"Error loading model: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/chat/completions', methods=['POST'])
def chat_completions():
    if model is None or tokenizer is None:
        return jsonify({"error": "Model not loaded"}), 400
    
    data = request.json
    prompt = data.get('prompt')
    
    if not prompt:
        return jsonify({"error": "Prompt is required"}), 400
    
    try:
        inputs = tokenizer(prompt, return_tensors="pt")
        outputs = model.generate(inputs.input_ids, max_length=50)
        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        return jsonify({"response": response}), 200
    except Exception as e:
        print(f"Error generating text: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/stop_model', methods=['POST'])
def stop_model():
    global model, tokenizer, model_path
    if model is None or tokenizer is None:
        return jsonify({"error": "Model not loaded"}), 400
    
    try:
        model = None
        tokenizer = None
        model_path = None
        return jsonify({"message": "Model stopped successfully"}), 200
    except Exception as e:
        print(f"Error stopping model: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/is_model_running', methods=['POST'])
def is_model_running():
    data = request.json
    path = data.get('model_path')
    
    if not path:
        return jsonify({"error": "Model path is required"}), 400
    
    if model is not None and model_path == path:
        return jsonify({"is_running": True}), 200
    else:
        return jsonify({"is_running": False}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)